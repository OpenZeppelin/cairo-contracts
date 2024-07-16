use core::hash::{HashStateTrait, HashStateExTrait};
use core::num::traits::Zero;
use core::poseidon::PoseidonTrait;
use openzeppelin::access::accesscontrol::AccessControlComponent::{
    AccessControlImpl, InternalImpl as AccessControlInternalImpl
};
use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
use openzeppelin::access::accesscontrol::interface::IACCESSCONTROL_ID;
use openzeppelin::access::accesscontrol::interface::IAccessControl;
use openzeppelin::governance::timelock::OperationState;
use openzeppelin::governance::timelock::TimelockControllerComponent::{
    CallScheduled, CallExecuted, CallSalt, CallCancelled, MinDelayChanged
};
use openzeppelin::governance::timelock::TimelockControllerComponent::{
    TimelockImpl, InternalImpl as TimelockInternalImpl
};
use openzeppelin::governance::timelock::TimelockControllerComponent;
use openzeppelin::governance::timelock::interface::{
    TimelockABIDispatcher, TimelockABIDispatcherTrait
};
use openzeppelin::governance::timelock::{PROPOSER_ROLE, EXECUTOR_ROLE, CANCELLER_ROLE};
use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin::tests::mocks::timelock_mocks::MockContract;
use openzeppelin::tests::mocks::timelock_mocks::{
    IMockContractDispatcher, IMockContractDispatcherTrait
};
use openzeppelin::tests::mocks::timelock_mocks::{
    ITimelockAttackerDispatcher, ITimelockAttackerDispatcherTrait
};
use openzeppelin::tests::mocks::timelock_mocks::{TimelockControllerMock, TimelockAttackerMock};
use openzeppelin::tests::utils::constants::{ADMIN, ZERO, OTHER, SALT};
use openzeppelin::tests::utils;
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;
use starknet::account::Call;
use starknet::contract_address_const;
use starknet::testing;

type ComponentState =
    TimelockControllerComponent::ComponentState<TimelockControllerMock::ContractState>;

fn CONTRACT_STATE() -> TimelockControllerMock::ContractState {
    TimelockControllerMock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    TimelockControllerComponent::component_state_for_testing()
}

//
// Constants
//

const MIN_DELAY: u64 = 1000;
const NEW_DELAY: u64 = 2000;
const VALUE: felt252 = 'VALUE';
const NO_PREDECESSOR: felt252 = 0;

//
// Addresses
//

fn PROPOSER() -> ContractAddress {
    contract_address_const::<'PROPOSER'>()
}

fn EXECUTOR() -> ContractAddress {
    contract_address_const::<'EXECUTOR'>()
}

fn get_proposers() -> (ContractAddress, ContractAddress, ContractAddress) {
    let p1 = contract_address_const::<'PROPOSER_1'>();
    let p2 = contract_address_const::<'PROPOSER_2'>();
    let p3 = contract_address_const::<'PROPOSER_3'>();
    (p1, p2, p3)
}

fn get_executors() -> (ContractAddress, ContractAddress, ContractAddress) {
    let e1 = contract_address_const::<'EXECUTOR_1'>();
    let e2 = contract_address_const::<'EXECUTOR_2'>();
    let e3 = contract_address_const::<'EXECUTOR_3'>();
    (e1, e2, e3)
}

//
// Operations
//

fn single_operation(target: ContractAddress) -> Call {
    let mut calldata = array![];
    calldata.append_serde(VALUE);

    Call { to: target, selector: selector!("set_number"), calldata: calldata.span() }
}

fn batched_operations(target: ContractAddress) -> Span<Call> {
    let mut calls = array![];
    let call = single_operation(target);
    calls.append(call);
    calls.append(call);
    calls.append(call);

    calls.span()
}

fn failing_operation(target: ContractAddress) -> Call {
    let mut calldata = array![];

    Call { to: target, selector: selector!("failing_function"), calldata: calldata.span() }
}

fn operation_with_bad_selector(target: ContractAddress) -> Call {
    let mut calldata = array![];

    Call { to: target, selector: selector!("bad_selector"), calldata: calldata.span() }
}

//
// Dispatchers
//

fn deploy_timelock() -> TimelockABIDispatcher {
    let mut calldata = array![];

    let proposers = array![PROPOSER()].span();
    let executors = array![EXECUTOR()].span();
    let admin = ADMIN();

    calldata.append_serde(MIN_DELAY);
    calldata.append_serde(proposers);
    calldata.append_serde(executors);
    calldata.append_serde(admin);

    let address = utils::deploy(TimelockControllerMock::TEST_CLASS_HASH, calldata);
    // Events dropped:
    // - 5 RoleGranted: self, proposer, canceller, executor, admin
    // - MinDelayChanged
    utils::drop_events(address, 6);
    TimelockABIDispatcher { contract_address: address }
}

fn deploy_mock_target() -> IMockContractDispatcher {
    let mut calldata = array![];

    let address = utils::deploy(MockContract::TEST_CLASS_HASH, calldata);
    IMockContractDispatcher { contract_address: address }
}

fn setup_dispatchers() -> (TimelockABIDispatcher, IMockContractDispatcher) {
    let timelock = deploy_timelock();
    let target = deploy_mock_target();

    (timelock, target)
}

fn deploy_attacker() -> ITimelockAttackerDispatcher {
    let mut calldata = array![];

    let address = utils::deploy(TimelockAttackerMock::TEST_CLASS_HASH, calldata);
    ITimelockAttackerDispatcher { contract_address: address }
}

//
// hash_operation
//

#[test]
fn test_hash_operation() {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = 123;
    let salt = SALT;

    // Set up call
    let mut calldata = array![];
    calldata.append_serde(VALUE);
    let mut call = Call {
        to: target.contract_address, selector: selector!("set_number"), calldata: calldata.span()
    };

    // Hash operation
    let hashed_operation = timelock.hash_operation(call, predecessor, salt);

    // Manually set hash elements
    let mut expected_hash = PoseidonTrait::new()
        .update_with(target.contract_address) // call::to
        .update_with(selector!("set_number")) // call::selector
        .update_with(1) // call::calldata.len
        .update_with(VALUE) // call::calldata::number
        .update_with(predecessor) // predecessor
        .update_with(salt) // salt
        .finalize();

    assert_eq!(hashed_operation, expected_hash);
}

