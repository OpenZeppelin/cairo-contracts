use core::num::traits::Bounded;
use openzeppelin_interfaces::erc6909 as interface;
use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin_test_common::erc6909::ERC6909SpyHelpers;
use openzeppelin_test_common::mocks::erc6909::{ERC6909Mock, ERC6909MockWithHooks};
use openzeppelin_testing::constants::{OWNER, RECIPIENT, SPENDER, SUPPLY, TOKEN_ID, VALUE, ZERO};
use openzeppelin_testing::{EventSpyExt, EventSpyQueue as EventSpy, ExpectedEvent, spy_events};
use snforge_std::{start_cheat_caller_address, test_address};
use starknet::ContractAddress;
use crate::erc6909::ERC6909Component;
use crate::erc6909::ERC6909Component::{ERC6909Impl, InternalImpl};

type ComponentState = ERC6909Component::ComponentState<ERC6909Mock::ContractState>;
type ComponentStateWithHooks =
    ERC6909Component::ComponentState<ERC6909MockWithHooks::ContractState>;


fn CONTRACT_STATE() -> ERC6909Mock::ContractState {
    ERC6909Mock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    ERC6909Component::component_state_for_testing()
}

fn COMPONENT_STATE_WITH_HOOKS() -> ComponentStateWithHooks {
    ERC6909Component::component_state_for_testing()
}

fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    state.initializer();
    state.mint(OWNER, TOKEN_ID, SUPPLY);
    state
}

fn setup_with_hooks() -> ComponentStateWithHooks {
    let mut state = COMPONENT_STATE_WITH_HOOKS();
    state.initializer();
    state.mint(OWNER, TOKEN_ID, SUPPLY);
    state
}

#[test]
fn test_initializer() {
    let mut state = COMPONENT_STATE();
    let mock_state = CONTRACT_STATE();

    state.initializer();

    let supports_ierc6909 = mock_state.supports_interface(interface::IERC6909_ID);
    assert!(supports_ierc6909);

    let supports_isrc5 = mock_state
        .supports_interface(openzeppelin_interfaces::introspection::ISRC5_ID);
    assert!(supports_isrc5);
}


#[test]
fn test_balance_of() {
    let state = setup();
    assert_eq!(state.balance_of(OWNER, TOKEN_ID), SUPPLY);
}

#[test]
fn test_allowance() {
    let mut state = setup();
    assert_eq!(state.allowance(OWNER, SPENDER, TOKEN_ID), 0);
    state._approve(OWNER, SPENDER, TOKEN_ID, VALUE);
    assert_eq!(state.allowance(OWNER, SPENDER, TOKEN_ID), VALUE);
}

#[test]
fn test_is_operator() {
    let mut state = COMPONENT_STATE();

    assert!(!state.is_operator(OWNER, SPENDER));

    state._set_operator(OWNER, SPENDER, true);
    assert!(state.is_operator(OWNER, SPENDER));

    state._set_operator(OWNER, SPENDER, false);
    assert!(!state.is_operator(OWNER, SPENDER));
}


#[test]
fn test_transfer_success() {
    let mut state = setup();
    let contract_address = test_address();
    let caller = OWNER;
    let receiver = RECIPIENT;
    let id = TOKEN_ID;
    let amount = VALUE;

    start_cheat_caller_address(contract_address, caller);

    let mut spy = spy_events();
    assert_state_before_transfer(caller, receiver, id, amount, SUPPLY);

    assert!(state.transfer(receiver, id, amount));

    spy.assert_only_event_transfer(contract_address, caller, caller, receiver, id, amount);
    assert_state_after_transfer(caller, receiver, id, amount, SUPPLY);
}

#[test]
#[should_panic(expected: 'ERC6909: invalid receiver')]
fn test_transfer_invalid_receiver_zero() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OWNER);
    state.transfer(ZERO, TOKEN_ID, VALUE);
}

#[test]
#[should_panic(expected: 'ERC6909: insufficient balance')]
fn test_transfer_insufficient_balance() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), SPENDER);
    state.transfer(RECIPIENT, TOKEN_ID, VALUE);
}


