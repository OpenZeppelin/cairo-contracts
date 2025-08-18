use openzeppelin_testing::{EventSpyExt, EventSpyQueue as EventSpy, ExpectedEvent};
use starknet::ContractAddress;
use starknet::account::Call;

//
// Event helpers
//

#[generate_trait]
pub(crate) impl GovernorSpyHelpersImpl of GovernorSpyHelpers {
    fn assert_event_proposal_created(
        ref self: EventSpy,
        contract: ContractAddress,
        proposal_id: felt252,
        proposer: ContractAddress,
        calls: Span<Call>,
        signatures: Span<Span<felt252>>,
        vote_start: u64,
        vote_end: u64,
        description: @ByteArray,
    ) {
        let expected = ExpectedEvent::new()
            .key(selector!("ProposalCreated"))
            .key(proposal_id)
            .key(proposer)
            .data(calls)
            .data(signatures)
            .data(vote_start)
            .data(vote_end)
            .data(description.clone());
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_proposal_created(
        ref self: EventSpy,
        contract: ContractAddress,
        proposal_id: felt252,
        proposer: ContractAddress,
        calls: Span<Call>,
        signatures: Span<Span<felt252>>,
        vote_start: u64,
        vote_end: u64,
        description: @ByteArray,
    ) {
        self
            .assert_event_proposal_created(
                contract,
                proposal_id,
                proposer,
                calls,
                signatures,
                vote_start,
                vote_end,
                description,
            );
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_vote_cast(
        ref self: EventSpy,
        contract: ContractAddress,
        voter: ContractAddress,
        proposal_id: felt252,
        support: u8,
        weight: u256,
        reason: @ByteArray,
    ) {
        let expected = ExpectedEvent::new()
            .key(selector!("VoteCast"))
            .key(voter)
            .data(proposal_id)
            .data(support)
            .data(weight)
            .data(reason.clone());
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_vote_cast(
        ref self: EventSpy,
        contract: ContractAddress,
        voter: ContractAddress,
        proposal_id: felt252,
        support: u8,
        weight: u256,
        reason: @ByteArray,
    ) {
        self.assert_event_vote_cast(contract, voter, proposal_id, support, weight, reason);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_vote_cast_with_params(
        ref self: EventSpy,
        contract: ContractAddress,
        voter: ContractAddress,
        proposal_id: felt252,
        support: u8,
        weight: u256,
        reason: @ByteArray,
        params: Span<felt252>,
    ) {
        let expected = ExpectedEvent::new()
            .key(selector!("VoteCastWithParams"))
            .key(voter)
            .data(proposal_id)
            .data(support)
            .data(weight)
            .data(reason.clone())
            .data(params);
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_vote_cast_with_params(
        ref self: EventSpy,
        contract: ContractAddress,
        voter: ContractAddress,
        proposal_id: felt252,
        support: u8,
        weight: u256,
        reason: @ByteArray,
        params: Span<felt252>,
    ) {
        self
            .assert_event_vote_cast_with_params(
                contract, voter, proposal_id, support, weight, reason, params,
            );
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_proposal_queued(
        ref self: EventSpy, contract: ContractAddress, proposal_id: felt252, eta_seconds: u64,
    ) {
        let expected = ExpectedEvent::new()
            .key(selector!("ProposalQueued"))
            .key(proposal_id)
            .data(eta_seconds);
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_proposal_queued(
        ref self: EventSpy, contract: ContractAddress, proposal_id: felt252, eta_seconds: u64,
    ) {
        self.assert_event_proposal_queued(contract, proposal_id, eta_seconds);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_proposal_executed(
        ref self: EventSpy, contract: ContractAddress, proposal_id: felt252,
    ) {
        let expected = ExpectedEvent::new().key(selector!("ProposalExecuted")).key(proposal_id);
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_proposal_executed(
        ref self: EventSpy, contract: ContractAddress, proposal_id: felt252,
    ) {
        self.assert_event_proposal_executed(contract, proposal_id);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_proposal_canceled(
        ref self: EventSpy, contract: ContractAddress, proposal_id: felt252,
    ) {
        let expected = ExpectedEvent::new().key(selector!("ProposalCanceled")).key(proposal_id);
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_proposal_canceled(
        ref self: EventSpy, contract: ContractAddress, proposal_id: felt252,
    ) {
        self.assert_event_proposal_canceled(contract, proposal_id);
        self.assert_no_events_left_from(contract);
    }
}