#[test]
fn test_hash_operation_batch() {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = 123;
    let salt = SALT;

    // Set up calls
    let mut calldata = array![];
    calldata.append_serde(VALUE);
    let mut call = Call {
        to: target.contract_address, selector: selector!("set_number"), calldata: calldata.span()
    };
    let calls = array![call, call, call].span();

    // Hash operation
    let hashed_operation = timelock.hash_operation_batch(calls, predecessor, salt);

    // Manually set hash elements
    let mut expected_hash = PoseidonTrait::new()
        .update_with(3) // total number of Calls
        .update_with(target.contract_address) // call::to
        .update_with(selector!("set_number")) // call::selector
        .update_with(1) // call::calldata.len
        .update_with(VALUE) // call::calldata::number
        .update_with(target.contract_address) // call::to
        .update_with(selector!("set_number")) // call::selector
        .update_with(1) // call::calldata.len
        .update_with(VALUE) // call::calldata::number
        .update_with(target.contract_address) // call::to
        .update_with(selector!("set_number")) // call::selector
        .update_with(1) // call::calldata.len
        .update_with(VALUE) // call::calldata::number
        .update_with(predecessor) // predecessor
        .update_with(salt) // salt
        .finalize();

    assert_eq!(hashed_operation, expected_hash);
}

//
// schedule
//

fn schedule_from_proposer(salt: felt252) {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let delay = MIN_DELAY;
    let mut salt = salt;

    // Set up call
    let call = single_operation(target.contract_address);
    let target_id = timelock.hash_operation(call, predecessor, salt);
    assert_operation_state(timelock, OperationState::Unset, target_id);

    // Schedule
    testing::set_contract_address(PROPOSER());
    timelock.schedule(call, predecessor, salt, delay);
    assert_operation_state(timelock, OperationState::Waiting, target_id);

    // Check timestamp
    let operation_ts = timelock.get_timestamp(target_id);
    let expected_ts = starknet::get_block_timestamp() + delay;
    assert_eq!(operation_ts, expected_ts);

    // Check event(s)
    let event_index = 0;
    if salt != 0 {
        assert_event_schedule(
            timelock.contract_address, target_id, event_index, call, predecessor, delay
        );
        assert_only_event_call_salt(timelock.contract_address, target_id, salt);
    } else {
        assert_only_event_schedule(
            timelock.contract_address, target_id, event_index, call, predecessor, delay
        );
    }
}

#[test]
fn test_schedule_from_proposer_with_salt() {
    let salt = SALT;
    schedule_from_proposer(salt);
}

#[test]
fn test_schedule_from_proposer_no_salt() {
    let salt = 0;
    schedule_from_proposer(salt);
}

#[test]
#[should_panic(expected: ('Timelock: expected Unset op', 'ENTRYPOINT_FAILED'))]
fn test_schedule_overwrite() {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let salt = SALT;
    let delay = MIN_DELAY;

    let call = single_operation(target.contract_address);

    testing::set_contract_address(PROPOSER());
    timelock.schedule(call, predecessor, salt, delay);
    timelock.schedule(call, predecessor, salt, delay);
}

#[test]
#[should_panic(expected: ('Caller is missing role', 'ENTRYPOINT_FAILED'))]
fn test_schedule_unauthorized() {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let salt = SALT;
    let delay = MIN_DELAY;

    let call = single_operation(target.contract_address);

    testing::set_contract_address(OTHER());
    timelock.schedule(call, predecessor, salt, delay);
}

#[test]
#[should_panic(expected: ('Timelock: insufficient delay', 'ENTRYPOINT_FAILED'))]
fn test_schedule_bad_min_delay() {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let salt = SALT;
    let bad_delay = MIN_DELAY - 1;

    let call = single_operation(target.contract_address);

    testing::set_contract_address(PROPOSER());
    timelock.schedule(call, predecessor, salt, bad_delay);
}

//
// schedule_batch
//

fn schedule_batch_from_proposer(salt: felt252) {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let delay = MIN_DELAY;
    let mut salt = salt;

    // Set up calls
    let calls = batched_operations(target.contract_address);
    let target_id = timelock.hash_operation_batch(calls, predecessor, salt);
    assert_operation_state(timelock, OperationState::Unset, target_id);

    // Schedule batch
    testing::set_contract_address(PROPOSER());
    timelock.schedule_batch(calls, predecessor, salt, delay);
    assert_operation_state(timelock, OperationState::Waiting, target_id);

    // Check timestamp
    let operation_ts = timelock.get_timestamp(target_id);
    let expected_ts = starknet::get_block_timestamp() + delay;
    assert_eq!(operation_ts, expected_ts);

    // Check events
    if salt != 0 {
        assert_events_schedule_batch(
            timelock.contract_address, target_id, calls, predecessor, delay
        );
        assert_only_event_call_salt(timelock.contract_address, target_id, salt);
    } else {
        assert_only_events_schedule_batch(
            timelock.contract_address, target_id, calls, predecessor, delay
        );
    }
}

#[test]
fn test_schedule_batch_from_proposer_with_salt() {
    let salt = SALT;
    schedule_batch_from_proposer(salt);
}

#[test]
fn test_schedule_batch_from_proposer_no_salt() {
    let no_salt = 0;
    schedule_batch_from_proposer(no_salt);
}

#[test]
#[should_panic(expected: ('Timelock: expected Unset op', 'ENTRYPOINT_FAILED'))]
fn test_schedule_batch_overwrite() {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let salt = SALT;
    let delay = MIN_DELAY;

    let calls = batched_operations(target.contract_address);

    testing::set_contract_address(PROPOSER());
    timelock.schedule_batch(calls, predecessor, salt, delay);
    timelock.schedule_batch(calls, predecessor, salt, delay);
}

#[test]
#[should_panic(expected: ('Caller is missing role', 'ENTRYPOINT_FAILED'))]
fn test_schedule_batch_unauthorized() {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let salt = SALT;
    let delay = MIN_DELAY;

    let calls = batched_operations(target.contract_address);

    testing::set_contract_address(OTHER());
    timelock.schedule_batch(calls, predecessor, salt, delay);
}

#[test]
#[should_panic(expected: ('Timelock: insufficient delay', 'ENTRYPOINT_FAILED'))]
fn test_schedule_batch_bad_min_delay() {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let salt = SALT;
    let bad_delay = MIN_DELAY - 1;

    let calls = batched_operations(target.contract_address);

    testing::set_contract_address(PROPOSER());
    timelock.schedule_batch(calls, predecessor, salt, bad_delay);
}

//
// execute
//

#[test]
#[should_panic(expected: ('Timelock: expected Ready op', 'ENTRYPOINT_FAILED'))]
fn test_execute_when_not_scheduled() {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let salt = 0;

    let call = single_operation(target.contract_address);

    testing::set_contract_address(EXECUTOR());
    timelock.execute(call, predecessor, salt);
}

