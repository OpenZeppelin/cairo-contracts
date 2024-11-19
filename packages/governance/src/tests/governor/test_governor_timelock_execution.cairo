use crate::governor::DefaultConfig;
use crate::governor::GovernorComponent::{InternalImpl, InternalExtendedImpl};
use crate::governor::extensions::GovernorTimelockExecutionComponent::GovernorExecution;
use crate::governor::extensions::interface::{ITimelockedDispatcher, ITimelockedDispatcherTrait};
use crate::governor::interface::ProposalState;
use crate::governor::interface::{IGovernorDispatcher, IGovernorDispatcherTrait};
use crate::tests::governor::common::{
    COMPONENT_STATE_TIMELOCKED as COMPONENT_STATE, CONTRACT_STATE_TIMELOCKED as CONTRACT_STATE
};
use crate::tests::governor::common::{set_executor, get_proposal_info, ComponentStateTimelocked};
use crate::tests::governor::test_governor::GovernorSpyHelpersImpl;
use crate::tests::test_timelock::TimelockSpyHelpersImpl;
use crate::timelock::interface::{OperationState, ITimelockDispatcher};
use openzeppelin_test_common::mocks::governor::GovernorMock::SNIP12MetadataImpl;
use openzeppelin_test_common::mocks::governor::GovernorTimelockedMock;
use openzeppelin_test_common::mocks::timelock::{
    IMockContractDispatcher, IMockContractDispatcherTrait
};
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{TIMELOCK, VOTES_TOKEN};
use openzeppelin_utils::bytearray::ByteArrayExtTrait;
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{start_mock_call, start_cheat_block_timestamp_global, spy_events, store};
use starknet::ContractAddress;
use starknet::account::Call;
use starknet::storage::{StoragePathEntry, StoragePointerWriteAccess, StorageMapWriteAccess};

const MIN_DELAY: u64 = 100;

//
// Dispatchers
//

fn deploy_governor() -> IGovernorDispatcher {
    let mut calldata = array![];
    calldata.append_serde(VOTES_TOKEN());
    calldata.append_serde(1);

    let address = utils::declare_and_deploy("GovernorTimelockedMock", calldata);
    IGovernorDispatcher { contract_address: address }
}

fn deploy_timelock(admin: ContractAddress) -> ITimelockDispatcher {
    let proposers = array![admin].span();
    let executors = array![admin].span();

    let mut calldata = array![];
    calldata.append_serde(MIN_DELAY);
    calldata.append_serde(proposers);
    calldata.append_serde(executors);
    calldata.append_serde(admin);

    let address = utils::declare_and_deploy("TimelockControllerMock", calldata);
    ITimelockDispatcher { contract_address: address }
}

fn deploy_mock_target() -> IMockContractDispatcher {
    let mut calldata = array![];

    let address = utils::declare_and_deploy("MockContract", calldata);
    IMockContractDispatcher { contract_address: address }
}

fn setup_dispatchers() -> (IGovernorDispatcher, ITimelockDispatcher, IMockContractDispatcher) {
    let governor = deploy_governor();
    let timelock = deploy_timelock(governor.contract_address);
    let target = deploy_mock_target();

    // Set the timelock controller
    store(
        governor.contract_address,
        selector!("Governor_timelock_controller"),
        array![timelock.contract_address.into()].span()
    );

    (governor, timelock, target)
}

//
// state
//

#[test]
fn test_state_executed() {
    let mut component_state = COMPONENT_STATE();
    let id = setup_executed_proposal(ref component_state);

    let state = GovernorExecution::state(@component_state, id);
    assert_eq!(state, ProposalState::Executed);
}

#[test]
fn test_state_canceled() {
    let mut component_state = COMPONENT_STATE();
    let id = setup_canceled_proposal(ref component_state);

    let state = GovernorExecution::state(@component_state, id);
    assert_eq!(state, ProposalState::Canceled);
}

#[test]
#[should_panic(expected: 'Nonexistent proposal')]
fn test_state_non_existent() {
    let component_state = COMPONENT_STATE();

    GovernorExecution::state(@component_state, 1);
}

