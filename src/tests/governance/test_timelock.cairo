use openzeppelin::access::accesscontrol::AccessControlComponent::{
    AccessControlImpl, InternalImpl as AccessControlInternalImpl
};
use openzeppelin::governance::timelock::TimelockControllerComponent::Call;
use openzeppelin::governance::timelock::TimelockControllerComponent::{
    CallScheduled, CallExecuted, CallSalt, Cancelled, MinDelayChange
};
use openzeppelin::governance::timelock::TimelockControllerComponent::{
    PROPOSER_ROLE, EXECUTOR_ROLE, CANCELLER_ROLE
};
use openzeppelin::governance::timelock::TimelockControllerComponent::{
    TimelockImpl, InternalImpl as TimelockInternalImpl
};
use openzeppelin::governance::timelock::TimelockControllerComponent;
use openzeppelin::governance::timelock::interface::ITimelock;
use openzeppelin::governance::timelock::interface::{ITimelockDispatcher, ITimelockDispatcherTrait};
use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin::tests::mocks::erc721_mocks::DualCaseERC721Mock;
use openzeppelin::tests::mocks::timelock_mocks::TimelockControllerMock;
use openzeppelin::tests::utils::constants::{
    ADMIN, ZERO, NAME, SYMBOL, BASE_URI, RECIPIENT, SPENDER, OTHER, SALT, TOKEN_ID
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc1155::interface::IERC1155_RECEIVER_ID;
use openzeppelin::token::erc721::interface::IERC721_RECEIVER_ID;
use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;
use starknet::contract_address_const;
use openzeppelin::governance::timelock::timelock_controller::{CallPartialEq, HashCallImpl};
use hash::{HashStateTrait, HashStateExTrait};
use poseidon::PoseidonTrait;

type ComponentState =
    TimelockControllerComponent::ComponentState<TimelockControllerMock::ContractState>;

fn CONTRACT_STATE() -> TimelockControllerMock::ContractState {
    TimelockControllerMock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    TimelockControllerComponent::component_state_for_testing()
}

const MIN_DELAY: u64 = 1000;

fn get_proposers() -> (ContractAddress, ContractAddress, ContractAddress) {
    let p1 = contract_address_const::<'PROPOSER_1'>();
    let p2 = contract_address_const::<'PROPOSER_2'>();
    let p3 = contract_address_const::<'PROPOSER_3'>();
    (p1, p2, p3)
}

fn get_proposer() -> ContractAddress {
    let (p1, _, _) = get_proposers();
    p1
}

fn get_executors() -> (ContractAddress, ContractAddress, ContractAddress) {
    let e1 = contract_address_const::<'EXECUTOR_1'>();
    let e2 = contract_address_const::<'EXECUTOR_2'>();
    let e3 = contract_address_const::<'EXECUTOR_3'>();
    (e1, e2, e3)
}

fn get_executor() -> ContractAddress {
    let (e1, _, _) = get_executors();
    e1
}

fn single_operation(erc721_addr: ContractAddress) -> Call {
    // Call: approve
    let mut calldata = array![];
    calldata.append_serde(SPENDER());
    calldata.append_serde(TOKEN_ID);

    Call {
        to: erc721_addr, selector: 'approve', calldata: calldata.span()
    }
}

fn batched_operations(erc721_addr: ContractAddress, timelock_addr: ContractAddress) -> Span<Call> {
    // Call 1: approve
    let mut calldata1 = array![];
    calldata1.append_serde(SPENDER());
    calldata1.append_serde(TOKEN_ID);

    let call1 = Call{ to: erc721_addr, selector: 'approve', calldata: calldata1.span() };

    // Call 2: transfer_from
    let mut calldata2 = array![];
    calldata2.append_serde(timelock_addr);
    calldata2.append_serde(RECIPIENT());
    calldata2.append_serde(TOKEN_ID);
    let call2 = Call {
        to: erc721_addr, selector: 'transfer_from', calldata: calldata2.span()
    };

    array![call1, call2].span()
}

fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    let min_delay = MIN_DELAY;

    let (p1, p2, p3) = get_proposers();
    let mut proposers = array![p1, p2, p3].span();

    let (e1, e2, e3) = get_executors();
    let mut executors = array![e1, e2, e3].span();

    let admin = ADMIN();

    state.initializer(min_delay, proposers, executors, admin);
    // The initializer has emits 11 `RoleGranted` events:
    // - Self administration
    // - Optional admin
    // - 3 proposers
    // - 3 cancellers
    // - 3 executors
    utils::drop_events(ZERO(), 11);

    state
}

