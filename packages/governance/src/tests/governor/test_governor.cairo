use core::hash::{HashStateTrait, HashStateExTrait};
use core::num::traits::Zero;
use core::pedersen::PedersenTrait;
use crate::governor::GovernorComponent::{InternalImpl, InternalExtendedImpl, GovernorQuorumTrait};
use crate::governor::interface::{IGOVERNOR_ID, ProposalState};
use crate::governor::{GovernorComponent, ProposalCore};
use crate::utils::call_impls::{HashCallImpl, HashCallsImpl};
use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin_test_common::mocks::governor::GovernorMock;
use openzeppelin_testing::constants::{ADMIN, OTHER, ZERO};
use openzeppelin_testing::events::EventSpyExt;
use openzeppelin_token::erc1155::interface::IERC1155_RECEIVER_ID;
use openzeppelin_token::erc721::interface::IERC721_RECEIVER_ID;
use openzeppelin_utils::bytearray::ByteArrayExtTrait;
use snforge_std::EventSpy;
use snforge_std::{spy_events, test_address};
use snforge_std::{start_cheat_caller_address, start_cheat_block_timestamp_global, start_mock_call};
use starknet::ContractAddress;
use starknet::account::Call;
use starknet::storage::{StoragePathEntry, StoragePointerWriteAccess, StorageMapWriteAccess};

type ComponentState = GovernorComponent::ComponentState<GovernorMock::ContractState>;

fn CONTRACT_STATE() -> GovernorMock::ContractState {
    GovernorMock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    GovernorComponent::component_state_for_testing()
}

//
// Internal
//

#[test]
fn test_initializer() {
    let mut state = COMPONENT_STATE();
    let contract_state = CONTRACT_STATE();

    state.initializer();

    assert!(contract_state.supports_interface(IGOVERNOR_ID));
    assert!(contract_state.supports_interface(IERC721_RECEIVER_ID));
    assert!(contract_state.supports_interface(IERC1155_RECEIVER_ID));
}

//
// get_proposal
//

#[test]
fn test_get_empty_proposal() {
    let mut state = COMPONENT_STATE();

    let proposal = state.get_proposal(0);

    assert_eq!(proposal.proposer, ZERO());
    assert_eq!(proposal.vote_start, 0);
    assert_eq!(proposal.vote_duration, 0);
    assert_eq!(proposal.executed, false);
    assert_eq!(proposal.canceled, false);
    assert_eq!(proposal.eta_seconds, 0);
}

#[test]
fn test_get_proposal() {
    let mut state = COMPONENT_STATE();
    let (_, expected_proposal) = get_proposal_info();

    state.Governor_proposals.write(1, expected_proposal);

    let proposal = state.get_proposal(1);
    assert_eq!(proposal, expected_proposal);
}

//
// is_valid_description_for_proposer
//

#[test]
fn test_is_valid_description_too_short() {
    let state = COMPONENT_STATE();
    let short_description: ByteArray =
        "fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
    assert_eq!(short_description.len(), 75);

    let is_valid = state.is_valid_description_for_proposer(ADMIN(), @short_description);
    assert!(is_valid);
}

#[test]
fn test_is_valid_description_wrong_suffix() {
    let state = COMPONENT_STATE();
    let description = "?proposer=0x4718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d";

    let is_valid = state.is_valid_description_for_proposer(ADMIN(), @description);
    assert!(is_valid);
}

#[test]
fn test_is_valid_description_wrong_proposer() {
    let state = COMPONENT_STATE();
    let description =
        "#proposer=0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d";

    let is_valid = state.is_valid_description_for_proposer(ADMIN(), @description);
    assert!(!is_valid);
}

#[test]
fn test_is_valid_description_valid_proposer() {
    let state = COMPONENT_STATE();
    let address = ADMIN().to_byte_array(16, 64);
    let mut description: ByteArray = "#proposer=0x";

    description.append(@address);

    let is_valid = state.is_valid_description_for_proposer(ADMIN(), @description);
    assert!(is_valid);
}

