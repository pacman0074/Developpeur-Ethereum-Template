const Voting = artifacts.require("Voting");
const {expect} = require("chai");
const  {expectRevert, expectEvent, BN} = require("@openzeppelin/test-helpers");
const ERR_ONLY_OWNER = "Ownable: caller is not the owner";
const ERR_VOTERS_REGISTRATION_SESSION = "Voter registration session is over, please wait for the next voting !"
const ERR_START_PROPOSAL_REGISTRATION_SESSION = "The proposal registration is over !";
const ERR_NOT_IN_WHITELIST = "You're not in the whitelist !!!";
const ERR_ALREADY_VOTED = "You're already voted";
const ERR_PROPOSAL_ID_NOT_EXIST = "This proposal ID does not exist";
const _proposal = "New proposal";
const _proposal2 = "New proposal 2";

contract ('Voting', function(accounts){

    //the contract owner's address
    const owner = accounts[0];

    //the voter's address
    const voterAddress = accounts[1];
    const voterAddress2 = accounts[2];
    const voterAddress3 = accounts[3];  


    describe("Test StartProposalsRegistration", () => {
        beforeEach(async function() {
            //Create a new instance Voting contract
            this.VotingInstance = await Voting.new({from : owner}); 
        });
        
        it("verify if Proposals Registration has started", async function(){
            //Big number of registration voters & Proposals registration started status
            let registrationVotersStatus = new BN(Voting.WorkflowStatus.registrationVoters);
            let ProposalsRegistrationStartedStatus = new BN(Voting.WorkflowStatus.ProposalsRegistrationStarted);

            //Owner of the contract starts the proposal registration
            let receipt = await this.VotingInstance.StartProposalsRegistration({from : owner});

            //Expect proposal registration has started and the event WorkflowStatusChange is logged with the right values arguments
            expect(await this.VotingInstance.currentStatus()).to.be.bignumber.equal(ProposalsRegistrationStartedStatus);
            expectEvent(receipt, "WorkflowStatusChange",{previousStatus : registrationVotersStatus, newStatus : ProposalsRegistrationStartedStatus});
        });

        it("verify we cannot start proposals registrations if we are not in voters registration workflow", async function(){
            //Change the currentStatus of the contract to StartProposalsRegistration
            await this.VotingInstance.StartProposalsRegistration({from : owner});

            //Expect owner's contract cannot register new voter because we are not anymore in registration voters
            await expectRevert(this.VotingInstance.StartProposalsRegistration({from : owner}), ERR_START_PROPOSAL_REGISTRATION_SESSION);                
            });
        });



    describe("Test addvoter", () => {
        beforeEach(async function() {
            this.VotingInstance = await Voting.new({from : owner});
        });

        it('verify if the voter has been added in the whitelist and an event has been triggered', async function() {
            //add a new voter in the whitelist and retrieve the receipt of the transaction
            let receipt = await this.VotingInstance.addVoter(voterAddress, {from : owner});

            //retrieve voter structure from whitelist 
            voter = await this.VotingInstance.whitelist(voterAddress, {from : owner});

            //expect voter is now registered and the event VoterRegistered is logged with the right values arguments
            expect(voter.isRegistered).to.be.true;
            expectEvent(receipt, "VoterRegistered", {voterAddress : voterAddress });
        });

        it('verify if only the owner of the contract can add voter', async function(){
            //expert a Revert when addVoter is not called by owner's contract
            await expectRevert(this.VotingInstance.addVoter(voterAddress, {from : voterAddress}), ERR_ONLY_OWNER);
        });

        it("verify owner\'s contract cannot add a voter if registration session is finished or not started", async function(){
            //Owner of the contract starts the proposal registration
            await this.VotingInstance.StartProposalsRegistration({from : owner});

            //Expect owner's contract cannot register new voter because we are not anymore registration voters
            await expectRevert(this.VotingInstance.addVoter(voterAddress, {from : owner}), ERR_VOTERS_REGISTRATION_SESSION);
        });    
    });


    describe("Test registerProposal", () => {
        beforeEach(async function() {
            this.VotingInstance = await Voting.new({from : owner});

            //Owner add a voter and start proposal registration 
            await this.VotingInstance.addVoter(voterAddress, {from : owner});
            await this.VotingInstance.StartProposalsRegistration({from : owner});
        });

        it("verify a voter not registred in the whilelist can't register proposal(s)", async function(){
            //Expect voter cannot submit proposal because he's not in the whitelist
            await expectRevert(this.VotingInstance.registerProposal(_proposal, {from :owner}), ERR_NOT_IN_WHITELIST);
        });

        it("verify the proposal has been registerd", async function (){
            //voter registers a new proposal
            let receipt = await this.VotingInstance.registerProposal(_proposal, {from : voterAddress});
            let proposalId = new BN(1);

            //retrieve the proposal identified by its proposal ID 
            let proposal = await this.VotingInstance.proposalList(proposalId, {from : owner});
            
            //expect proposal description is equal to proposal description registered by the voter
            expect(proposal.description).to.equal(_proposal);

            //expect the event ProposalRegistered is logged with the right values arguments
            expectEvent(receipt, "ProposalRegistered", {proposalId : proposalId});
        });
    });
    

    describe("Test Vote", () => {
        beforeEach(async function() {
            this.VotingInstance = await Voting.new({from : owner});

            //we advance the Voting workflow until the start of voting
            await this.VotingInstance.addVoter(voterAddress, {from : owner});
            await this.VotingInstance.addVoter(voterAddress2, {from : owner});
            await this.VotingInstance.addVoter(voterAddress3, {from : owner});
            await this.VotingInstance.StartProposalsRegistration({from : owner});
            await this.VotingInstance.registerProposal(_proposal, {from : voterAddress});
            await this.VotingInstance.registerProposal(_proposal2, {from : voterAddress});
            await this.VotingInstance.EndProposalsRegistration({from : owner});
            await this.VotingInstance.StartVoting({from : owner});
        });

        it("verify a voter can vote only one time", async function(){
            let proposalId = new BN(1);
            
            //Voter vote for a proposal ID and expect a revert because the voter already voted
            await this.VotingInstance.Vote(proposalId, {from : voterAddress});
            await expectRevert(this.VotingInstance.Vote(proposalId, {from : voterAddress}), ERR_ALREADY_VOTED);
        });

        it("verify a voter cannot vote for an unknown proposal", async function(){
            let unknownProposalId = new BN(4);
            
            //expect a revert because the voter vote for a non-existent proposal ID
            await expectRevert(this.VotingInstance.Vote(unknownProposalId, {from : voterAddress}),ERR_PROPOSAL_ID_NOT_EXIST);
        });

        it("verify the vote has been registerd", async function() {
            let proposalId = new BN(1);
            let voteCount = new BN(1);

            //retrieve the receipt of the transaction, the voter by his address and the proposal identified by its proposal ID
            let receipt = await this.VotingInstance.Vote(proposalId,{from : voterAddress});
            let voter = await this.VotingInstance.whitelist(voterAddress, {from : owner});
            let proposal = await this.VotingInstance.proposalList(proposalId, {from : owner});

            //verify the voter has voted, the voter has well voted for his favorite proposal ID and voteCount has been set to 1
            expect(voter.hasVoted).to.be.true;
            expect(voter.votedProposalId).to.be.bignumber.equal(proposalId);
            expect(proposal.voteCount).to.be.bignumber.equal(voteCount);

            //expect the event Voted is logged with the right values arguments
            expectEvent(receipt, "Voted", {voter : voterAddress, proposalId : proposalId });
        });
        it("verify winningProposalId is updated only when number of votes of voted proposal id is greater than number of votes of winningProposalId", async function(){ 
            let proposalId = new BN(1);
            let proposal2Id = new BN(2);

            await this.VotingInstance.Vote(proposalId, {from : voterAddress});
            await this.VotingInstance.Vote(proposal2Id, {from : voterAddress2});
            //verify winning proposal ID is still 1
            expect(await this.VotingInstance.winningProposalId({from : owner})).to.be.bignumber.equal(proposalId);

            await this.VotingInstance.Vote(proposal2Id, {from : voterAddress3});
            //verify winning proposal ID is 2 now
            expect(await this.VotingInstance.winningProposalId({from : owner})).to.be.bignumber.equal(proposal2Id);
        })
    });  
});
