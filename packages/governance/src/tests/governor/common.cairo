use openzeppelin_testing::{EventSpyExt, EventSpyQueue as EventSpy};
use starknet::ContractAddress;
use starknet::account::Call;
use crate::governor::GovernorComponent;

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
        let expected = GovernorComponent::Event::ProposalCreated(
            GovernorComponent::ProposalCreated {
                proposal_id,
                proposer,
                calls,
                signatures,
                vote_start,
                vote_end,
                description: description.clone(),
            },
        );
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
        let expected = GovernorComponent::Event::VoteCast(
            GovernorComponent::VoteCast {
                voter, proposal_id, support, weight, reason: reason.clone(),
            },
        );
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
        let expected = GovernorComponent::Event::VoteCastWithParams(
            GovernorComponent::VoteCastWithParams {
                voter, proposal_id, support, weight, reason: reason.clone(), params,
            },
        );
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
        let expected = GovernorComponent::Event::ProposalQueued(
            GovernorComponent::ProposalQueued { proposal_id, eta_seconds },
        );
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
        let expected = GovernorComponent::Event::ProposalExecuted(
            GovernorComponent::ProposalExecuted { proposal_id },
        );
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
        let expected = GovernorComponent::Event::ProposalCanceled(
            GovernorComponent::ProposalCanceled { proposal_id },
        );
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_proposal_canceled(
        ref self: EventSpy, contract: ContractAddress, proposal_id: felt252,
    ) {
        self.assert_event_proposal_canceled(contract, proposal_id);
        self.assert_no_events_left_from(contract);
    }
}
