use hash::{HashStateTrait, HashStateExTrait};
use openzeppelin::access::accesscontrol::AccessControlComponent::{
    AccessControlImpl, InternalImpl as AccessControlInternalImpl
};
use openzeppelin::access::accesscontrol::accesscontrol::AccessControlComponent::InternalTrait;
use openzeppelin::access::accesscontrol::interface::IAccessControl;
use openzeppelin::governance::timelock::TimelockControllerComponent::Call;
use openzeppelin::governance::timelock::TimelockControllerComponent::{
    CallScheduled, CallExecuted, CallSalt, Cancelled, MinDelayChange
};
use openzeppelin::governance::timelock::TimelockControllerComponent::{
    PROPOSER_ROLE, EXECUTOR_ROLE, CANCELLER_ROLE, DEFAULT_ADMIN_ROLE
};
use openzeppelin::governance::timelock::TimelockControllerComponent::{
    TimelockImpl, InternalImpl as TimelockInternalImpl
};
use openzeppelin::governance::timelock::TimelockControllerComponent;
use openzeppelin::governance::timelock::interface::{
    ITimelockABIDispatcher, ITimelockABIDispatcherTrait
};
use openzeppelin::governance::timelock::timelock_controller::{CallPartialEq, HashCallImpl};
use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin::tests::mocks::erc721_mocks::DualCaseERC721Mock;
use openzeppelin::tests::mocks::timelock_mocks::{
    ITimelockAttackerDispatcher, ITimelockAttackerDispatcherTrait
};
use openzeppelin::tests::mocks::timelock_mocks::{TimelockControllerMock, TimelockAttackerMock};
use openzeppelin::tests::utils::constants::{
    ADMIN, ZERO, NAME, SYMBOL, BASE_URI, RECIPIENT, SPENDER, OTHER, SALT, TOKEN_ID
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc1155::interface::IERC1155_RECEIVER_ID;
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

const MIN_DELAY: u64 = 1000;
const NEW_DELAY: u64 = 2000;
const NO_PREDECESSOR: felt252 = 0;

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

fn single_operation(erc721_addr: ContractAddress) -> Call {
    // Call: approve
    let mut calldata = array![];
    calldata.append_serde(SPENDER());
    calldata.append_serde(TOKEN_ID);

    Call { to: erc721_addr, selector: selectors::approve, calldata: calldata.span() }
}

fn failing_operation(erc721_addr: ContractAddress) -> Call {
    let nonexistent_token = 999_u256;
    // Call: approve
    let mut calldata = array![];
    calldata.append_serde(SPENDER());
    calldata.append_serde(nonexistent_token);

    Call { to: erc721_addr, selector: selectors::approve, calldata: calldata.span() }
}

fn batched_operations(erc721_addr: ContractAddress, timelock_addr: ContractAddress) -> Span<Call> {
    // Call 1: approve
    let mut calldata1 = array![];
    calldata1.append_serde(SPENDER());
    calldata1.append_serde(TOKEN_ID);

    let call1 = Call { to: erc721_addr, selector: selectors::approve, calldata: calldata1.span() };

    // Call 2: transfer_from
    let mut calldata2 = array![];
    calldata2.append_serde(timelock_addr);
    calldata2.append_serde(RECIPIENT());
    calldata2.append_serde(TOKEN_ID);
    let call2 = Call {
        to: erc721_addr, selector: selectors::transfer_from, calldata: calldata2.span()
    };

    array![call1, call2].span()
}

fn setup_dispatchers() -> (ITimelockABIDispatcher, IERC721Dispatcher) {
    let timelock = deploy_timelock();
    let token_recipient = timelock.contract_address;
    let erc721 = deploy_erc721(token_recipient);

    (timelock, erc721)
}

fn deploy_timelock() -> ITimelockABIDispatcher {
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
    ITimelockABIDispatcher { contract_address: address }
}

fn deploy_erc721(recipient: ContractAddress) -> IERC721Dispatcher {
    let mut calldata = array![];

    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(recipient);
    calldata.append_serde(TOKEN_ID);

    let address = utils::deploy(DualCaseERC721Mock::TEST_CLASS_HASH, calldata);
    // Event dropped:
    // - Transfer
    utils::drop_event(address);
    IERC721Dispatcher { contract_address: address }
}

fn deploy_attacker() -> ITimelockAttackerDispatcher {
    let mut calldata = array![];

    let address = utils::deploy(TimelockAttackerMock::TEST_CLASS_HASH, calldata);
    ITimelockAttackerDispatcher { contract_address: address }
}

// initializer

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

// schedule

#[test]
fn test_schedule_from_proposer_with_salt() {
    let (mut timelock, mut erc721) = setup_dispatchers();
    let batched_operations = batched_operations(erc721.contract_address, timelock.contract_address);

    testing::set_contract_address(PROPOSER());

    timelock.schedule(batched_operations, NO_PREDECESSOR, SALT, MIN_DELAY);
    assert_event_schedule(timelock.contract_address, batched_operations, NO_PREDECESSOR, MIN_DELAY);

    // Check timestamp
    let hash_id = timelock.hash_operation(batched_operations, NO_PREDECESSOR, SALT);
    let operation_ts = timelock.get_timestamp(hash_id);
    let expected_ts = starknet::get_block_timestamp() + MIN_DELAY;
    assert_eq!(operation_ts, expected_ts);

    assert_only_event_call_salt(timelock.contract_address, hash_id, SALT);
}

#[test]
#[should_panic(expected: ('Timelock: unexpected op state', 'ENTRYPOINT_FAILED'))]
fn test_schedule_overwrite() {
    let (mut timelock, mut erc721) = setup_dispatchers();

    let batched_operations = batched_operations(erc721.contract_address, timelock.contract_address);

    testing::set_contract_address(PROPOSER());
    timelock.schedule(batched_operations, NO_PREDECESSOR, SALT, MIN_DELAY);
    timelock.schedule(batched_operations, NO_PREDECESSOR, SALT, MIN_DELAY);
}

#[test]
#[should_panic(expected: ('Caller is missing role', 'ENTRYPOINT_FAILED'))]
fn test_schedule_unauthorized() {
    let (mut timelock, mut erc721) = setup_dispatchers();

    let batched_operations = batched_operations(erc721.contract_address, timelock.contract_address);

    testing::set_contract_address(OTHER());
    timelock.schedule(batched_operations, NO_PREDECESSOR, SALT, MIN_DELAY);
}

#[test]
#[should_panic(expected: ('Timelock: insufficient delay', 'ENTRYPOINT_FAILED'))]
fn test_schedule_bad_min_delay() {
    let (mut timelock, mut erc721) = setup_dispatchers();

    let bad_delay = MIN_DELAY - 1;
    let batched_operations = batched_operations(erc721.contract_address, timelock.contract_address);

    testing::set_contract_address(PROPOSER());
    timelock.schedule(batched_operations, NO_PREDECESSOR, SALT, bad_delay);
}

#[test]
fn test_schedule_with_salt_zero() {
    let (mut timelock, mut erc721) = setup_dispatchers();

    let zero_salt = 0;
    let batched_operations = batched_operations(erc721.contract_address, timelock.contract_address);
    let hash_id = timelock.hash_operation(batched_operations, NO_PREDECESSOR, zero_salt);

    // Schedule
    testing::set_contract_address(PROPOSER());
    timelock.schedule(batched_operations, NO_PREDECESSOR, zero_salt, MIN_DELAY);
    assert_only_event_schedule(
        timelock.contract_address, batched_operations, NO_PREDECESSOR, MIN_DELAY
    );

    // Check timestamp
    let operation_ts = timelock.get_timestamp(hash_id);
    let expected_ts = starknet::get_block_timestamp() + MIN_DELAY;
    assert_eq!(operation_ts, expected_ts)
}

// execute

#[test]
#[should_panic(expected: ('Timelock: unexpected op state', 'ENTRYPOINT_FAILED'))]
fn test_execute_when_not_scheduled() {
    let (mut timelock, mut erc721) = setup_dispatchers();

    let salt = SALT;
    let call = single_operation(erc721.contract_address);
    let call_arr = array![call];

    testing::set_contract_address(EXECUTOR());
    timelock.execute(call_arr.span(), NO_PREDECESSOR, salt);
}

#[test]
fn test_execute_when_scheduled() {
    let (mut timelock, mut erc721) = setup_dispatchers();

    let call = single_operation(erc721.contract_address);
    let call_span = array![call].span();
    let salt = SALT;
    let delay = MIN_DELAY;

    let hash_id = timelock.hash_operation(call_span, NO_PREDECESSOR, salt);

    // schedule
    testing::set_contract_address(PROPOSER());

    timelock.schedule(call_span, NO_PREDECESSOR, salt, delay);
    utils::drop_events(timelock.contract_address, 2);

    // fast-forward
    testing::set_block_timestamp(delay);

    // Check initial target state
    let check_approved_is_zero = erc721.get_approved(TOKEN_ID);
    assert_eq!(check_approved_is_zero, ZERO());

    // execute
    testing::set_contract_address(EXECUTOR());

    timelock.execute(call_span, NO_PREDECESSOR, salt);
    assert_only_event_execute(timelock.contract_address, hash_id, call_span);

    // Check target state updates
    let check_approved_is_spender = erc721.get_approved(TOKEN_ID);
    assert_eq!(check_approved_is_spender, SPENDER());
}

#[test]
#[should_panic(expected: ('Timelock: unexpected op state', 'ENTRYPOINT_FAILED'))]
fn test_execute_early() {
    let (mut timelock, mut erc721) = setup_dispatchers();

    let call = single_operation(erc721.contract_address);
    let call_span = array![call].span();
    let salt = SALT;
    let delay = MIN_DELAY;

    // schedule
    testing::set_contract_address(PROPOSER());

    timelock.schedule(call_span, NO_PREDECESSOR, salt, delay);
    utils::drop_events(timelock.contract_address, 2);

    // fast-forward
    let early_time = delay - 1;
    testing::set_block_timestamp(early_time);

    // execute
    testing::set_contract_address(EXECUTOR());
    timelock.execute(call_span, NO_PREDECESSOR, salt);
}

#[test]
#[should_panic(expected: ('Caller is missing role', 'ENTRYPOINT_FAILED'))]
fn test_execute_unauthorized() {
    let (mut timelock, mut erc721) = setup_dispatchers();

    let call = single_operation(erc721.contract_address);
    let call_span = array![call].span();
    let salt = SALT;
    let delay = MIN_DELAY;

    // schedule
    testing::set_contract_address(PROPOSER());
    timelock.schedule(call_span, NO_PREDECESSOR, salt, delay);

    // fast-forward
    testing::set_block_timestamp(delay);

    // execute
    testing::set_contract_address(OTHER());
    timelock.execute(call_span, NO_PREDECESSOR, salt);
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

    let reentrant_call = Call {
        to: attacker.contract_address, selector: selector!("reenter"), calldata: array![].span()
    };

    let reentrant_call_span = array![reentrant_call].span();
    let delay = MIN_DELAY;

    // schedule
    testing::set_contract_address(PROPOSER());
    timelock.schedule(reentrant_call_span, NO_PREDECESSOR, SALT, delay);

    // fast-forward
    testing::set_block_timestamp(delay);

    // Grant executor role to attacker
    testing::set_contract_address(ADMIN());
    timelock.grant_role(EXECUTOR_ROLE, attacker.contract_address);

    // Attempt reentrant call
    testing::set_contract_address(EXECUTOR());
    timelock.execute(reentrant_call_span, NO_PREDECESSOR, SALT);
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_execute_partial_execution() {
    let (mut timelock, mut erc721) = setup_dispatchers();

    let good_call = single_operation(erc721.contract_address);
    let bad_call = failing_operation(erc721.contract_address);
    let call_span = array![good_call, bad_call].span();
    let salt = SALT;
    let delay = MIN_DELAY;

    // schedule
    testing::set_contract_address(PROPOSER());

    timelock.schedule(call_span, NO_PREDECESSOR, salt, delay);
    utils::drop_events(timelock.contract_address, 2);

    // fast-forward
    testing::set_block_timestamp(delay);

    // execute
    testing::set_contract_address(EXECUTOR());
    timelock.execute(call_span, NO_PREDECESSOR, salt);
}

// cancel

#[test]
fn test_cancel() {
    let (mut timelock, mut erc721) = setup_dispatchers();

    let batched_operations = batched_operations(erc721.contract_address, timelock.contract_address);
    let hash_id = timelock.hash_operation(batched_operations, NO_PREDECESSOR, SALT);

    // Schedule
    testing::set_contract_address(PROPOSER()); // PROPOSER is also CANCELLER
    timelock.schedule(batched_operations, NO_PREDECESSOR, SALT, MIN_DELAY);
    utils::drop_events(timelock.contract_address, 2);

    // Cancel
    timelock.cancel(hash_id);
    assert_only_event_cancel(timelock.contract_address, hash_id);
}

#[test]
#[should_panic(expected: ('Timelock: unexpected op state', 'ENTRYPOINT_FAILED'))]
fn test_cancel_invalid_operation() {
    let (mut timelock, mut erc721) = setup_dispatchers();

    let batched_operations = batched_operations(erc721.contract_address, timelock.contract_address);
    let hash_id = timelock.hash_operation(batched_operations, NO_PREDECESSOR, SALT);

    // PROPOSER is also CANCELLER
    testing::set_contract_address(PROPOSER());

    timelock.cancel(hash_id);
}

#[test]
#[should_panic(expected: ('Caller is missing role', 'ENTRYPOINT_FAILED'))]
fn test_cancel_unauthorized() {
    let (mut timelock, mut erc721) = setup_dispatchers();

    let batched_operations = batched_operations(erc721.contract_address, timelock.contract_address);
    let hash_id = timelock.hash_operation(batched_operations, NO_PREDECESSOR, SALT);

    // Schedule
    testing::set_contract_address(PROPOSER());
    timelock.schedule(batched_operations, NO_PREDECESSOR, SALT, MIN_DELAY);
    utils::drop_events(timelock.contract_address, 2);

    // Cancel
    testing::set_contract_address(OTHER());
    timelock.cancel(hash_id);
}

// update_delay

#[test]
#[should_panic(expected: ('Timelock: unauthorized caller', 'ENTRYPOINT_FAILED'))]
fn test_update_delay_unauthorized() {
    let mut timelock = deploy_timelock();

    timelock.update_delay(NEW_DELAY);
}

#[test]
fn test_update_delay_scheduled() {
    let mut timelock = deploy_timelock();

    let update_delay_call = Call {
        to: timelock.contract_address,
        selector: selector!("update_delay"),
        calldata: array![NEW_DELAY.into()].span()
    };
    let call_span = array![update_delay_call].span();
    let hash_id = timelock.hash_operation(call_span, NO_PREDECESSOR, SALT);

    // Schedule
    testing::set_contract_address(PROPOSER());
    timelock.schedule(call_span, NO_PREDECESSOR, SALT, MIN_DELAY);
    utils::drop_events(timelock.contract_address, 2);

    // fast-forward
    testing::set_block_timestamp(MIN_DELAY);

    // execute
    testing::set_contract_address(EXECUTOR());
    timelock.execute(call_span, NO_PREDECESSOR, SALT);
    assert_event_delay(timelock.contract_address, MIN_DELAY, NEW_DELAY);
    assert_only_event_execute(timelock.contract_address, hash_id, call_span);

    // Check new minimum delay
    let get_new_delay = timelock.get_min_delay();
    assert_eq!(get_new_delay, NEW_DELAY);
}

// hash_operation

#[test]
fn test_hash_operation() {
    let (mut timelock, mut erc721) = setup_dispatchers();

    // Call 1
    let mut calldata1 = array![];
    calldata1.append_serde(SPENDER());
    calldata1.append_serde(TOKEN_ID);

    let mut call1 = Call {
        to: erc721.contract_address, selector: selectors::approve, calldata: calldata1.span()
    };

    // Call 2
    let mut calldata2 = array![];
    calldata2.append_serde(timelock.contract_address);
    calldata2.append_serde(RECIPIENT());
    calldata2.append_serde(TOKEN_ID);
    let mut call2 = Call {
        to: erc721.contract_address, selector: selectors::transfer_from, calldata: calldata2.span()
    };

    // Hash operation
    let predecessor = 123;
    let salt = SALT;
    let call_span = array![call1, call2].span();
    let hashed_operation = timelock.hash_operation(call_span, predecessor, salt);

    // Manually set hash elements
    let mut expected_hash = PoseidonTrait::new()
        .update_with(14) // total elements of Call span
        .update_with(2) // total number of Calls
        .update_with(erc721.contract_address) // call1::to
        .update_with(selector!("approve")) // call1::selector
        .update_with(3) // call1::calldata.len
        .update_with(SPENDER()) // call1::calldata::to
        .update_with(TOKEN_ID.low) // call1::calldata::token_id.low
        .update_with(TOKEN_ID.high) // call1::calldata::token_id.high
        .update_with(erc721.contract_address) // call2::to
        .update_with(selector!("transfer_from")) // call2::selector
        .update_with(4) // call2::calldata.len
        .update_with(timelock.contract_address) // call2::calldata::from
        .update_with(RECIPIENT()) // call2::calldata::to
        .update_with(TOKEN_ID.low) // call2::calldata::token_id.low
        .update_with(TOKEN_ID.high) // call2::calldata::token_id.high
        .update_with(predecessor) // predecessor
        .update_with(salt) // salt
        .finalize();

    assert_eq!(hashed_operation, expected_hash);
}

//
// Helpers
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

fn assert_event_schedule(
    contract: ContractAddress, calls: Span<Call>, predecessor: felt252, delay: u64
) {
    let event = utils::pop_log::<TimelockControllerComponent::Event>(contract).unwrap();
    let expected = TimelockControllerComponent::Event::CallScheduled(
        CallScheduled { calls, predecessor, delay }
    );
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("CallScheduled"));
    indexed_keys.append_serde(calls);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_only_event_schedule(
    contract: ContractAddress, calls: Span<Call>, predecessor: felt252, delay: u64
) {
    assert_event_schedule(contract, calls, predecessor, delay);
    utils::assert_no_events_left(contract);
}

fn assert_event_call_salt(contract: ContractAddress, id: felt252, salt: felt252) {
    let event = utils::pop_log::<TimelockControllerComponent::Event>(contract).unwrap();
    let expected = TimelockControllerComponent::Event::CallSalt(CallSalt { id, salt });
    assert!(event == expected);
}

fn assert_only_event_call_salt(contract: ContractAddress, id: felt252, salt: felt252) {
    assert_event_call_salt(contract, id, salt);
    utils::assert_no_events_left(contract);
}

fn assert_event_execute(contract: ContractAddress, id: felt252, calls: Span<Call>) {
    let event = utils::pop_log::<TimelockControllerComponent::Event>(contract).unwrap();
    let expected = TimelockControllerComponent::Event::CallExecuted(CallExecuted { id, calls });
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("CallExecuted"));
    indexed_keys.append_serde(id);
    indexed_keys.append_serde(calls);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_only_event_execute(contract: ContractAddress, id: felt252, calls: Span<Call>) {
    assert_event_execute(contract, id, calls);
    utils::assert_no_events_left(contract);
}

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

fn assert_event_delay(contract: ContractAddress, old_duration: u64, new_duration: u64) {
    let event = utils::pop_log::<TimelockControllerComponent::Event>(contract).unwrap();
    let expected = TimelockControllerComponent::Event::MinDelayChange(MinDelayChange { old_duration, new_duration });
    assert!(event == expected);
}

fn assert_only_event_delay(contract: ContractAddress, old_duration: u64, new_duration: u64) {
    assert_event_delay(contract, old_duration, new_duration);
    utils::assert_no_events_left(contract);
}