//
// _hash_proposal
//

#[test]
fn test__hash_proposal() {
    let state = COMPONENT_STATE();
    let calls = get_calls(ZERO());
    let description = @"proposal description";
    let description_hash = description.hash();

    let expected_hash = hash_proposal(calls, description_hash);
    let hash = state._hash_proposal(calls, description_hash);

    assert_eq!(hash, expected_hash);
}

//
// Proposal info
//

#[test]
fn test__proposal_snapshot() {
    let mut state = COMPONENT_STATE();
    let (id, proposal) = get_proposal_info();

    state.Governor_proposals.write(id, proposal);

    let snapshot = state._proposal_snapshot(id);
    let expected = proposal.vote_start;
    assert_eq!(snapshot, expected);
}

#[test]
fn test__proposal_deadline() {
    let mut state = COMPONENT_STATE();
    let (id, proposal) = get_proposal_info();

    state.Governor_proposals.write(id, proposal);

    let deadline = state._proposal_deadline(id);
    let expected = proposal.vote_start + proposal.vote_duration;
    assert_eq!(deadline, expected);
}

#[test]
fn test__proposal_proposer() {
    let mut state = COMPONENT_STATE();
    let (id, proposal) = get_proposal_info();

    state.Governor_proposals.write(id, proposal);

    let proposer = state._proposal_proposer(id);
    let expected = proposal.proposer;
    assert_eq!(proposer, expected);
}

#[test]
fn test__proposal_eta() {
    let mut state = COMPONENT_STATE();
    let (_, proposal) = get_proposal_info();

    state.Governor_proposals.write(1, proposal);

    let eta = state._proposal_eta(1);
    let expected = proposal.eta_seconds;
    assert_eq!(eta, expected);
}

//
// assert_only_governance
//

#[test]
fn test_assert_only_governance() {
    let mut state = COMPONENT_STATE();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, contract_address);

    state.assert_only_governance();
}

#[test]
#[should_panic(expected: 'Executor only')]
fn test_assert_only_governance_not_executor() {
    let mut state = COMPONENT_STATE();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, OTHER());

    state.assert_only_governance();
}

//
// validate_state
//

#[test]
fn test_validate_state() {
    let mut state = COMPONENT_STATE();
    let (id, proposal) = get_proposal_info();

    state.Governor_proposals.write(id, proposal);

    // Current should be Pending
    let current_state = state._state(id);
    assert_eq!(current_state, ProposalState::Pending);

    let valid_states = array![ProposalState::Pending];
    state.validate_state(id, valid_states.span());

    let valid_states = array![ProposalState::Pending, ProposalState::Active];
    state.validate_state(id, valid_states.span());

    let valid_states = array![
        ProposalState::Executed, ProposalState::Active, ProposalState::Pending
    ];
    state.validate_state(id, valid_states.span());
}

#[test]
#[should_panic(expected: 'Unexpected proposal state')]
fn test_validate_state_invalid() {
    let mut state = COMPONENT_STATE();
    let (id, proposal) = get_proposal_info();

    state.Governor_proposals.write(id, proposal);

    // Current should be Pending
    let current_state = state._state(id);
    assert_eq!(current_state, ProposalState::Pending);

    let valid_states = array![ProposalState::Active].span();
    state.validate_state(id, valid_states);
}

//
// _state
//

#[test]
fn test__state_executed() {
    let mut state = COMPONENT_STATE();

    // The getter already asserts the state
    get_executed_proposal(ref state);
}

#[test]
fn test__state_canceled() {
    let mut state = COMPONENT_STATE();

    // The getter already asserts the state
    get_canceled_proposal(ref state);
}

#[test]
#[should_panic(expected: 'Nonexistent proposal')]
fn test__state_non_existent() {
    let state = COMPONENT_STATE();

    state._state(1);
}

