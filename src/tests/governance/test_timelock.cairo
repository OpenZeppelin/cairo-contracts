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
    ADMIN, ZERO, NAME, SYMBOL, BASE_URI, RECIPIENT, TOKEN_ID
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc1155::interface::IERC1155_RECEIVER_ID;
use openzeppelin::token::erc721::interface::IERC721_RECEIVER_ID;
use openzeppelin::token::erc721::interface::{IERC721DispatcherTrait, IERC721Dispatcher};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;
use starknet::contract_address_const;

type ComponentState =
    TimelockControllerComponent::ComponentState<TimelockControllerMock::ContractState>;

fn CONTRACT_STATE() -> TimelockControllerMock::ContractState {
    TimelockControllerMock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    TimelockControllerComponent::component_state_for_testing()
}

const MIN_DELAY: u64 = 2000;

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

    // The initializer has emits 11 `RoleGranted` events prior to `MinDelayChange`:
    // - Self administration
    // - Optional admin
    // - 3 proposers
    // - 3 cancellers
    // - 3 executors
    utils::drop_events(ZERO(), 11);
    assert_only_event_delay_change(ZERO(), 0, MIN_DELAY);
}

// hash_operation

#[test]
fn test_hash_operation() {
    let mut timelock = deploy_timelock();
    let mut erc721 = deploy_erc721(timelock.contract_address);
    let erc721_address = erc721.contract_address;

    // Call
    let mut calldata = array![];
    calldata.append_serde(timelock.contract_address);
    calldata.append_serde(RECIPIENT());
    calldata.append_serde(TOKEN_ID);

    let mut call = Call {
        to: erc721_address, selector: 'transfer_from', calldata: calldata.span()
    };
    let call_span = array![call].span();

    let _hash = timelock.hash_operation(call_span, 0, 0);
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
    utils::drop_event(ZERO());
}