#[test]
fn test_execute_when_scheduled() {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let salt = 0;
    let delay = MIN_DELAY;
    let event_index = 0;

    // Set up call
    let call = single_operation(target.contract_address);
    let target_id = timelock.hash_operation(call, predecessor, salt);
    assert_operation_state(timelock, OperationState::Unset, target_id);

    // Schedule
    testing::set_contract_address(PROPOSER());
    timelock.schedule(call, predecessor, salt, delay);
    assert_only_event_schedule(
        timelock.contract_address, target_id, event_index, call, predecessor, delay
    );
    assert_operation_state(timelock, OperationState::Waiting, target_id);

    // Fast-forward
    testing::set_block_timestamp(delay);
    assert_operation_state(timelock, OperationState::Ready, target_id);

    // Check initial target state
    let check_target = target.get_number();
    assert_eq!(check_target, 0);

    // Execute
    testing::set_contract_address(EXECUTOR());
    timelock.execute(call, predecessor, salt);

    assert_operation_state(timelock, OperationState::Done, target_id);
    assert_only_event_execute(timelock.contract_address, target_id, event_index, call);

    // Check target state updates
    let check_target = target.get_number();
    assert_eq!(check_target, VALUE);
}

#[test]
#[should_panic(expected: ('Timelock: expected Ready op', 'ENTRYPOINT_FAILED'))]
fn test_execute_early() {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let salt = 0;
    let delay = MIN_DELAY;

    let call = single_operation(target.contract_address);

    // Schedule
    testing::set_contract_address(PROPOSER());
    timelock.schedule(call, predecessor, salt, delay);

    // Fast-forward
    let early_time = delay - 1;
    testing::set_block_timestamp(early_time);

    // Execute
    testing::set_contract_address(EXECUTOR());
    timelock.execute(call, predecessor, salt);
}

#[test]
#[should_panic(expected: ('Caller is missing role', 'ENTRYPOINT_FAILED'))]
fn test_execute_unauthorized() {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let salt = 0;
    let delay = MIN_DELAY;

    let call = single_operation(target.contract_address);

    // Schedule
    testing::set_contract_address(PROPOSER());
    timelock.schedule(call, predecessor, salt, delay);

    // Fast-forward
    testing::set_block_timestamp(delay);

    // Execute
    testing::set_contract_address(OTHER());
    timelock.execute(call, predecessor, salt);
}

#[test]
#[should_panic(expected: ('Expected failure', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_execute_failing_tx() {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let salt = 0;
    let delay = MIN_DELAY;

    // Set up call
    let call = failing_operation(target.contract_address);
    let target_id = timelock.hash_operation(call, predecessor, salt);

    // Schedule
    testing::set_contract_address(PROPOSER());
    timelock.schedule(call, predecessor, salt, delay);

    // Fast-forward
    testing::set_block_timestamp(delay);
    assert_operation_state(timelock, OperationState::Ready, target_id);

    // Execute
    testing::set_contract_address(EXECUTOR());
    timelock.execute(call, predecessor, salt);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', 'ENTRYPOINT_FAILED'))]
fn test_execute_bad_selector() {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let salt = 0;
    let delay = MIN_DELAY;

    // Set up call
    let call = operation_with_bad_selector(target.contract_address);
    let target_id = timelock.hash_operation(call, predecessor, salt);

    // Schedule
    testing::set_contract_address(PROPOSER());
    timelock.schedule(call, predecessor, salt, delay);

    // Fast-forward
    testing::set_block_timestamp(delay);
    assert_operation_state(timelock, OperationState::Ready, target_id);

    // Execute
    testing::set_contract_address(EXECUTOR());
    timelock.execute(call, predecessor, salt);
}

#[test]
#[should_panic(
    expected: (
        'Timelock: expected Ready op', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'
    )
)]
fn test_execute_reentrant_call() {
    let mut timelock = deploy_timelock();
    let mut attacker = deploy_attacker();
    let predecessor = NO_PREDECESSOR;
    let salt = 0;
    let delay = MIN_DELAY;

    let reentrant_call = Call {
        to: attacker.contract_address, selector: selector!("reenter"), calldata: array![].span()
    };

    // Schedule
    testing::set_contract_address(PROPOSER());
    timelock.schedule(reentrant_call, predecessor, salt, delay);

    // Fast-forward
    testing::set_block_timestamp(delay);

    // Grant executor role to attacker
    testing::set_contract_address(ADMIN());
    timelock.grant_role(EXECUTOR_ROLE, attacker.contract_address);

    // Attempt reentrant call
    testing::set_contract_address(EXECUTOR());
    timelock.execute(reentrant_call, predecessor, salt);
}

#[test]
#[should_panic(expected: ('Timelock: awaiting predecessor', 'ENTRYPOINT_FAILED'))]
fn test_execute_before_dependency() {
    let (mut timelock, mut target) = setup_dispatchers();
    let salt = 0;
    let delay = MIN_DELAY;

    // Call 1
    let call_1 = single_operation(target.contract_address);
    let predecessor_1 = NO_PREDECESSOR;
    let target_id_1 = timelock.hash_operation(call_1, predecessor_1, salt);

    // Call 2
    let call_2 = single_operation(target.contract_address);
    let predecessor_2 = target_id_1;
    let target_id_2 = timelock.hash_operation(call_2, predecessor_2, salt);

    // Schedule call 1
    testing::set_contract_address(PROPOSER());
    timelock.schedule(call_1, predecessor_1, salt, delay);

    // Schedule call 2
    timelock.schedule(call_2, predecessor_2, salt, delay);

    // Fast-forward
    testing::set_block_timestamp(delay);
    assert_operation_state(timelock, OperationState::Ready, target_id_1);
    assert_operation_state(timelock, OperationState::Ready, target_id_2);

    // Execute
    testing::set_contract_address(EXECUTOR());
    timelock.execute(call_2, predecessor_2, salt);
}