#[test]
fn test__state_pending() {
    let mut state = COMPONENT_STATE();

    // The getter already asserts the state
    get_pending_proposal(ref state);
}

#[test]
fn test__state_active() {
    let mut state = COMPONENT_STATE();
    let (id, proposal) = get_proposal_info();

    state.Governor_proposals.write(id, proposal);

    let deadline = proposal.vote_start + proposal.vote_duration;
    let expected = ProposalState::Active;

    // Is active before deadline
    start_cheat_block_timestamp_global(deadline - 1);
    let current_state = state._state(id);
    assert_eq!(current_state, expected);

    // Is active in deadline
    start_cheat_block_timestamp_global(deadline);
    let current_state = state._state(id);
    assert_eq!(current_state, expected);
}

#[test]
fn test__state_defeated_quorum_not_reached() {
    let mut mock_state = CONTRACT_STATE();
    let (id, proposal) = get_proposal_info();

    mock_state.governor.Governor_proposals.write(id, proposal);

    let deadline = proposal.vote_start + proposal.vote_duration;
    let expected = ProposalState::Defeated;

    start_cheat_block_timestamp_global(deadline + 1);

    // Quorum not reached
    let quorum = mock_state.governor.quorum(0);
    let proposal_votes = mock_state.governor_counting_simple.Governor_proposals_votes.entry(id);
    proposal_votes.for_votes.write(quorum - 1);

    let current_state = mock_state.governor._state(id);
    assert_eq!(current_state, expected);
}

#[test]
fn test__state_defeated_vote_not_succeeded() {
    let mut mock_state = CONTRACT_STATE();
    let (id, proposal) = get_proposal_info();

    mock_state.governor.Governor_proposals.write(id, proposal);

    let deadline = proposal.vote_start + proposal.vote_duration;
    let expected = ProposalState::Defeated;

    start_cheat_block_timestamp_global(deadline + 1);

    // Quorum reached
    let quorum = mock_state.governor.quorum(0);
    let proposal_votes = mock_state.governor_counting_simple.Governor_proposals_votes.entry(id);
    proposal_votes.for_votes.write(quorum + 1);

    // Vote not succeeded
    proposal_votes.against_votes.write(quorum + 1);

    let current_state = mock_state.governor._state(id);
    assert_eq!(current_state, expected);
}

#[test]
fn test__state_queued() {
    let mut mock_state = CONTRACT_STATE();

    // The getter already asserts the state
    get_queued_proposal(ref mock_state);
}

#[test]
fn test__state_succeeded() {
    let mut mock_state = CONTRACT_STATE();

    // The getter already asserts the state
    get_succeeded_proposal(ref mock_state);
}

//
// _propose
//

#[test]
fn test__propose() {
    let mut state = COMPONENT_STATE();
    let mut spy = spy_events();
    let contract_address = test_address();

    let calls = get_calls(OTHER());
    let description = @"proposal description";
    let proposer = ADMIN();
    let vote_start = starknet::get_block_timestamp() + GovernorMock::VOTING_DELAY;
    let vote_end = vote_start + GovernorMock::VOTING_PERIOD;

    let id = state._propose(calls, description, proposer);

    // Check id
    let expected_id = hash_proposal(calls, description.hash());
    assert_eq!(id, expected_id);

    // Check event
    spy
        .assert_only_event_proposal_created(
            contract_address,
            expected_id,
            proposer,
            calls,
            array![].span(),
            vote_start,
            vote_end,
            description
        );

    // Check proposal
    let proposal = state.get_proposal(id);
    let expected = ProposalCore {
        proposer: ADMIN(),
        vote_start: starknet::get_block_timestamp() + GovernorMock::VOTING_DELAY,
        vote_duration: GovernorMock::VOTING_PERIOD,
        executed: false,
        canceled: false,
        eta_seconds: 0
    };

    assert_eq!(proposal, expected);
}

