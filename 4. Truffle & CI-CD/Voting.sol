// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Voting is Ownable {
    //enum
    //struct
    //variable
    //event
    //modifier
    //constructor
    //fonctions (regrouper fonction view) 

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
    
    
    //Proposal IDs counter
    using Counters for Counters.Counter;
    Counters.Counter private proposalIDs;

    uint public winningProposalId;
    
    //Whitelist of voters identified by their address
    mapping (address => Voter) public whitelist;
    //List of proposal identified by their proposal ID
    mapping (uint => Proposal) public proposalList;

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
        whitelist[_voterAddress].isRegistered = true;
        
        emit VoterRegistered(_voterAddress);
    }

    //Voting administrator starts proposal recording session
    function StartProposalsRegistration() public onlyOwner returns(WorkflowStatus) {
        require (currentStatus == WorkflowStatus.registrationVoters, "The proposal registration is over !");

        WorkflowStatus oldStatus = currentStatus;
        currentStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(oldStatus, currentStatus);

        return currentStatus;
    }

    //Registered voters are allowed to register their proposals while the registration session is active
    function registerProposal(string memory _proposal)  external {
        require (currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "The proposal registration vote is over !");
        require(whitelist[msg.sender].isRegistered, "You're not in the whitelist !!!");

        proposalIDs.increment();
        //whitelist[msg.sender].votedProposalId = proposalIDs.current();
        proposalList[proposalIDs.current()].description = _proposal;
        emit ProposalRegistered(proposalIDs.current()); 
    }

    //Voting administrator ends proposal recording session
    function EndProposalsRegistration() public onlyOwner returns(WorkflowStatus) {
        require (currentStatus == WorkflowStatus.ProposalsRegistrationStarted, "The proposal registration vote is over !");

        WorkflowStatus oldStatus = currentStatus;
        currentStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(oldStatus, currentStatus);

        return currentStatus;
    }

    //The voting administrator starts the voting session
    function StartVoting() public onlyOwner returns(WorkflowStatus) {

        require (currentStatus == WorkflowStatus.ProposalsRegistrationEnded, "The voting is over !");

        WorkflowStatus oldStatus = currentStatus;
        currentStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(oldStatus, currentStatus);

        return currentStatus;

    }

    //Voters can vote for their favorite proposal
    function Vote(uint256 _proposalID) external {
        require (currentStatus == WorkflowStatus.VotingSessionStarted, "The voting is over !");
        require(whitelist[msg.sender].isRegistered, "You're not in the whitelist !");
        require(!whitelist[msg.sender].hasVoted, "You're already voted");
        require(keccak256(bytes(proposalList[_proposalID].description)) != keccak256(bytes("")), "This proposal ID does not exist");

        whitelist[msg.sender].votedProposalId = _proposalID;
        whitelist[msg.sender].hasVoted = true;
        proposalList[_proposalID].voteCount+=1;
        
        if (proposalList[winningProposalId].voteCount < proposalList[_proposalID].voteCount){
              winningProposalId = _proposalID;
        }
        emit Voted(msg.sender, _proposalID );

    }

    //The voting administrator ends the voting session
    function EndVoting() public onlyOwner returns(WorkflowStatus) {
        require (currentStatus == WorkflowStatus.VotingSessionStarted, "The voting is over !");

        WorkflowStatus oldStatus = currentStatus;
        currentStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(oldStatus, currentStatus);

        return currentStatus;
         
    }
    
    //L'administrateur du vote comptabilise les votes
    function countVotes() public onlyOwner returns(WorkflowStatus) {
        require (currentStatus == WorkflowStatus.VotingSessionEnded, "The counting of votes is over !");

        WorkflowStatus oldStatus = currentStatus;
        currentStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(oldStatus, currentStatus);

        return currentStatus;
    }
}
