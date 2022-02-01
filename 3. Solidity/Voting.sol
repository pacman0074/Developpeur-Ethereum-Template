// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";

contract Voting is Ownable {

    //Proposal IDs counter
    using Counters for Counters.Counter;
    Counters.Counter private proposalIDs;

    uint public winningProposalId;
    
    //Whitelist of voters identified by their address
    mapping (address => Voter) public whitelist;
    //List of proposal identified by their proposal ID
    mapping (uint => Proposal) public proposalList;


    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }
    struct Proposal {
        string description;
        uint voteCount;
    } 

    enum WorkflowStatus {
        registrationVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }
    WorkflowStatus public currentStatus = WorkflowStatus.registrationVoters;

    event VoterRegistered(address voterAddress); 
    event VoterBlackListed(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    //Voting admin registers a whitelist of voters identified by their Ethereum address
    function addVoter(address _voterAddress) public onlyOwner {
        require(currentStatus == WorkflowStatus.registrationVoters, "Voter registration session is over, please wait for the next voting !");
        require(!whitelist[_voterAddress].isRegistered, "Voter is alrealdy registered !");
        
        //Register a new voter
        Voter memory newvoter;
        newvoter.isRegistered = true;
        newvoter.hasVoted = false;
        whitelist[_voterAddress] = newvoter;
        emit VoterRegistered(_voterAddress);
    }

    //Voting administrator starts proposal recording session
    function StartProposalsRegistration() public onlyOwner returns(WorkflowStatus) {
        require (currentStatus != WorkflowStatus.ProposalsRegistrationStarted, "The proposal registration is ongoing !");
        require (currentStatus == WorkflowStatus.registrationVoters, "The proposal registration is over !");

        WorkflowStatus oldStatus = currentStatus;
        currentStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(oldStatus, currentStatus);

        return currentStatus;
    }

    //Registered voters are allowed to register their proposals while the registration session is active
    function registerProposal(string memory _proposal)  external {
        require (currentStatus != WorkflowStatus.registrationVoters, "The proposal registration has not started yet");
        require (currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "The proposal registration vote is over !");
        require(whitelist[msg.sender].isRegistered, "You're not in the whitelist !!!");

        proposalIDs.increment();
        Proposal memory newproposal = Proposal(_proposal, 0);
        whitelist[msg.sender].votedProposalId = proposalIDs.current();
        proposalList[proposalIDs.current()] = newproposal;
        emit ProposalRegistered(proposalIDs.current()); 
    }

    //Voting administrator ends proposal recording session
    function EndProposalsRegistration() public onlyOwner returns(WorkflowStatus) {
        require (currentStatus != WorkflowStatus.registrationVoters, "The proposal registration has not started yet");
        require (currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "The proposal registration vote is over !");

        WorkflowStatus oldStatus = currentStatus;
        currentStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(oldStatus, currentStatus);

        return currentStatus;
    }

    //The voting administrator starts the voting session
    function StartVoting() public onlyOwner returns(WorkflowStatus) {
        require (currentStatus != WorkflowStatus.ProposalsRegistrationStarted && 
        currentStatus != WorkflowStatus.registrationVoters, "The voting has not started yet");
        require (currentStatus == WorkflowStatus.ProposalsRegistrationEnded, "The voting is over !");

        WorkflowStatus oldStatus = currentStatus;
        currentStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(oldStatus, currentStatus);

        return currentStatus;

    }

    //Voters can vote for their favorite proposal
    function Vote(uint256 _proposalID) external {
        require (currentStatus != WorkflowStatus.registrationVoters &&
        currentStatus != WorkflowStatus.ProposalsRegistrationStarted &&
        currentStatus != WorkflowStatus.ProposalsRegistrationEnded, "The voting has not started yet");
        require (currentStatus == WorkflowStatus.VotingSessionStarted, "The voting is over !");
        require(whitelist[msg.sender].isRegistered, "You're not in the whitelist !");
        require(!whitelist[msg.sender].hasVoted, "You're already voted");
        require(keccak256(bytes(proposalList[_proposalID].description)) != keccak256(bytes("")), "This proposal ID does not exist");

        whitelist[msg.sender].votedProposalId = _proposalID;
        whitelist[msg.sender].hasVoted = true;
        proposalList[_proposalID].voteCount+=1;
        emit Voted(msg.sender, _proposalID );

    }

    //The voting administrator ends the voting session
    function EndVoting() public onlyOwner returns(WorkflowStatus) {
        require (currentStatus != WorkflowStatus.registrationVoters && 
        currentStatus != WorkflowStatus.ProposalsRegistrationStarted &&
        currentStatus != WorkflowStatus.ProposalsRegistrationEnded, "The voting has not started yet");
        require (currentStatus == WorkflowStatus.VotingSessionStarted, "The voting is over !");

        WorkflowStatus oldStatus = currentStatus;
        currentStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(oldStatus, currentStatus);

        return currentStatus;
         
    }
    
    //L'administrateur du vote comptabilise les votes
    function countVotes() public onlyOwner {
        require (currentStatus != WorkflowStatus.registrationVoters &&
        currentStatus != WorkflowStatus.ProposalsRegistrationStarted &&
        currentStatus != WorkflowStatus.ProposalsRegistrationEnded &&
        currentStatus != WorkflowStatus.VotingSessionStarted, "The counting of votes has not started yet");
        require (currentStatus == WorkflowStatus.VotingSessionEnded, "The counting of votes is over !");

        uint proposalId = 1;
        if (proposalIDs.current() != 1){
            for (uint i=1; i<=proposalIDs.current(); i++) {
                if (proposalList[proposalId].voteCount < proposalList[i].voteCount){
                    proposalId = i;
                }
            }
        }
        winningProposalId = proposalId;

        WorkflowStatus oldStatus = currentStatus;
        currentStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(oldStatus, currentStatus);
    }
}