#[test]
#[should_panic(expected: 'Existent proposal')]
fn test__propose_existent_proposal() {
    let mut state = COMPONENT_STATE();
    let calls = get_calls(OTHER());
    let description = @"proposal description";
    let proposer = ADMIN();

    let id = state._propose(calls, description, proposer);
    let expected_id = hash_proposal(calls, description.hash());
    assert_eq!(id, expected_id);

    // Propose again
    state._propose(calls, description, proposer);
}

//
// _cancel
//

#[test]
fn test__cancel_pending() {
    let mut state = COMPONENT_STATE();
    let (id, _) = get_pending_proposal(ref state);

    state._cancel(id, 0);

    let canceled_proposal = state.get_proposal(id);
    assert_eq!(canceled_proposal.canceled, true);
}

#[test]
fn test__cancel_active() {
    let mut state = COMPONENT_STATE();
    let (id, _) = get_active_proposal(ref state);

    state._cancel(id, 0);

    let canceled_proposal = state.get_proposal(id);
    assert_eq!(canceled_proposal.canceled, true);
}

#[test]
fn test__cancel_defeated() {
    let mut mock_state = CONTRACT_STATE();
    let (id, _) = get_defeated_proposal(ref mock_state);

    mock_state.governor._cancel(id, 0);

    let canceled_proposal = mock_state.governor.get_proposal(id);
    assert_eq!(canceled_proposal.canceled, true);
}

#[test]
fn test__cancel_succeeded() {
    let mut mock_state = CONTRACT_STATE();
    let (id, _) = get_succeeded_proposal(ref mock_state);

    mock_state.governor._cancel(id, 0);

    let canceled_proposal = mock_state.governor.get_proposal(id);
    assert_eq!(canceled_proposal.canceled, true);
}

#[test]
fn test__cancel_queued() {
    let mut mock_state = CONTRACT_STATE();
    let (id, _) = get_queued_proposal(ref mock_state);

    mock_state.governor._cancel(id, 0);

    let canceled_proposal = mock_state.governor.get_proposal(id);
    assert_eq!(canceled_proposal.canceled, true);
}

#[test]
#[should_panic(expected: 'Unexpected proposal state')]
fn test__cancel_canceled() {
    let mut state = COMPONENT_STATE();
    let (id, _) = get_canceled_proposal(ref state);

    // Cancel again
    state._cancel(id, 0);
}

#[test]
#[should_panic(expected: 'Unexpected proposal state')]
fn test__cancel_executed() {
    let mut state = COMPONENT_STATE();
    let (id, _) = get_executed_proposal(ref state);

    state._cancel(id, 0);
}

//
// _cast_vote
//

#[test]
#[should_panic(expected: 'Unexpected proposal state')]
fn test__cast_vote_pending() {
    let mut state = COMPONENT_STATE();
    let (id, _) = get_pending_proposal(ref state);

    state._cast_vote(id, OTHER(), 0, "", "");
}

#[test]
fn test__cast_vote_active_no_params() {
    let mut state = COMPONENT_STATE();
    let (id, _) = get_active_proposal(ref state);
    let mut spy = spy_events();
    let contract_address = test_address();

    let reason = "reason";
    let expected_weight = 100;

    // Mock the get past votes call
    start_mock_call(Zero::zero(), selector!("get_past_votes"), expected_weight);

    let weight = state._cast_vote(id, OTHER(), 0, reason, "");
    assert_eq!(weight, expected_weight);

    spy.assert_only_event_vote_cast(contract_address, OTHER(), id, 0, expected_weight, @"reason");
}

#[test]
fn test__cast_vote_active_with_params() {
    let mut state = COMPONENT_STATE();
    let (id, _) = get_active_proposal(ref state);
    let mut spy = spy_events();
    let contract_address = test_address();

    let reason = "reason";
    let params = "params";
    let expected_weight = 100;

    // Mock the get past votes call
    start_mock_call(Zero::zero(), selector!("get_past_votes"), expected_weight);

    let weight = state._cast_vote(id, OTHER(), 0, reason, params);
    assert_eq!(weight, expected_weight);

    spy
        .assert_event_vote_cast_with_params(
            contract_address, OTHER(), id, 0, expected_weight, @"reason", @"params"
        );
}

