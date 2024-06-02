use hash::{HashStateTrait, HashStateExTrait};
use openzeppelin::access::accesscontrol::AccessControlComponent::{
    AccessControlImpl, InternalImpl as AccessControlInternalImpl
};
use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
use openzeppelin::access::accesscontrol::interface::IAccessControl;
use openzeppelin::governance::timelock::TimelockControllerComponent::Call;
use openzeppelin::governance::timelock::TimelockControllerComponent::OperationState;
use openzeppelin::governance::timelock::TimelockControllerComponent::{
    CallScheduled, CallExecuted, CallSalt, Cancelled, MinDelayChange
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
use openzeppelin::tests::mocks::account_mocks::SnakeAccountMock;
use openzeppelin::tests::mocks::erc1155_mocks::DualCaseERC1155Mock;
use openzeppelin::tests::mocks::erc721_mocks::DualCaseERC721Mock;
use openzeppelin::tests::mocks::timelock_mocks::MockContract;
use openzeppelin::tests::mocks::timelock_mocks::{
    IMockContractDispatcher, IMockContractDispatcherTrait
};
use openzeppelin::tests::mocks::timelock_mocks::{
    ITimelockAttackerDispatcher, ITimelockAttackerDispatcherTrait
};
use openzeppelin::tests::mocks::timelock_mocks::{TimelockControllerMock, TimelockAttackerMock};
use openzeppelin::tests::utils::constants::{
    ADMIN, ZERO, NAME, SYMBOL, BASE_URI, OWNER, RECIPIENT, SPENDER, OTHER, PUBKEY, SALT, TOKEN_ID,
    TOKEN_ID_2, TOKEN_VALUE, TOKEN_VALUE_2
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc1155::interface::IERC1155_RECEIVER_ID;
use openzeppelin::token::erc1155::interface::{IERC1155DispatcherTrait, IERC1155Dispatcher};
use openzeppelin::token::erc721::interface::IERC721_RECEIVER_ID;
use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use poseidon::PoseidonTrait;
use starknet::ContractAddress;
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

//
// Dispatchers
//

fn setup_dispatchers() -> (TimelockABIDispatcher, IMockContractDispatcher) {
    let timelock = deploy_timelock();
    let target = deploy_mock_target();

    (timelock, target)
}

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
    // - MinDelayChange
    utils::drop_events(address, 6);
    TimelockABIDispatcher { contract_address: address }
}

fn deploy_erc721() -> IERC721Dispatcher {
    let mut calldata = array![];

    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(OWNER());
    calldata.append_serde(TOKEN_ID);

    let address = utils::deploy(DualCaseERC721Mock::TEST_CLASS_HASH, calldata);
    IERC721Dispatcher { contract_address: address }
}

fn deploy_erc1155() -> (IERC1155Dispatcher, ContractAddress) {
    let uri: ByteArray = "URI";
    let mut calldata = array![];
    let mut token_id = TOKEN_ID;
    let mut value = TOKEN_VALUE;

    let owner = setup_account();
    testing::set_contract_address(owner);

    calldata.append_serde(uri);
    calldata.append_serde(owner);
    calldata.append_serde(token_id);
    calldata.append_serde(value);

    let address = utils::deploy(DualCaseERC1155Mock::TEST_CLASS_HASH, calldata);
    (IERC1155Dispatcher { contract_address: address }, owner)
}

fn setup_account() -> ContractAddress {
    let mut calldata = array![PUBKEY];
    utils::deploy(SnakeAccountMock::TEST_CLASS_HASH, calldata)
}

fn deploy_mock_target() -> IMockContractDispatcher {
    let mut calldata = array![];

    let address = utils::deploy(MockContract::TEST_CLASS_HASH, calldata);
    IMockContractDispatcher { contract_address: address }
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

    // Setup call
    let mut calldata = array![];
    calldata.append_serde(VALUE);
    let mut call = Call {
        to: target.contract_address, selector: selector!("set_number"), calldata: calldata.span()
    };

    // Hash operation
    let hashed_operation = timelock.hash_operation(call, predecessor, salt);

    // Manually set hash elements
    let mut expected_hash = PoseidonTrait::new()
        .update_with(4) // total elements of call
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

    // Setup calls
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
        .update_with(13) // total elements of Call span
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

    let call = single_operation(target.contract_address);
    let target_id = timelock.hash_operation(call, predecessor, salt);
    assert_operation_state(timelock, OperationState::Unset, target_id);

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
#[should_panic(expected: ('Timelock: unexpected op state', 'ENTRYPOINT_FAILED'))]
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

    let calls = batched_operations(target.contract_address);
    let target_id = timelock.hash_operation_batch(calls, predecessor, salt);
    assert_operation_state(timelock, OperationState::Unset, target_id);

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
#[should_panic(expected: ('Timelock: unexpected op state', 'ENTRYPOINT_FAILED'))]
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
#[should_panic(expected: ('Timelock: unexpected op state', 'ENTRYPOINT_FAILED'))]
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
#[should_panic(expected: ('Timelock: unexpected op state', 'ENTRYPOINT_FAILED'))]
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
#[should_panic(
    expected: (
        'Timelock: unexpected op state',
        'ENTRYPOINT_FAILED',
        'ENTRYPOINT_FAILED',
        'ENTRYPOINT_FAILED'
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
#[should_panic(expected: ('Timelock: unexpected op state', 'ENTRYPOINT_FAILED'))]
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
#[should_panic(expected: ('Timelock: unexpected op state', 'ENTRYPOINT_FAILED'))]
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
        'Timelock: unexpected op state',
        'ENTRYPOINT_FAILED',
        'ENTRYPOINT_FAILED',
        'ENTRYPOINT_FAILED'
    )
)]
fn test_execute_batch_reentrant_call() {
    let (mut timelock, mut target) = setup_dispatchers();
    let mut attacker = deploy_attacker();
    let predecessor = NO_PREDECESSOR;
    let salt = 0;
    let delay = MIN_DELAY;

    let call_1 = single_operation(target.contract_address);
    let call_2 = single_operation(target.contract_address);
    let reentrant_call = Call {
        to: attacker.contract_address, selector: selector!("reenter"), calldata: array![].span()
    };
    let calls = array![call_1, call_2, reentrant_call].span();

    // schedule
    testing::set_contract_address(PROPOSER());
    timelock.schedule_batch(calls, predecessor, salt, delay);

    // fast-forward
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

    // Call 1
    let calls_1 = batched_operations(target.contract_address);
    let predecessor_1 = NO_PREDECESSOR;
    let target_id_1 = timelock.hash_operation_batch(calls_1, predecessor_1, salt);

    // Call 2
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

#[test]
fn test_cancel_from_canceller() {
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

    // Cancel
    timelock.cancel(target_id);
    assert_only_event_cancel(timelock.contract_address, target_id);
    assert_operation_state(timelock, OperationState::Unset, target_id);
}

#[test]
#[should_panic(expected: ('Timelock: unexpected op state', 'ENTRYPOINT_FAILED'))]
fn test_cancel_invalid_operation() {
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
    utils::drop_events(timelock.contract_address, 2);

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
// Safe receive
//

#[test]
fn test_receive_erc721_safe_transfer() {
    let mut timelock = deploy_timelock();
    let mut erc721 = deploy_erc721();

    let owner = OWNER();
    let timelock_addr = timelock.contract_address;
    let token = TOKEN_ID;
    let data = array![].span();

    // Check original holder
    let original_owner = erc721.owner_of(token);
    assert_eq!(original_owner, owner);

    // Safe transfer
    testing::set_contract_address(OWNER());
    erc721.safe_transfer_from(owner, timelock_addr, token, data);

    // Check that timelock accepted safe transfer
    let new_owner = erc721.owner_of(token);
    assert_eq!(new_owner, timelock_addr);
}

#[test]
fn test_receive_erc1155_safe_transfer() {
    let mut timelock = deploy_timelock();
    let (mut erc1155, owner) = deploy_erc1155();

    let token_id = TOKEN_ID;
    let token_value = TOKEN_VALUE;
    //let data = array![];

    // Check initial balances
    let owner_balance = erc1155.balance_of(owner, token_id);
    let expected_balance = token_value;
    assert_eq!(owner_balance, expected_balance);

    let timelock_balance = erc1155.balance_of(timelock.contract_address, token_id);
    let expected_balance = 0;
    assert_eq!(timelock_balance, expected_balance);

    // Safe transfer
    testing::set_contract_address(owner);
    let transfer_amt = 1;
    let data = array![].span();
    erc1155.safe_transfer_from(owner, timelock.contract_address, token_id, transfer_amt, data);

    // Check new balances
    let owner_balance = erc1155.balance_of(owner, token_id);
    let expected_balance = token_value - transfer_amt;
    assert_eq!(owner_balance, expected_balance);

    let timelock_balance = erc1155.balance_of(timelock.contract_address, token_id);
    let expected_balance = transfer_amt;
    assert_eq!(timelock_balance, expected_balance);
}

#[test]
fn test_receive_erc1155_safe_batch_transfer() {
    let mut timelock = deploy_timelock();
    let (mut erc1155, owner) = deploy_erc1155();

    let token_id = TOKEN_ID;
    let token_value = TOKEN_VALUE;

    // Check initial balances
    let owner_balance = erc1155.balance_of(owner, token_id);
    let expected_balance = token_value;
    assert_eq!(owner_balance, expected_balance);

    let timelock_balance = erc1155.balance_of(timelock.contract_address, token_id);
    let expected_balance = 0;
    assert_eq!(timelock_balance, expected_balance);

    // Safe batch transfer
    testing::set_contract_address(owner);
    let transfer_ids = array![token_id, token_id].span();
    let transfer_amts = array![1, 1].span();
    let data = array![].span();
    erc1155
        .safe_batch_transfer_from(
            owner, timelock.contract_address, transfer_ids, transfer_amts, data
        );

    // Check new balances
    let total_transfer_amt = 2;

    let owner_balance = erc1155.balance_of(owner, token_id);
    let expected_balance = token_value - total_transfer_amt;
    assert_eq!(owner_balance, expected_balance);

    let timelock_balance = erc1155.balance_of(timelock.contract_address, token_id);
    let expected_balance = total_transfer_amt;
    assert_eq!(timelock_balance, expected_balance);
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

    let supports_ierc1155_receiver = contract_state.src5.supports_interface(IERC1155_RECEIVER_ID);
    assert!(supports_ierc1155_receiver);

    let supports_ierc721_receiver = contract_state.src5.supports_interface(IERC721_RECEIVER_ID);
    assert!(supports_ierc721_receiver);
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

    // The initializer emits 4 `RoleGranted` events prior to `MinDelayChange`:
    // - Self administration
    // - 1 proposers
    // - 1 cancellers
    // - 1 executors
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

    let proposers = array![open_role].span();
    let executors = array![EXECUTOR()].span();
    let admin = ADMIN();

    state.initializer(min_delay, proposers, executors, admin);

    let is_open_role = contract_state.has_role(PROPOSER_ROLE, open_role);
    assert!(is_open_role);

    testing::set_caller_address(OTHER());
    state.assert_only_role_or_open_role(PROPOSER_ROLE);
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
// MinDelayChange
//

fn assert_event_delay_change(contract: ContractAddress, old_duration: u64, new_duration: u64) {
    let event = utils::pop_log::<TimelockControllerComponent::Event>(contract).unwrap();
    let expected = TimelockControllerComponent::Event::MinDelayChange(
        MinDelayChange { old_duration, new_duration }
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
    let expected = TimelockControllerComponent::Event::Cancelled(Cancelled { id });
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("Cancelled"));
    indexed_keys.append_serde(id);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_only_event_cancel(contract: ContractAddress, id: felt252) {
    assert_event_cancel(contract, id);
    utils::assert_no_events_left(contract);
}

//
// MinDelayChange
//

fn assert_event_delay(contract: ContractAddress, old_duration: u64, new_duration: u64) {
    let event = utils::pop_log::<TimelockControllerComponent::Event>(contract).unwrap();
    let expected = TimelockControllerComponent::Event::MinDelayChange(
        MinDelayChange { old_duration, new_duration }
    );
    assert!(event == expected);
}

fn assert_only_event_delay(contract: ContractAddress, old_duration: u64, new_duration: u64) {
    assert_event_delay(contract, old_duration, new_duration);
    utils::assert_no_events_left(contract);
}