fn deploy_timelock() -> ITimelockDispatcher {
    let mut calldata = array![];

    let (p1, p2, p3) = get_proposers();
    let mut proposers = array![p1, p2, p3].span();

    let (e1, e2, e3) = get_executors();
    let mut executors = array![e1, e2, e3].span();

    calldata.append_serde(MIN_DELAY);
    calldata.append_serde(proposers);
    calldata.append_serde(executors);
    calldata.append_serde(ADMIN());

    let address = utils::deploy(TimelockControllerMock::TEST_CLASS_HASH, calldata);
    ITimelockDispatcher { contract_address: address }
}

fn deploy_erc721(recipient: ContractAddress) -> IERC721Dispatcher {
    let mut calldata = array![];

    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(recipient);
    calldata.append_serde(TOKEN_ID);

    let address = utils::deploy(DualCaseERC721Mock::TEST_CLASS_HASH, calldata);
    IERC721Dispatcher { contract_address: address }
}

// initializer

#[test]
fn test_initializer_roles() {
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

    let (p1, p2, p3) = get_proposers();
    let mut proposers = array![p1, p2, p3].span();

    let (e1, e2, e3) = get_executors();
    let mut executors = array![e1, e2, e3].span();

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

    let (p1, p2, p3) = get_proposers();
    let mut proposers = array![p1, p2, p3].span();

    let (e1, e2, e3) = get_executors();
    let mut executors = array![e1, e2, e3].span();

    let admin = ADMIN();

    state.initializer(min_delay, proposers, executors, admin);

    // Check minimum delay is set
    let delay = state.get_min_delay();
    assert_eq!(delay, MIN_DELAY);

    // The initializer emits 11 `RoleGranted` events prior to `MinDelayChange`:
    // - Self administration
    // - Optional admin
    // - 3 proposers
    // - 3 cancellers
    // - 3 executors
    utils::drop_events(ZERO(), 11);
    assert_only_event_delay_change(ZERO(), 0, MIN_DELAY);
}

// schedule

#[test]
fn test_schedule_from_proposer() {
    let mut timelock = deploy_timelock();
    let mut erc721 = deploy_erc721(timelock.contract_address);
    utils::drop_events(timelock.contract_address, 12);

    let (proposer, _, _) = get_proposers();
    starknet::testing::set_contract_address(proposer);

    let batched_operations = batched_operations(erc721.contract_address, timelock.contract_address);
    let predecessor = 0;
    let salt = SALT;
    let delay = MIN_DELAY;

    timelock.schedule(batched_operations, predecessor, salt, delay);
    assert_event_schedule(timelock.contract_address, batched_operations, predecessor, delay);

    // Check timestamp
    let hash_id = timelock.hash_operation(batched_operations, predecessor, salt);
    let operation_ts = timelock.get_timestamp(hash_id);
    let expected_ts = starknet::get_block_timestamp() + delay;
    assert_eq!(operation_ts, expected_ts);

    assert_only_event_call_salt(timelock.contract_address, hash_id, salt);
}

#[test]
#[should_panic(expected: ('Timelock: unexpected op state', 'ENTRYPOINT_FAILED'))]
fn test_schedule_overwrite() {
    let mut timelock = deploy_timelock();
    let mut erc721 = deploy_erc721(timelock.contract_address);
    utils::drop_events(timelock.contract_address, 12);

    let (proposer, _, _) = get_proposers();
    starknet::testing::set_contract_address(proposer);

    let batched_operations = batched_operations(erc721.contract_address, timelock.contract_address);
    let predecessor = 0;
    let salt = SALT;
    let delay = MIN_DELAY;

    timelock.schedule(batched_operations, predecessor, salt, delay);
    timelock.schedule(batched_operations, predecessor, salt, delay);
}

#[test]
#[should_panic(expected: ('Caller is missing role', 'ENTRYPOINT_FAILED'))]
fn test_schedule_unauthorized() {
    let mut timelock = deploy_timelock();
    let mut erc721 = deploy_erc721(timelock.contract_address);
    utils::drop_events(timelock.contract_address, 12);

    starknet::testing::set_contract_address(OTHER());
    let batched_operations = batched_operations(erc721.contract_address, timelock.contract_address);
    let predecessor = 0;
    let salt = SALT;
    let delay = MIN_DELAY;

    timelock.schedule(batched_operations, predecessor, salt, delay);
}