#[test]
fn test_execute_after_dependency() {
    let (mut timelock, mut target) = setup_dispatchers();
    let salt = 0;
    let delay = MIN_DELAY;
    let event_index = 0;

    // Call 1
    let call_1 = single_operation(target.contract_address);
    let predecessor_1 = NO_PREDECESSOR;
    let target_id_1 = timelock.hash_operation(call_1, predecessor_1, salt);
    assert_operation_state(timelock, OperationState::Unset, target_id_1);

    // Call 2
    let call_2 = single_operation(target.contract_address);
    let predecessor_2 = target_id_1;
    let target_id_2 = timelock.hash_operation(call_2, predecessor_2, salt);
    assert_operation_state(timelock, OperationState::Unset, target_id_2);

    // Schedule call 1
    testing::set_contract_address(PROPOSER());
    timelock.schedule(call_1, predecessor_1, salt, delay);
    assert_operation_state(timelock, OperationState::Waiting, target_id_1);
    assert_only_event_schedule(
        timelock.contract_address, target_id_1, event_index, call_1, predecessor_1, delay
    );

    // Schedule call 2
    timelock.schedule(call_2, predecessor_2, salt, delay);
    assert_operation_state(timelock, OperationState::Waiting, target_id_2);
    assert_only_event_schedule(
        timelock.contract_address, target_id_2, event_index, call_2, predecessor_2, delay
    );

    // Fast-forward
    testing::set_block_timestamp(delay);
    assert_operation_state(timelock, OperationState::Ready, target_id_1);
    assert_operation_state(timelock, OperationState::Ready, target_id_2);

    // Execute call 1
    testing::set_contract_address(EXECUTOR());
    timelock.execute(call_1, predecessor_1, salt);
    assert_operation_state(timelock, OperationState::Done, target_id_1);
    assert_event_execute(timelock.contract_address, target_id_1, event_index, call_1);

    // Execute call 2
    timelock.execute(call_2, predecessor_2, salt);
    assert_operation_state(timelock, OperationState::Done, target_id_2);
    assert_only_event_execute(timelock.contract_address, target_id_2, event_index, call_2);
}

//
// execute_batch
//

#[test]
#[should_panic(expected: ('Timelock: expected Ready op', 'ENTRYPOINT_FAILED'))]
fn test_execute_batch_when_not_scheduled() {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let salt = 0;

    let calls = batched_operations(target.contract_address);

    testing::set_contract_address(EXECUTOR());
    timelock.execute_batch(calls, predecessor, salt);
}

#[test]
fn test_execute_batch_when_scheduled() {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let salt = 0;
    let delay = MIN_DELAY;

    // Set up call
    let calls = batched_operations(target.contract_address);
    let target_id = timelock.hash_operation_batch(calls, predecessor, salt);
    assert_operation_state(timelock, OperationState::Unset, target_id);

    // Schedule
    testing::set_contract_address(PROPOSER());
    timelock.schedule_batch(calls, predecessor, salt, delay);
    assert_operation_state(timelock, OperationState::Waiting, target_id);
    assert_only_events_schedule_batch(
        timelock.contract_address, target_id, calls, predecessor, delay
    );

    // Fast-forward
    testing::set_block_timestamp(delay);
    assert_operation_state(timelock, OperationState::Ready, target_id);

    // Check initial target state
    let check_target = target.get_number();
    assert_eq!(check_target, 0);

    // Execute
    testing::set_contract_address(EXECUTOR());
    timelock.execute_batch(calls, predecessor, salt);
    assert_operation_state(timelock, OperationState::Done, target_id);
    assert_only_events_execute_batch(timelock.contract_address, target_id, calls);

    // Check target state updates
    let check_target = target.get_number();
    assert_eq!(check_target, VALUE);
}

#[test]
#[should_panic(expected: ('Timelock: expected Ready op', 'ENTRYPOINT_FAILED'))]
fn test_execute_batch_early() {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let salt = 0;
    let delay = MIN_DELAY;

    let calls = batched_operations(target.contract_address);

    // Schedule
    testing::set_contract_address(PROPOSER());
    timelock.schedule_batch(calls, predecessor, salt, delay);

    // Fast-forward
    let early_time = delay - 1;
    testing::set_block_timestamp(early_time);

    // Execute
    testing::set_contract_address(EXECUTOR());
    timelock.execute_batch(calls, predecessor, salt);
}

#[test]
#[should_panic(expected: ('Caller is missing role', 'ENTRYPOINT_FAILED'))]
fn test_execute_batch_unauthorized() {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let salt = 0;
    let delay = MIN_DELAY;

    let calls = batched_operations(target.contract_address);

    // Schedule
    testing::set_contract_address(PROPOSER());
    timelock.schedule_batch(calls, predecessor, salt, delay);

    // Fast-forward
    testing::set_block_timestamp(delay);

    // Execute
    testing::set_contract_address(OTHER());
    timelock.execute_batch(calls, predecessor, salt);
}

#[test]
#[should_panic(
    expected: (
        'Timelock: expected Ready op', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'
    )
)]
fn test_execute_batch_reentrant_call() {
    let mut timelock = deploy_timelock();
    let mut attacker = deploy_attacker();
    let predecessor = NO_PREDECESSOR;
    let salt = 0;
    let delay = MIN_DELAY;

    let reentrant_call = Call {
        to: attacker.contract_address,
        selector: selector!("reenter_batch"),
        calldata: array![].span()
    };
    let calls = array![reentrant_call].span();

    // Schedule
    testing::set_contract_address(PROPOSER());
    timelock.schedule_batch(calls, predecessor, salt, delay);

    // Fast-forward
    testing::set_block_timestamp(delay);

    // Grant executor role to attacker
    testing::set_contract_address(ADMIN());
    timelock.grant_role(EXECUTOR_ROLE, attacker.contract_address);

    // Attempt reentrant call
    testing::set_contract_address(EXECUTOR());
    timelock.execute_batch(calls, predecessor, salt);
}

#[test]
#[should_panic(expected: ('Expected failure', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_execute_batch_partial_execution() {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let salt = 0;
    let delay = MIN_DELAY;

    let good_call = single_operation(target.contract_address);
    let bad_call = failing_operation(target.contract_address);
    let calls = array![good_call, bad_call].span();

    // Schedule
    testing::set_contract_address(PROPOSER());
    timelock.schedule_batch(calls, predecessor, salt, delay);

    // Fast-forward
    testing::set_block_timestamp(delay);

    // Execute
    testing::set_contract_address(EXECUTOR());
    timelock.execute_batch(calls, predecessor, salt);
}

#[test]
#[should_panic(expected: ('Timelock: awaiting predecessor', 'ENTRYPOINT_FAILED'))]
fn test_execute_batch_before_dependency() {
    let (mut timelock, mut target) = setup_dispatchers();
    let salt = 0;
    let delay = MIN_DELAY;

    // Calls 1
    let calls_1 = batched_operations(target.contract_address);
    let predecessor_1 = NO_PREDECESSOR;
    let target_id_1 = timelock.hash_operation_batch(calls_1, predecessor_1, salt);

    // Calls 2
    let calls_2 = batched_operations(target.contract_address);
    let predecessor_2 = target_id_1;

    // Schedule calls 1
    testing::set_contract_address(PROPOSER());
    timelock.schedule_batch(calls_1, predecessor_1, salt, delay);

    // Schedule calls 2
    timelock.schedule_batch(calls_2, predecessor_2, salt, delay);

    // Fast-forward
    testing::set_block_timestamp(delay);

    // Execute
    testing::set_contract_address(EXECUTOR());
    timelock.execute_batch(calls_2, predecessor_2, salt);
}