#[test]
fn test_state_pending() {
    let mut component_state = COMPONENT_STATE();
    let id = setup_pending_proposal(ref component_state);

    let state = GovernorExecution::state(@component_state, id);
    assert_eq!(state, ProposalState::Pending);
}

#[test]
fn test_state_active() {
    let mut component_state = COMPONENT_STATE();
    let (id, proposal) = get_proposal_info();

    component_state.Governor_proposals.write(id, proposal);

    let deadline = proposal.vote_start + proposal.vote_duration;
    let expected = ProposalState::Active;

    // Is active before deadline
    start_cheat_block_timestamp_global(deadline - 1);
    let state = GovernorExecution::state(@component_state, id);
    assert_eq!(state, expected);

    // Is active in deadline
    start_cheat_block_timestamp_global(deadline);
    let state = GovernorExecution::state(@component_state, id);
    assert_eq!(state, expected);
}

#[test]
fn test_state_defeated_quorum_not_reached() {
    let mut mock_state = CONTRACT_STATE();
    let component_state = COMPONENT_STATE();
    let (id, proposal) = get_proposal_info();

    mock_state.governor.Governor_proposals.write(id, proposal);

    let deadline = proposal.vote_start + proposal.vote_duration;
    let expected = ProposalState::Defeated;

    start_cheat_block_timestamp_global(deadline + 1);

    // Quorum not reached
    let quorum = GovernorTimelockedMock::QUORUM;
    let proposal_votes = mock_state.governor_counting_simple.Governor_proposals_votes.entry(id);
    proposal_votes.for_votes.write(quorum - 1);

    let state = GovernorExecution::state(@component_state, id);
    assert_eq!(state, expected);
}

#[test]
fn test_state_defeated_vote_not_succeeded() {
    let mut mock_state = CONTRACT_STATE();
    let component_state = COMPONENT_STATE();
    let (id, proposal) = get_proposal_info();

    mock_state.governor.Governor_proposals.write(id, proposal);

    let deadline = proposal.vote_start + proposal.vote_duration;
    let expected = ProposalState::Defeated;

    start_cheat_block_timestamp_global(deadline + 1);

    // Quorum reached
    let quorum = GovernorTimelockedMock::QUORUM;
    let proposal_votes = mock_state.governor_counting_simple.Governor_proposals_votes.entry(id);
    proposal_votes.for_votes.write(quorum + 1);

    // Vote not succeeded
    proposal_votes.against_votes.write(quorum + 1);

    let state = GovernorExecution::state(@component_state, id);
    assert_eq!(state, expected);
}

#[test]
fn test_state_queued_timelock_waiting() {
    let mut mock_state = CONTRACT_STATE();
    let component_state = COMPONENT_STATE();
    let id = setup_queued_proposal(ref mock_state);

    // 1. Mock the timelock to return pending
    set_executor(ref mock_state, TIMELOCK());
    start_mock_call(TIMELOCK(), selector!("get_operation_state"), OperationState::Waiting);

    let state = GovernorExecution::state(@component_state, id);
    assert_eq!(state, ProposalState::Queued);
}

#[test]
fn test_state_queued_timelock_ready() {
    let mut mock_state = CONTRACT_STATE();
    let component_state = COMPONENT_STATE();
    let id = setup_queued_proposal(ref mock_state);

    // 1. Mock the timelock to return pending
    set_executor(ref mock_state, TIMELOCK());
    start_mock_call(TIMELOCK(), selector!("get_operation_state"), OperationState::Ready);

    let state = GovernorExecution::state(@component_state, id);
    assert_eq!(state, ProposalState::Queued);
}

#[test]
fn test_state_queued_timelock_done() {
    let mut mock_state = CONTRACT_STATE();
    let component_state = COMPONENT_STATE();
    let id = setup_queued_proposal(ref mock_state);

    // 1. Mock the timelock to return pending
    set_executor(ref mock_state, TIMELOCK());
    start_mock_call(TIMELOCK(), selector!("get_operation_state"), OperationState::Done);

    let state = GovernorExecution::state(@component_state, id);
    assert_eq!(state, ProposalState::Executed);
}

