use openzeppelin_testing::{EventSpyExt, EventSpyQueue as EventSpy};
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::Event;
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
        let mut keys = array![];
        keys.append_serde(selector!("ProposalCreated"));
        keys.append_serde(proposal_id);
        keys.append_serde(proposer);

        let mut data = array![];
        data.append_serde(calls);
        data.append_serde(signatures);
        data.append_serde(vote_start);
        data.append_serde(vote_end);
        data.append_serde(description.clone());

        let expected = Event { keys, data };
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
        let mut keys = array![];
        keys.append_serde(selector!("VoteCast"));
        keys.append_serde(voter);

        let mut data = array![];
        data.append_serde(proposal_id);
        data.append_serde(support);
        data.append_serde(weight);
        data.append_serde(reason.clone());

        let expected = Event { keys, data };
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
        let mut keys = array![];
        keys.append_serde(selector!("VoteCastWithParams"));
        keys.append_serde(voter);

        let mut data = array![];
        data.append_serde(proposal_id);
        data.append_serde(support);
        data.append_serde(weight);
        data.append_serde(reason.clone());
        data.append_serde(params);

        let expected = Event { keys, data };
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
        let mut keys = array![];
        keys.append_serde(selector!("ProposalQueued"));
        keys.append_serde(proposal_id);

        let mut data = array![];
        data.append_serde(eta_seconds);

        let expected = Event { keys, data };
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
        let mut keys = array![];
        keys.append_serde(selector!("ProposalExecuted"));
        keys.append_serde(proposal_id);

        let expected = Event { keys, data: array![] };
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
        let mut keys = array![];
        keys.append_serde(selector!("ProposalCanceled"));
        keys.append_serde(proposal_id);

        let expected = Event { keys, data: array![] };
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_proposal_canceled(
        ref self: EventSpy, contract: ContractAddress, proposal_id: felt252,
    ) {
        self.assert_event_proposal_canceled(contract, proposal_id);
        self.assert_no_events_left_from(contract);
    }
}