#[test]
fn test_execute_batch_after_dependency() {
    let (mut timelock, mut target) = setup_dispatchers();
    let salt = 0;
    let delay = MIN_DELAY;

    // Calls 1
    let calls_1 = batched_operations(target.contract_address);
    let predecessor_1 = NO_PREDECESSOR;
    let target_id_1 = timelock.hash_operation_batch(calls_1, predecessor_1, salt);
    assert_operation_state(timelock, OperationState::Unset, target_id_1);

    // Calls 2
    let calls_2 = batched_operations(target.contract_address);
    let predecessor_2 = target_id_1;
    let target_id_2 = timelock.hash_operation_batch(calls_2, predecessor_2, salt);
    assert_operation_state(timelock, OperationState::Unset, target_id_2);

    // Schedule calls 1
    testing::set_contract_address(PROPOSER());
    timelock.schedule_batch(calls_1, predecessor_1, salt, delay);
    assert_operation_state(timelock, OperationState::Waiting, target_id_1);
    assert_only_events_schedule_batch(
        timelock.contract_address, target_id_1, calls_1, predecessor_1, delay
    );

    // Schedule calls 2
    timelock.schedule_batch(calls_2, predecessor_2, salt, delay);
    assert_operation_state(timelock, OperationState::Waiting, target_id_2);
    assert_only_events_schedule_batch(
        timelock.contract_address, target_id_2, calls_2, predecessor_2, delay
    );

    // Fast-forward
    testing::set_block_timestamp(delay);
    assert_operation_state(timelock, OperationState::Ready, target_id_1);
    assert_operation_state(timelock, OperationState::Ready, target_id_2);

    // Execute calls 1
    testing::set_contract_address(EXECUTOR());
    timelock.execute_batch(calls_1, predecessor_1, salt);
    assert_only_events_execute_batch(timelock.contract_address, target_id_1, calls_1);
    assert_operation_state(timelock, OperationState::Done, target_id_1);

    // Execute calls 2
    timelock.execute_batch(calls_2, predecessor_2, salt);
    assert_operation_state(timelock, OperationState::Done, target_id_2);
    assert_only_events_execute_batch(timelock.contract_address, target_id_2, calls_2);
}

//
// cancel
//

fn cancel_from_canceller(operation_state: OperationState) {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let salt = 0;
    let delay = MIN_DELAY;
    let event_index = 0;

    let call = single_operation(target.contract_address);
    let target_id = timelock.hash_operation(call, predecessor, salt);
    assert_operation_state(timelock, OperationState::Unset, target_id);

    // Schedule
    testing::set_contract_address(PROPOSER()); // PROPOSER is also CANCELLER
    timelock.schedule(call, predecessor, salt, delay);
    assert_operation_state(timelock, OperationState::Waiting, target_id);
    assert_only_event_schedule(
        timelock.contract_address, target_id, event_index, call, predecessor, delay
    );

    if operation_state == OperationState::Ready {
        // Fast-forward
        testing::set_block_timestamp(delay);
        assert_operation_state(timelock, OperationState::Ready, target_id);
    }

    // Cancel
    timelock.cancel(target_id);
    assert_only_event_cancel(timelock.contract_address, target_id);
    assert_operation_state(timelock, OperationState::Unset, target_id);
}

#[test]
fn test_cancel_when_waiting() {
    let waiting = OperationState::Waiting;
    cancel_from_canceller(waiting);
}

#[test]
fn test_cancel_when_ready() {
    let ready = OperationState::Waiting;
    cancel_from_canceller(ready);
}

#[test]
#[should_panic(expected: ('Timelock: expected Pending op', 'ENTRYPOINT_FAILED'))]
fn test_cancel_when_done() {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let salt = 0;
    let delay = MIN_DELAY;

    let call = single_operation(target.contract_address);
    let target_id = timelock.hash_operation(call, predecessor, salt);
    assert_operation_state(timelock, OperationState::Unset, target_id);

    // Schedule
    testing::set_contract_address(PROPOSER());
    timelock.schedule(call, predecessor, salt, delay);
    assert_operation_state(timelock, OperationState::Waiting, target_id);

    // Fast-forward
    testing::set_block_timestamp(delay);
    assert_operation_state(timelock, OperationState::Ready, target_id);

    // Execute
    testing::set_contract_address(EXECUTOR());
    timelock.execute(call, predecessor, salt);
    assert_operation_state(timelock, OperationState::Done, target_id);

    // Attempt cancel
    testing::set_contract_address(PROPOSER()); // PROPOSER is also CANCELLER
    timelock.cancel(target_id);
}

#[test]
#[should_panic(expected: ('Timelock: expected Pending op', 'ENTRYPOINT_FAILED'))]
fn test_cancel_when_unset() {
    let (mut timelock, _) = setup_dispatchers();
    let invalid_id = 0;

    // PROPOSER is also CANCELLER
    testing::set_contract_address(PROPOSER());
    timelock.cancel(invalid_id);
}

#[test]
#[should_panic(expected: ('Caller is missing role', 'ENTRYPOINT_FAILED'))]
fn test_cancel_unauthorized() {
    let (mut timelock, mut target) = setup_dispatchers();
    let predecessor = NO_PREDECESSOR;
    let salt = 0;
    let delay = MIN_DELAY;

    let call = single_operation(target.contract_address);
    let target_id = timelock.hash_operation(call, predecessor, salt);

    // Schedule
    testing::set_contract_address(PROPOSER());
    timelock.schedule(call, predecessor, salt, delay);

    // Cancel
    testing::set_contract_address(OTHER());
    timelock.cancel(target_id);
}

//
// update_delay
//

#[test]
#[should_panic(expected: ('Timelock: unauthorized caller', 'ENTRYPOINT_FAILED'))]
fn test_update_delay_unauthorized() {
    let mut timelock = deploy_timelock();

    timelock.update_delay(NEW_DELAY);
}