#[test]
fn test_state_queued_timelock_canceled() {
    let mut mock_state = CONTRACT_STATE();
    let component_state = COMPONENT_STATE();
    let id = setup_queued_proposal(ref mock_state);

    // 1. Mock the timelock to return pending
    set_executor(ref mock_state, TIMELOCK());
    start_mock_call(TIMELOCK(), selector!("get_operation_state"), OperationState::Unset);

    let state = GovernorExecution::state(@component_state, id);
    assert_eq!(state, ProposalState::Canceled);
}

#[test]
fn test_state_succeeded() {
    let mut mock_state = CONTRACT_STATE();
    let component_state = COMPONENT_STATE();
    let id = setup_succeeded_proposal(ref mock_state);

    let state = GovernorExecution::state(@component_state, id);
    assert_eq!(state, ProposalState::Succeeded);
}

//
// executor
//

#[test]
fn test_executor() {
    let mut mock_state = CONTRACT_STATE();
    let component_state = COMPONENT_STATE();
    let expected = TIMELOCK();

    set_executor(ref mock_state, expected);

    assert_eq!(GovernorExecution::executor(@component_state), expected);
}

//
// execute_operations
//

#[test]
fn test_execute_operations() {
    let (mut governor, timelock, target) = setup_dispatchers();
    let timelocked = ITimelockedDispatcher { contract_address: governor.contract_address };

    let new_number = 125;

    let call = Call {
        to: target.contract_address,
        selector: selector!("set_number"),
        calldata: array![new_number].span()
    };
    let calls = array![call].span();
    let description = "proposal description";

    let number = target.get_number();
    assert_eq!(number, 0);

    // 1. Mock the get_past_votes call
    let quorum = GovernorTimelockedMock::QUORUM;
    start_mock_call(VOTES_TOKEN(), selector!("get_past_votes"), quorum);

    // 2. Propose
    let mut current_time = 10;
    start_cheat_block_timestamp_global(current_time);
    let id = governor.propose(calls, description.clone());

    // 3. Cast vote

    // Fast forward the vote delay
    current_time += GovernorTimelockedMock::VOTING_DELAY;
    start_cheat_block_timestamp_global(current_time);

    // Cast vote
    governor.cast_vote(id, 1);

    // 4. Queue

    // Fast forward the vote duration
    current_time += (GovernorTimelockedMock::VOTING_PERIOD + 1);
    start_cheat_block_timestamp_global(current_time);

    let state = governor.state(id);
    assert_eq!(state, ProposalState::Succeeded);

    governor.queue(calls, (@description).hash());

    let target_id = timelocked.get_timelock_id(id);
    let salt = timelock_salt(governor.contract_address, (@description).hash());

    let state = governor.state(id);
    assert_eq!(state, ProposalState::Queued);

    // 5. Execute
    // Fast forward the timelock delay
    current_time += MIN_DELAY;
    start_cheat_block_timestamp_global(current_time);

    let mut spy = spy_events();
    governor.execute(calls, (@description).hash());

    // 6. Assertions
    let number = target.get_number();
    assert_eq!(number, new_number);

    let state = governor.state(id);
    assert_eq!(state, ProposalState::Executed);

    let target_id = timelocked.get_timelock_id(id);
    assert_eq!(target_id, 0);

    spy.assert_only_events_call_executed_batch(timelock.contract_address, target_id, calls);
}

//
// queue_operations
//