#[test]
#[should_panic(expected: 'Unexpected proposal state')]
fn test__cast_vote_defeated() {
    let mut mock_state = CONTRACT_STATE();
    let (id, _) = get_defeated_proposal(ref mock_state);

    mock_state.governor._cast_vote(id, OTHER(), 0, "", "");
}

#[test]
#[should_panic(expected: 'Unexpected proposal state')]
fn test__cast_vote_succeeded() {
    let mut mock_state = CONTRACT_STATE();
    let (id, _) = get_succeeded_proposal(ref mock_state);

    mock_state.governor._cast_vote(id, OTHER(), 0, "", "");
}

#[test]
#[should_panic(expected: 'Unexpected proposal state')]
fn test__cast_vote_queued() {
    let mut mock_state = CONTRACT_STATE();
    let (id, _) = get_queued_proposal(ref mock_state);

    mock_state.governor._cast_vote(id, OTHER(), 0, "", "");
}

#[test]
#[should_panic(expected: 'Unexpected proposal state')]
fn test__cast_vote_canceled() {
    let mut state = COMPONENT_STATE();
    let (id, _) = get_canceled_proposal(ref state);

    state._cast_vote(id, OTHER(), 0, "", "");
}

#[test]
#[should_panic(expected: 'Unexpected proposal state')]
fn test__cast_vote_executed() {
    let mut state = COMPONENT_STATE();
    let (id, _) = get_executed_proposal(ref state);

    state._cast_vote(id, OTHER(), 0, "", "");
}

//
// Helpers
//

fn get_proposal_info() -> (felt252, ProposalCore) {
    get_proposal_with_id(array![].span(), @"")
}

fn get_proposal_with_id(calls: Span<Call>, description: @ByteArray) -> (felt252, ProposalCore) {
    let timestamp = starknet::get_block_timestamp();
    let vote_start = timestamp + GovernorMock::VOTING_DELAY;
    let vote_duration = GovernorMock::VOTING_PERIOD;

    let proposal_id = hash_proposal(calls, description.hash());
    let proposal = ProposalCore {
        proposer: ADMIN(),
        vote_start,
        vote_duration,
        executed: false,
        canceled: false,
        eta_seconds: 0
    };

    (proposal_id, proposal)
}

fn hash_proposal(calls: Span<Call>, description_hash: felt252) -> felt252 {
    PedersenTrait::new(0).update_with(calls).update_with(description_hash).finalize()
}

fn get_calls(to: ContractAddress) -> Span<Call> {
    let call1 = Call { to, selector: selector!("test1"), calldata: array![].span() };
    let call2 = Call { to, selector: selector!("test2"), calldata: array![].span() };

    array![call1, call2].span()
}

fn get_pending_proposal(ref state: ComponentState) -> (felt252, ProposalCore) {
    let (id, proposal) = get_proposal_info();

    state.Governor_proposals.write(id, proposal);

    let state = state._state(id);
    let expected = ProposalState::Pending;

    assert_eq!(state, expected);

    (id, proposal)
}

fn get_active_proposal(ref state: ComponentState) -> (felt252, ProposalCore) {
    let (id, proposal) = get_proposal_info();

    state.Governor_proposals.write(id, proposal);

    let deadline = proposal.vote_start + proposal.vote_duration;
    let expected = ProposalState::Active;

    // Is active before deadline
    start_cheat_block_timestamp_global(deadline - 1);
    let current_state = state._state(id);
    assert_eq!(current_state, expected);

    (id, proposal)
}