#[test]
fn test_update_delay_scheduled() {
    let mut timelock = deploy_timelock();
    let predecessor = NO_PREDECESSOR;
    let salt = 0;
    let delay = MIN_DELAY;
    let event_index = 0;

    let call = Call {
        to: timelock.contract_address,
        selector: selector!("update_delay"),
        calldata: array![NEW_DELAY.into()].span()
    };
    let target_id = timelock.hash_operation(call, predecessor, salt);

    // Schedule
    testing::set_contract_address(PROPOSER());
    timelock.schedule(call, predecessor, salt, delay);
    assert_operation_state(timelock, OperationState::Waiting, target_id);
    assert_only_event_schedule(
        timelock.contract_address, target_id, event_index, call, predecessor, delay
    );

    // Fast-forward
    testing::set_block_timestamp(delay);

    // Execute
    testing::set_contract_address(EXECUTOR());
    timelock.execute(call, predecessor, salt);
    assert_operation_state(timelock, OperationState::Done, target_id);
    assert_event_delay(timelock.contract_address, MIN_DELAY, NEW_DELAY);
    assert_only_event_execute(timelock.contract_address, target_id, event_index, call);

    // Check new minimum delay
    let get_new_delay = timelock.get_min_delay();
    assert_eq!(get_new_delay, NEW_DELAY);
}

//
// Internal
//

//
// initializer
//

#[test]
fn test_initializer_single_role_and_no_admin() {
    let mut state = COMPONENT_STATE();
    let contract_state = CONTRACT_STATE();
    let min_delay = MIN_DELAY;

    let proposers = array![PROPOSER()].span();
    let executors = array![EXECUTOR()].span();
    let admin_zero = ZERO();

    state.initializer(min_delay, proposers, executors, admin_zero);
    assert!(contract_state.has_role(DEFAULT_ADMIN_ROLE, admin_zero));
}

#[test]
fn test_initializer_multiple_roles_and_admin() {
    let mut state = COMPONENT_STATE();
    let contract_state = CONTRACT_STATE();
    let min_delay = MIN_DELAY;

    let (p1, p2, p3) = get_proposers();
    let mut proposers = array![p1, p2, p3].span();

    let (e1, e2, e3) = get_executors();
    let mut executors = array![e1, e2, e3].span();

    let admin = ADMIN();

    state.initializer(min_delay, proposers, executors, admin);

    // Check assigned roles
    assert!(contract_state.has_role(DEFAULT_ADMIN_ROLE, admin));

    let mut index = 0;
    loop {
        if index == proposers.len() {
            break;
        }

        assert!(contract_state.has_role(PROPOSER_ROLE, *proposers.at(index)));
        assert!(contract_state.has_role(CANCELLER_ROLE, *proposers.at(index)));
        assert!(contract_state.has_role(EXECUTOR_ROLE, *executors.at(index)));
        index += 1;
    };
}

#[test]
fn test_initializer_supported_interfaces() {
    let mut state = COMPONENT_STATE();
    let contract_state = CONTRACT_STATE();
    let min_delay = MIN_DELAY;

    let proposers = array![PROPOSER()].span();
    let executors = array![EXECUTOR()].span();
    let admin = ADMIN();

    state.initializer(min_delay, proposers, executors, admin);

    // Check interface support
    let supports_isrc5 = contract_state.src5.supports_interface(ISRC5_ID);
    assert!(supports_isrc5);

    let supports_access_control = contract_state.src5.supports_interface(IACCESSCONTROL_ID);
    assert!(supports_access_control);
}

#[test]
fn test_initializer_min_delay() {
    let mut state = COMPONENT_STATE();
    let min_delay = MIN_DELAY;

    let proposers = array![PROPOSER()].span();
    let executors = array![EXECUTOR()].span();
    let admin_zero = ZERO();

    state.initializer(min_delay, proposers, executors, admin_zero);

    // Check minimum delay is set
    let delay = state.get_min_delay();
    assert_eq!(delay, MIN_DELAY);

    // The initializer emits 4 `RoleGranted` events prior to `MinDelayChanged`:
    // - Self administration
    // - 1 proposer
    // - 1 canceller
    // - 1 executor
    utils::drop_events(ZERO(), 4);
    assert_only_event_delay_change(ZERO(), 0, MIN_DELAY);
}

//
// assert_only_role_or_open_role
//