#[test]
fn test_queue_operations() {
    let (mut governor, timelock, target) = setup_dispatchers();
    let timelocked = ITimelockedDispatcher { contract_address: governor.contract_address };

    let new_number = 125;

    let call = Call {
        to: target.contract_address,
        selector: selector!("set_number"),
        calldata: array![new_number].span()
    };
    let calls = array![call].span();
    let description = "proposal description";

    let number = target.get_number();
    assert_eq!(number, 0);

    // 1. Mock the get_past_votes call
    let quorum = GovernorTimelockedMock::QUORUM;
    start_mock_call(VOTES_TOKEN(), selector!("get_past_votes"), quorum);

    // 2. Propose
    let mut current_time = 10;
    start_cheat_block_timestamp_global(current_time);
    let id = governor.propose(calls, description.clone());

    // 3. Cast vote

    // Fast forward the vote delay
    current_time += GovernorTimelockedMock::VOTING_DELAY;
    start_cheat_block_timestamp_global(current_time);

    // Cast vote
    governor.cast_vote(id, 1);

    // 4. Queue

    // Fast forward the vote duration
    current_time += (GovernorTimelockedMock::VOTING_PERIOD + 1);
    start_cheat_block_timestamp_global(current_time);

    let state = governor.state(id);
    assert_eq!(state, ProposalState::Succeeded);

    let mut spy = spy_events();

    governor.queue(calls, (@description).hash());

    let target_id = timelocked.get_timelock_id(id);
    let salt = timelock_salt(governor.contract_address, (@description).hash());
    spy.assert_event_call_scheduled(timelock.contract_address, target_id, 0, call, 0, MIN_DELAY);
    spy.assert_event_call_salt(timelock.contract_address, target_id, salt);
    spy.assert_only_event_proposal_queued(governor.contract_address, id, current_time + MIN_DELAY);

    let state = governor.state(id);
    assert_eq!(state, ProposalState::Queued);
}

//
// proposal_needs_queuing
//

#[test]
fn test_proposal_needs_queuing(id: felt252) {
    let component_state = COMPONENT_STATE();

    assert_eq!(GovernorExecution::proposal_needs_queuing(@component_state, id), true);
}

//
// cancel_operations
//

#[test]
fn test_cancel_operations_pending() {
    let mut state = COMPONENT_STATE();
    let id = setup_pending_proposal(ref state);

    GovernorExecution::cancel_operations(ref state, id, 0);

    let canceled_proposal = state.get_proposal(id);
    assert_eq!(canceled_proposal.canceled, true);
}

#[test]
fn test_cancel_operations_active() {
    let mut state = COMPONENT_STATE();
    let id = setup_active_proposal(ref state);

    GovernorExecution::cancel_operations(ref state, id, 0);

    let canceled_proposal = state.get_proposal(id);
    assert_eq!(canceled_proposal.canceled, true);
}

#[test]
fn test_cancel_operations_defeated() {
    let mut mock_state = CONTRACT_STATE();
    let mut state = COMPONENT_STATE();
    let id = setup_defeated_proposal(ref mock_state);

    GovernorExecution::cancel_operations(ref state, id, 0);

    let canceled_proposal = mock_state.governor.get_proposal(id);
    assert_eq!(canceled_proposal.canceled, true);
}

#[test]
fn test_cancel_operations_succeeded() {
    let mut mock_state = CONTRACT_STATE();
    let mut state = COMPONENT_STATE();
    let id = setup_succeeded_proposal(ref mock_state);

    GovernorExecution::cancel_operations(ref state, id, 0);

    let canceled_proposal = mock_state.governor.get_proposal(id);
    assert_eq!(canceled_proposal.canceled, true);
}

#[test]
fn test_cancel_operations_queued() {
    let mut mock_state = CONTRACT_STATE();
    let mut state = COMPONENT_STATE();
    let id = setup_queued_proposal(ref mock_state);

    GovernorExecution::cancel_operations(ref state, id, 0);

    let canceled_proposal = mock_state.governor.get_proposal(id);
    assert_eq!(canceled_proposal.canceled, true);
}

#[test]
#[should_panic(expected: 'Unexpected proposal state')]
fn test_cancel_operations_canceled() {
    let mut state = COMPONENT_STATE();
    let id = setup_canceled_proposal(ref state);

    // Cancel again
    GovernorExecution::cancel_operations(ref state, id, 0);
}

#[test]
#[should_panic(expected: 'Unexpected proposal state')]
fn test_cancel_operations_executed() {
    let mut state = COMPONENT_STATE();
    let id = setup_executed_proposal(ref state);

    GovernorExecution::cancel_operations(ref state, id, 0);
}

//
// Helpers
//