#[test]
fn test_transfer_from_by_sender_itself() {
    let mut state = setup();
    let contract_address = test_address();
    let sender = OWNER;
    let receiver = RECIPIENT;

    start_cheat_caller_address(contract_address, sender);
    let mut spy = spy_events();

    assert_state_before_transfer(sender, receiver, TOKEN_ID, VALUE, SUPPLY);
    assert!(state.transfer_from(sender, receiver, TOKEN_ID, VALUE));
    spy.assert_only_event_transfer(contract_address, sender, sender, receiver, TOKEN_ID, VALUE);
    assert_state_after_transfer(sender, receiver, TOKEN_ID, VALUE, SUPPLY);
}

#[test]
fn test_transfer_from_with_allowance() {
    let mut state = setup();
    let contract_address = test_address();

    state._approve(OWNER, SPENDER, TOKEN_ID, VALUE);
    assert_eq!(state.allowance(OWNER, SPENDER, TOKEN_ID), VALUE);

    start_cheat_caller_address(contract_address, SPENDER);
    let mut spy = spy_events();

    assert!(state.transfer_from(OWNER, RECIPIENT, TOKEN_ID, VALUE));

    spy.assert_only_event_transfer(contract_address, SPENDER, OWNER, RECIPIENT, TOKEN_ID, VALUE);

    assert_eq!(state.allowance(OWNER, SPENDER, TOKEN_ID), 0);
    assert_eq!(state.balance_of(OWNER, TOKEN_ID), SUPPLY - VALUE);
    assert_eq!(state.balance_of(RECIPIENT, TOKEN_ID), VALUE);
}

#[test]
fn test_transfer_from_with_infinite_allowance_does_not_decrease() {
    let mut state = setup();
    let contract_address = test_address();

    state._approve(OWNER, SPENDER, TOKEN_ID, Bounded::MAX);
    assert_eq!(state.allowance(OWNER, SPENDER, TOKEN_ID), Bounded::MAX);

    start_cheat_caller_address(contract_address, SPENDER);
    state.transfer_from(OWNER, RECIPIENT, TOKEN_ID, VALUE);

    assert_eq!(state.allowance(OWNER, SPENDER, TOKEN_ID), Bounded::MAX);
    assert_eq!(state.balance_of(OWNER, TOKEN_ID), SUPPLY - VALUE);
    assert_eq!(state.balance_of(RECIPIENT, TOKEN_ID), VALUE);
}

#[test]
fn test_transfer_from_operator_bypass_allowance() {
    let mut state = setup();
    let contract_address = test_address();

    state._set_operator(OWNER, SPENDER, true);

    start_cheat_caller_address(contract_address, SPENDER);
    let mut spy = spy_events();

    assert!(state.transfer_from(OWNER, RECIPIENT, TOKEN_ID, VALUE));

    spy.assert_only_event_transfer(contract_address, SPENDER, OWNER, RECIPIENT, TOKEN_ID, VALUE);
    assert_eq!(state.allowance(OWNER, SPENDER, TOKEN_ID), 0);
}

#[test]
#[should_panic(expected: 'ERC6909: insufficient allowance')]
fn test_transfer_from_insufficient_allowance() {
    let mut state = setup();
    let lesser = VALUE - 1;
    state._approve(OWNER, SPENDER, TOKEN_ID, lesser);

    start_cheat_caller_address(test_address(), SPENDER);
    state.transfer_from(OWNER, RECIPIENT, TOKEN_ID, VALUE);
}


#[test]
fn test_approve_external() {
    let mut state = setup();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, OWNER);
    let mut spy = spy_events();

    assert!(state.approve(SPENDER, TOKEN_ID, VALUE));

    spy.assert_only_event_approval(contract_address, OWNER, SPENDER, TOKEN_ID, VALUE);
    assert_eq!(state.allowance(OWNER, SPENDER, TOKEN_ID), VALUE);
}