#[test]
fn test_assert_only_role_or_open_role_when_has_role() {
    let mut state = COMPONENT_STATE();
    let min_delay = MIN_DELAY;

    let proposers = array![PROPOSER()].span();
    let executors = array![EXECUTOR()].span();
    let admin = ADMIN();

    state.initializer(min_delay, proposers, executors, admin);

    testing::set_caller_address(PROPOSER());
    state.assert_only_role_or_open_role(PROPOSER_ROLE);

    // PROPOSER == CANCELLER
    testing::set_caller_address(PROPOSER());
    state.assert_only_role_or_open_role(CANCELLER_ROLE);

    testing::set_caller_address(EXECUTOR());
    state.assert_only_role_or_open_role(EXECUTOR_ROLE);
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_assert_only_role_or_open_role_unauthorized() {
    let mut state = COMPONENT_STATE();
    let min_delay = MIN_DELAY;

    let proposers = array![PROPOSER()].span();
    let executors = array![EXECUTOR()].span();
    let admin = ADMIN();

    state.initializer(min_delay, proposers, executors, admin);

    testing::set_caller_address(OTHER());
    state.assert_only_role_or_open_role(PROPOSER_ROLE);
}

#[test]
fn test_assert_only_role_or_open_role_with_open_role() {
    let mut state = COMPONENT_STATE();
    let contract_state = CONTRACT_STATE();
    let min_delay = MIN_DELAY;
    let open_role = ZERO();

    let proposers = array![PROPOSER()].span();
    let executors = array![open_role].span();
    let admin = ADMIN();

    state.initializer(min_delay, proposers, executors, admin);

    let is_open_role = contract_state.has_role(EXECUTOR_ROLE, open_role);
    assert!(is_open_role);

    testing::set_caller_address(OTHER());
    state.assert_only_role_or_open_role(EXECUTOR_ROLE);
}

//
// _before_call
//

#[test]
fn test__before_call() {
    let mut state = COMPONENT_STATE();
    let predecessor = NO_PREDECESSOR;

    // Mock targets
    let target_id = 'TARGET_ID';
    let target_time = MIN_DELAY + starknet::get_block_timestamp();

    // Set targets in storage
    state.TimelockController_timestamps.write(target_id, target_time);

    // Fast-forward
    testing::set_block_timestamp(target_time);

    state._before_call(target_id, predecessor);
}

#[test]
#[should_panic(expected: ('Timelock: expected Ready op',))]
fn test__before_call_nonexistent_operation() {
    let mut state = COMPONENT_STATE();
    let predecessor = NO_PREDECESSOR;

    // Mock targets
    let target_id = 'TARGET_ID';
    let not_scheduled = 0;

    // Set targets in storage
    state.TimelockController_timestamps.write(target_id, not_scheduled);

    state._before_call(target_id, predecessor);
}

#[test]
#[should_panic(expected: ('Timelock: expected Ready op',))]
fn test__before_call_insufficient_time() {
    let mut state = COMPONENT_STATE();
    let predecessor = NO_PREDECESSOR;

    // Mock targets
    let target_id = 'TARGET_ID';
    let target_time = MIN_DELAY + starknet::get_block_timestamp();

    // Set targets in storage
    state.TimelockController_timestamps.write(target_id, target_time);

    // Fast-forward
    testing::set_block_timestamp(target_time - 1);

    state._before_call(target_id, predecessor);
}

#[test]
#[should_panic(expected: ('Timelock: expected Ready op',))]
fn test__before_call_when_already_done() {
    let mut state = COMPONENT_STATE();
    let predecessor = NO_PREDECESSOR;

    // Mock targets
    let target_id = 'TARGET_ID';
    let done_time = 1;

    // Set targets in storage
    state.TimelockController_timestamps.write(target_id, done_time);

    // Fast-forward
    testing::set_block_timestamp(done_time);

    state._before_call(target_id, predecessor);
}

#[test]
fn test__before_call_with_predecessor_done() {
    let mut state = COMPONENT_STATE();

    // Mock `Done` predecessor
    let predecessor_id = 'DONE';
    let done_time = 1;

    // Mock targets
    let target_id = 'TARGET_ID';
    let target_time = MIN_DELAY + starknet::get_block_timestamp();

    // Set targets in storage
    state.TimelockController_timestamps.write(predecessor_id, done_time);
    state.TimelockController_timestamps.write(target_id, target_time);

    // Fast-forward
    testing::set_block_timestamp(target_time);

    state._before_call(target_id, predecessor_id);
}

#[test]
#[should_panic(expected: ('Timelock: awaiting predecessor',))]
fn test__before_call_with_predecessor_not_done() {
    let mut state = COMPONENT_STATE();

    // Mock awaiting predecessor
    let predecessor_id = 'DONE';
    let not_done_time = 2;

    // Mock targets
    let target_id = 'TARGET_ID';
    let target_time = MIN_DELAY + starknet::get_block_timestamp();

    // Set targets in storage
    state.TimelockController_timestamps.write(predecessor_id, not_done_time);
    state.TimelockController_timestamps.write(target_id, target_time);

    // Fast-forward
    testing::set_block_timestamp(target_time);

    state._before_call(target_id, predecessor_id);
}

//
// _after_call
//

#[test]
fn test__after_call() {
    let mut state = COMPONENT_STATE();

    // Mock targets
    let target_id = 'TARGET_ID';
    let target_time = MIN_DELAY + starknet::get_block_timestamp();

    // Set targets in storage
    state.TimelockController_timestamps.write(target_id, target_time);

    // Fast-forward
    testing::set_block_timestamp(target_time);

    state._after_call(target_id);

    // Check timestamp is set to done (1)
    let done_ts = 1;
    let is_done = state.TimelockController_timestamps.read(target_id);
    assert_eq!(is_done, done_ts);
}

#[test]
#[should_panic(expected: ('Timelock: expected Ready op',))]
fn test__after_call_nonexistent_operation() {
    let mut state = COMPONENT_STATE();

    // Mock targets
    let target_id = 'TARGET_ID';
    let not_scheduled = 0;

    // Set targets in storage
    state.TimelockController_timestamps.write(target_id, not_scheduled);

    state._after_call(target_id);
}

#[test]
#[should_panic(expected: ('Timelock: expected Ready op',))]
fn test__after_call_insufficient_time() {
    let mut state = COMPONENT_STATE();

    // Mock targets
    let target_id = 'TARGET_ID';
    let target_time = MIN_DELAY + starknet::get_block_timestamp();

    // Set targets in storage
    state.TimelockController_timestamps.write(target_id, target_time);

    // Fast-forward
    testing::set_block_timestamp(target_time - 1);

    state._after_call(target_id);
}

#[test]
#[should_panic(expected: ('Timelock: expected Ready op',))]
fn test__after_call_already_done() {
    let mut state = COMPONENT_STATE();

    // Mock targets
    let target_id = 'TARGET_ID';
    let done_time = 1;

    // Set targets in storage
    state.TimelockController_timestamps.write(target_id, done_time);

    // Fast-forward
    testing::set_block_timestamp(done_time);

    state._after_call(target_id);
}

//
// _schedule
//

#[test]
fn test__schedule() {
    let mut state = COMPONENT_STATE();
    let mut target = deploy_mock_target();
    let predecessor = NO_PREDECESSOR;
    let delay = MIN_DELAY;
    let mut salt = 0;

    // Set up call
    let call = single_operation(target.contract_address);
    let target_id = state.hash_operation(call, predecessor, salt);

    // Schedule
    state._schedule(target_id, delay);

    let actual_ts = state.TimelockController_timestamps.read(target_id);
    let expected_ts = starknet::get_block_timestamp() + delay;
    assert_eq!(actual_ts, expected_ts);
}

#[test]
#[should_panic(expected: ('Timelock: expected Unset op',))]
fn test__schedule_overwrite() {
    let mut state = COMPONENT_STATE();
    let mut target = deploy_mock_target();
    let predecessor = NO_PREDECESSOR;
    let delay = MIN_DELAY;
    let mut salt = 0;

    // Set up call
    let call = single_operation(target.contract_address);
    let target_id = state.hash_operation(call, predecessor, salt);

    // Schedule and overwrite
    state._schedule(target_id, delay);
    state._schedule(target_id, delay);
}

#[test]
#[should_panic(expected: ('Timelock: insufficient delay',))]
fn test__schedule_bad_delay() {
    let mut state = COMPONENT_STATE();
    let mut target = deploy_mock_target();
    let predecessor = NO_PREDECESSOR;
    let mut salt = 0;
    let delay = MIN_DELAY;

    // Set up call
    let call = single_operation(target.contract_address);
    let target_id = state.hash_operation(call, predecessor, salt);

    // Set min delay
    state.TimelockController_min_delay.write(delay);

    // Schedule with bad delay
    state._schedule(target_id, delay - 1);
}

//
// _execute
//

#[test]
fn test__execute() {
    let mut state = COMPONENT_STATE();
    let mut target = deploy_mock_target();

    // Set up call
    let call = single_operation(target.contract_address);

    let storage_num = target.get_number();
    let expected_num = 0;
    assert_eq!(storage_num, expected_num);

    // Execute
    state._execute(call);

    let storage_num = target.get_number();
    let expected_num = VALUE;
    assert_eq!(storage_num, expected_num);
}

#[test]
#[should_panic(expected: ('Expected failure', 'ENTRYPOINT_FAILED',))]
fn test__execute_with_failing_tx() {
    let mut state = COMPONENT_STATE();
    let mut target = deploy_mock_target();

    // Set up call
    let call = failing_operation(target.contract_address);

    // Execute failing tx
    state._execute(call);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test__execute_with_bad_selector() {
    let mut state = COMPONENT_STATE();
    let mut target = deploy_mock_target();

    // Set up call
    let bad_selector_call = operation_with_bad_selector(target.contract_address);

    // Execute call with bad selector
    state._execute(bad_selector_call);
}

//
// Helpers
//

fn assert_operation_state(timelock: TimelockABIDispatcher, exp_state: OperationState, id: felt252) {
    let operation_state = timelock.get_operation_state(id);
    assert_eq!(operation_state, exp_state);

    let is_operation = timelock.is_operation(id);
    let is_pending = timelock.is_operation_pending(id);
    let is_ready = timelock.is_operation_ready(id);
    let is_done = timelock.is_operation_done(id);

    match exp_state {
        OperationState::Unset => {
            assert!(!is_operation);
            assert!(!is_pending);
            assert!(!is_ready);
            assert!(!is_done);
        },
        OperationState::Waiting => {
            assert!(is_operation);
            assert!(is_pending);
            assert!(!is_ready);
            assert!(!is_done);
        },
        OperationState::Ready => {
            assert!(is_operation);
            assert!(is_pending);
            assert!(is_ready);
            assert!(!is_done);
        },
        OperationState::Done => {
            assert!(is_operation);
            assert!(!is_pending);
            assert!(!is_ready);
            assert!(is_done);
        }
    };
}

//
// Event helpers
//

//
// MinDelayChanged
//

fn assert_event_delay_change(contract: ContractAddress, old_duration: u64, new_duration: u64) {
    let event = utils::pop_log::<TimelockControllerComponent::Event>(contract).unwrap();
    let expected = TimelockControllerComponent::Event::MinDelayChanged(
        MinDelayChanged { old_duration, new_duration }
    );
    assert!(event == expected);
}

fn assert_only_event_delay_change(contract: ContractAddress, old_duration: u64, new_duration: u64) {
    assert_event_delay_change(contract, old_duration, new_duration);
    utils::assert_no_events_left(contract);
}

//
// CallScheduled
//

fn assert_event_schedule(
    contract: ContractAddress,
    id: felt252,
    index: felt252,
    call: Call,
    predecessor: felt252,
    delay: u64
) {
    let event = utils::pop_log::<TimelockControllerComponent::Event>(contract).unwrap();
    let expected = TimelockControllerComponent::Event::CallScheduled(
        CallScheduled { id, index, call, predecessor, delay }
    );
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("CallScheduled"));
    indexed_keys.append_serde(id);
    indexed_keys.append_serde(index);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_only_event_schedule(
    contract: ContractAddress,
    id: felt252,
    index: felt252,
    call: Call,
    predecessor: felt252,
    delay: u64
) {
    assert_event_schedule(contract, id, index, call, predecessor, delay);
    utils::assert_no_events_left(contract);
}

fn assert_events_schedule_batch(
    contract: ContractAddress, id: felt252, calls: Span<Call>, predecessor: felt252, delay: u64
) {
    let mut i = 0;
    loop {
        if i == calls.len() {
            break;
        }
        assert_event_schedule(contract, id, i.into(), *calls.at(i), predecessor, delay);
        i += 1;
    }
}

fn assert_only_events_schedule_batch(
    contract: ContractAddress, id: felt252, calls: Span<Call>, predecessor: felt252, delay: u64
) {
    assert_events_schedule_batch(contract, id, calls, predecessor, delay);
    utils::assert_no_events_left(contract);
}

//
// CallSalt
//

fn assert_event_call_salt(contract: ContractAddress, id: felt252, salt: felt252) {
    let event = utils::pop_log::<TimelockControllerComponent::Event>(contract).unwrap();
    let expected = TimelockControllerComponent::Event::CallSalt(CallSalt { id, salt });
    assert!(event == expected);
}

fn assert_only_event_call_salt(contract: ContractAddress, id: felt252, salt: felt252) {
    assert_event_call_salt(contract, id, salt);
    utils::assert_no_events_left(contract);
}

//
// CallExecuted
//

fn assert_event_execute(contract: ContractAddress, id: felt252, index: felt252, call: Call) {
    let event = utils::pop_log::<TimelockControllerComponent::Event>(contract).unwrap();
    let expected = TimelockControllerComponent::Event::CallExecuted(
        CallExecuted { id, index, call }
    );
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("CallExecuted"));
    indexed_keys.append_serde(id);
    indexed_keys.append_serde(index);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_only_event_execute(contract: ContractAddress, id: felt252, index: felt252, call: Call) {
    assert_event_execute(contract, id, index, call);
    utils::assert_no_events_left(contract);
}

fn assert_events_execute_batch(contract: ContractAddress, id: felt252, calls: Span<Call>) {
    let mut i = 0;
    loop {
        if i == calls.len() {
            break;
        }
        assert_event_execute(contract, id, i.into(), *calls.at(i));
        i += 1;
    }
}

fn assert_only_events_execute_batch(contract: ContractAddress, id: felt252, calls: Span<Call>) {
    assert_events_execute_batch(contract, id, calls);
    utils::assert_no_events_left(contract);
}

//
// Cancelled
//

fn assert_event_cancel(contract: ContractAddress, id: felt252) {
    let event = utils::pop_log::<TimelockControllerComponent::Event>(contract).unwrap();
    let expected = TimelockControllerComponent::Event::CallCancelled(CallCancelled { id });
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("CallCancelled"));
    indexed_keys.append_serde(id);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_only_event_cancel(contract: ContractAddress, id: felt252) {
    assert_event_cancel(contract, id);
    utils::assert_no_events_left(contract);
}

//
// MinDelayChanged
//

fn assert_event_delay(contract: ContractAddress, old_duration: u64, new_duration: u64) {
    let event = utils::pop_log::<TimelockControllerComponent::Event>(contract).unwrap();
    let expected = TimelockControllerComponent::Event::MinDelayChanged(
        MinDelayChanged { old_duration, new_duration }
    );
    assert!(event == expected);
}

fn assert_only_event_delay(contract: ContractAddress, old_duration: u64, new_duration: u64) {
    assert_event_delay(contract, old_duration, new_duration);
    utils::assert_no_events_left(contract);
}