fn timelock_salt(contract_address: ContractAddress, description_hash: felt252) -> felt252 {
    let description_hash: u256 = description_hash.into();
    let contract_address: felt252 = contract_address.into();

    (contract_address.into() ^ description_hash).try_into().unwrap()
}

//
// Setup proposals
//

pub fn setup_pending_proposal(ref state: ComponentStateTimelocked) -> felt252 {
    let (id, proposal) = get_proposal_info();

    state.Governor_proposals.write(id, proposal);

    let current_state = state._state(id);
    let expected = ProposalState::Pending;

    assert_eq!(current_state, expected);

    id
}

pub fn setup_active_proposal(ref state: ComponentStateTimelocked) -> felt252 {
    let (id, proposal) = get_proposal_info();

    state.Governor_proposals.write(id, proposal);

    let deadline = proposal.vote_start + proposal.vote_duration;
    let expected = ProposalState::Active;

    // Is active before deadline
    start_cheat_block_timestamp_global(deadline - 1);
    let current_state = state._state(id);
    assert_eq!(current_state, expected);

    id
}

pub fn setup_queued_proposal(ref mock_state: GovernorTimelockedMock::ContractState) -> felt252 {
    let (id, mut proposal) = get_proposal_info();

    proposal.eta_seconds = 1;
    mock_state.governor.Governor_proposals.write(id, proposal);

    let deadline = proposal.vote_start + proposal.vote_duration;

    // Quorum reached
    start_cheat_block_timestamp_global(deadline + 1);
    let quorum = GovernorTimelockedMock::QUORUM;
    let proposal_votes = mock_state.governor_counting_simple.Governor_proposals_votes.entry(id);
    proposal_votes.for_votes.write(quorum + 1);

    // Vote succeeded
    proposal_votes.against_votes.write(quorum);

    let expected = ProposalState::Queued;
    let current_state = mock_state.governor._state(id);
    assert_eq!(current_state, expected);

    id
}

pub fn setup_canceled_proposal(ref state: ComponentStateTimelocked) -> felt252 {
    let (id, proposal) = get_proposal_info();

    state.Governor_proposals.write(id, proposal);

    state._cancel(id, 0);

    let expected = ProposalState::Canceled;
    let current_state = state._state(id);
    assert_eq!(current_state, expected);

    id
}

pub fn setup_defeated_proposal(ref mock_state: GovernorTimelockedMock::ContractState) -> felt252 {
    let (id, proposal) = get_proposal_info();

    mock_state.governor.Governor_proposals.write(id, proposal);

    let deadline = proposal.vote_start + proposal.vote_duration;

    // Quorum not reached
    start_cheat_block_timestamp_global(deadline + 1);
    let quorum = GovernorTimelockedMock::QUORUM;
    let proposal_votes = mock_state.governor_counting_simple.Governor_proposals_votes.entry(id);
    proposal_votes.for_votes.write(quorum - 1);

    let expected = ProposalState::Defeated;
    let current_state = mock_state.governor._state(id);
    assert_eq!(current_state, expected);

    id
}

pub fn setup_succeeded_proposal(ref mock_state: GovernorTimelockedMock::ContractState) -> felt252 {
    let (id, proposal) = get_proposal_info();

    mock_state.governor.Governor_proposals.write(id, proposal);

    let deadline = proposal.vote_start + proposal.vote_duration;
    let expected = ProposalState::Succeeded;

    start_cheat_block_timestamp_global(deadline + 1);

    // Quorum reached
    let quorum = GovernorTimelockedMock::QUORUM;
    let proposal_votes = mock_state.governor_counting_simple.Governor_proposals_votes.entry(id);
    proposal_votes.for_votes.write(quorum + 1);

    // Vote succeeded
    proposal_votes.against_votes.write(quorum);

    let current_state = mock_state.governor._state(id);
    assert_eq!(current_state, expected);

    id
}

pub fn setup_executed_proposal(ref state: ComponentStateTimelocked) -> felt252 {
    let (id, mut proposal) = get_proposal_info();

    proposal.executed = true;
    state.Governor_proposals.write(id, proposal);

    let current_state = state._state(id);
    let expected = ProposalState::Executed;

    assert_eq!(current_state, expected);

    id
}