#[test]
#[should_panic(expected: 'ERC6909: invalid approver')]
fn test__approve_invalid_owner_zero() {
    let mut state = setup();
    state._approve(ZERO, SPENDER, TOKEN_ID, VALUE);
}

#[test]
#[should_panic(expected: 'ERC6909: invalid spender')]
fn test__approve_invalid_spender_zero() {
    let mut state = setup();
    state._approve(OWNER, ZERO, TOKEN_ID, VALUE);
}


#[test]
fn test_set_operator_external() {
    let mut state = setup();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, OWNER);
    let mut spy = spy_events();

    assert!(state.set_operator(SPENDER, true));
    spy.assert_only_event_operator_set(contract_address, OWNER, SPENDER, true);
    assert!(state.is_operator(OWNER, SPENDER));

    assert!(state.set_operator(SPENDER, false));
    spy.assert_only_event_operator_set(contract_address, OWNER, SPENDER, false);
    assert!(!state.is_operator(OWNER, SPENDER));
}


#[test]
fn test__burn_reduces_balance_and_emits() {
    let mut state = setup();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, OWNER);
    let mut spy = spy_events();

    assert_eq!(state.balance_of(OWNER, TOKEN_ID), SUPPLY);
    state._burn(OWNER, TOKEN_ID, VALUE);

    spy.assert_only_event_transfer(contract_address, OWNER, OWNER, ZERO, TOKEN_ID, VALUE);

    assert_eq!(state.balance_of(OWNER, TOKEN_ID), SUPPLY - VALUE);
}

#[test]
#[should_panic(expected: 'ERC6909: invalid sender')]
fn test__burn_invalid_sender_zero() {
    let mut state = setup();
    state._burn(ZERO, TOKEN_ID, VALUE);
}

#[test]
#[should_panic(expected: 'ERC6909: insufficient balance')]
fn test__burn_insufficient_balance() {
    let mut state = setup();
    state._burn(OWNER, TOKEN_ID, SUPPLY + 1);
}


#[test]
fn test_update_calls_before_and_after_update_hooks_on_transfer() {
    let mut state = setup_with_hooks();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, OWNER);
    let mut spy = spy_events();

    let amount = VALUE;
    let id = TOKEN_ID;

    state.transfer(RECIPIENT, id, amount);

    spy.assert_event_before_update(contract_address, OWNER, RECIPIENT, id, amount);
    spy.assert_event_after_update(contract_address, OWNER, RECIPIENT, id, amount);
}


fn assert_state_before_transfer(
    sender: ContractAddress, receiver: ContractAddress, id: u256, amount: u256, total: u256,
) {
    let state = COMPONENT_STATE();
    assert_eq!(state.balance_of(sender, id), total);
    assert_eq!(state.balance_of(receiver, id), 0);
    assert!(amount <= total);
}

fn assert_state_after_transfer(
    sender: ContractAddress, receiver: ContractAddress, id: u256, amount: u256, total_before: u256,
) {
    let state = COMPONENT_STATE();
    assert_eq!(state.balance_of(sender, id), total_before - amount);
    assert_eq!(state.balance_of(receiver, id), amount);
}

#[generate_trait]
impl ERC6909HooksSpyHelpersImpl of ERC6909HooksSpyHelpers {
    fn assert_event_before_update(
        ref self: EventSpy,
        contract: ContractAddress,
        from: ContractAddress,
        recipient: ContractAddress,
        id: u256,
        amount: u256,
    ) {
        let expected = ExpectedEvent::new()
            .key(selector!("BeforeUpdate"))
            .data(from)
            .data(recipient)
            .data(id)
            .data(amount);
        self.assert_emitted_single(contract, expected);
    }

    fn assert_event_after_update(
        ref self: EventSpy,
        contract: ContractAddress,
        from: ContractAddress,
        recipient: ContractAddress,
        id: u256,
        amount: u256,
    ) {
        let expected = ExpectedEvent::new()
            .key(selector!("AfterUpdate"))
            .data(from)
            .data(recipient)
            .data(id)
            .data(amount);
        self.assert_emitted_single(contract, expected);
    }
}