fn get_queued_proposal(ref mock_state: GovernorMock::ContractState) -> (felt252, ProposalCore) {
    let (id, mut proposal) = get_proposal_info();

    proposal.eta_seconds = 1;
    mock_state.governor.Governor_proposals.write(id, proposal);

    let deadline = proposal.vote_start + proposal.vote_duration;

    // Quorum reached
    start_cheat_block_timestamp_global(deadline + 1);
    let quorum = mock_state.governor.quorum(0);
    let proposal_votes = mock_state.governor_counting_simple.Governor_proposals_votes.entry(id);
    proposal_votes.for_votes.write(quorum + 1);

    // Vote succeeded
    proposal_votes.against_votes.write(quorum);

    let expected = ProposalState::Queued;
    let current_state = mock_state.governor._state(id);
    assert_eq!(current_state, expected);

    (id, proposal)
}

fn get_canceled_proposal(ref state: ComponentState) -> (felt252, ProposalCore) {
    let (id, proposal) = get_proposal_info();

    state.Governor_proposals.write(id, proposal);

    state._cancel(id, 0);

    let expected = ProposalState::Canceled;
    let current_state = state._state(id);
    assert_eq!(current_state, expected);

    (id, proposal)
}

fn get_defeated_proposal(ref mock_state: GovernorMock::ContractState) -> (felt252, ProposalCore) {
    let (id, proposal) = get_proposal_info();

    mock_state.governor.Governor_proposals.write(id, proposal);

    let deadline = proposal.vote_start + proposal.vote_duration;

    // Quorum not reached
    start_cheat_block_timestamp_global(deadline + 1);
    let quorum = mock_state.governor.quorum(0);
    let proposal_votes = mock_state.governor_counting_simple.Governor_proposals_votes.entry(id);
    proposal_votes.for_votes.write(quorum - 1);

    let expected = ProposalState::Defeated;
    let current_state = mock_state.governor._state(id);
    assert_eq!(current_state, expected);

    (id, proposal)
}

fn get_succeeded_proposal(ref mock_state: GovernorMock::ContractState) -> (felt252, ProposalCore) {
    let (id, proposal) = get_proposal_info();

    mock_state.governor.Governor_proposals.write(id, proposal);

    let deadline = proposal.vote_start + proposal.vote_duration;
    let expected = ProposalState::Succeeded;

    start_cheat_block_timestamp_global(deadline + 1);

    // Quorum reached
    let quorum = mock_state.governor.quorum(0);
    let proposal_votes = mock_state.governor_counting_simple.Governor_proposals_votes.entry(id);
    proposal_votes.for_votes.write(quorum + 1);

    // Vote succeeded
    proposal_votes.against_votes.write(quorum);

    let current_state = mock_state.governor._state(id);
    assert_eq!(current_state, expected);

    (id, proposal)
}

fn get_executed_proposal(ref state: ComponentState) -> (felt252, ProposalCore) {
    let (id, mut proposal) = get_proposal_info();

    proposal.executed = true;
    state.Governor_proposals.write(id, proposal);

    let state = state._state(id);
    let expected = ProposalState::Executed;

    assert_eq!(state, expected);

    (id, proposal)
}

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
        description: @ByteArray
    ) {
        let expected = GovernorComponent::Event::ProposalCreated(
            GovernorComponent::ProposalCreated {
                proposal_id,
                proposer,
                calls,
                signatures,
                vote_start,
                vote_end,
                description: description.clone()
            }
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
        description: @ByteArray
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
                description
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
        reason: @ByteArray
    ) {
        let expected = GovernorComponent::Event::VoteCast(
            GovernorComponent::VoteCast {
                voter, proposal_id, support, weight, reason: reason.clone()
            }
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
        reason: @ByteArray
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
        params: @ByteArray
    ) {
        let expected = GovernorComponent::Event::VoteCastWithParams(
            GovernorComponent::VoteCastWithParams {
                voter, proposal_id, support, weight, reason: reason.clone(), params: params.clone()
            }
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
        params: @ByteArray
    ) {
        self
            .assert_event_vote_cast_with_params(
                contract, voter, proposal_id, support, weight, reason, params
            );
        self.assert_no_events_left_from(contract);
    }
}