#[test]
#[should_panic(expected: ('Timelock: insufficient delay', 'ENTRYPOINT_FAILED'))]
fn test_schedule_bad_min_delay() {
    let mut timelock = deploy_timelock();
    let mut erc721 = deploy_erc721(timelock.contract_address);
    utils::drop_events(timelock.contract_address, 12);

    let (proposer, _, _) = get_proposers();
    starknet::testing::set_contract_address(proposer);

    let batched_operations = batched_operations(erc721.contract_address, timelock.contract_address);
    let predecessor = 0;
    let salt = SALT;
    let bad_delay = MIN_DELAY - 1;

    timelock.schedule(batched_operations, predecessor, salt, bad_delay);
}

#[test]
fn test_schedule_with_salt_zero() {
    let mut timelock = deploy_timelock();
    let mut erc721 = deploy_erc721(timelock.contract_address);
    utils::drop_events(timelock.contract_address, 12);

    let proposer = get_proposer();
    starknet::testing::set_contract_address(proposer);

    // Schedule
    let batched_operations = batched_operations(erc721.contract_address, timelock.contract_address);
    let predecessor = 0;
    let salt = 0;
    let delay = MIN_DELAY;

    timelock.schedule(batched_operations, predecessor, salt, delay);
    assert_only_event_schedule(timelock.contract_address, batched_operations, predecessor, delay);

    // Check timestamp
    let hash_id = timelock.hash_operation(batched_operations, predecessor, salt);
    let operation_ts = timelock.get_timestamp(hash_id);
    let expected_ts = starknet::get_block_timestamp() + delay;
    assert_eq!(operation_ts, expected_ts)
}

// execute

// hash_operation

#[test]
fn test_hash_operation() {
    let mut timelock = deploy_timelock();
    let mut erc721 = deploy_erc721(timelock.contract_address);
    let erc721_address = erc721.contract_address;

    // Call 1
    let mut calldata1 = array![];
    calldata1.append_serde(SPENDER());
    calldata1.append_serde(TOKEN_ID);

    let mut call1 = Call {
        to: erc721_address, selector: 'approve', calldata: calldata1.span()
    };

    // Call 2
    let mut calldata2 = array![];
    calldata2.append_serde(timelock.contract_address);
    calldata2.append_serde(RECIPIENT());
    calldata2.append_serde(TOKEN_ID);
    let mut call2 = Call {
        to: erc721_address, selector: 'transfer_from', calldata: calldata2.span()
    };

    // Hash operation
    let predecessor = 123;
    let salt = SALT;
    let call_span = array![call1, call2].span();
    let hashed_operation = timelock.hash_operation(call_span, predecessor, salt);

    // Manually set hash elements
    let mut expected_hash = PoseidonTrait::new()
    .update_with(14)                        // total elements of Call span
    .update_with(2)                         // total number of Calls
    .update_with(erc721_address)            // call1::to
    .update_with('approve')                 // call1::selector
    .update_with(3)                         // call1::calldata.len
    .update_with(SPENDER())                 // call1::calldata::to
    .update_with(TOKEN_ID.low)              // call1::calldata::token_id.low
    .update_with(TOKEN_ID.high)             // call1::calldata::token_id.high
    .update_with(erc721_address)            // call2::to
    .update_with('transfer_from')           // call2::selector
    .update_with(4)                         // call2::calldata.len
    .update_with(timelock.contract_address) // call2::calldata::from
    .update_with(RECIPIENT())               // call2::calldata::to
    .update_with(TOKEN_ID.low)              // call2::calldata::token_id.low
    .update_with(TOKEN_ID.high)             // call2::calldata::token_id.high
    .update_with(predecessor)               // predecessor
    .update_with(salt)                      // salt
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
    utils::drop_event(contract);
}

fn assert_event_schedule(contract: ContractAddress, calls: Span<Call>, predecessor: felt252, delay: u64) {
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

fn assert_only_event_schedule(contract: ContractAddress, calls: Span<Call>, predecessor: felt252, delay: u64) {
    assert_event_schedule(contract, calls, predecessor, delay);
    utils::drop_event(contract);
}

fn assert_event_call_salt(contract: ContractAddress, id: felt252, salt: felt252) {
    let event = utils::pop_log::<TimelockControllerComponent::Event>(contract).unwrap();
    let expected = TimelockControllerComponent::Event::CallSalt(
        CallSalt { id, salt }
    );
    assert!(event == expected);
}

fn assert_only_event_call_salt(contract: ContractAddress, id: felt252, salt: felt252) {
    assert_event_call_salt(contract, id, salt);
    utils::drop_event(contract);
}
