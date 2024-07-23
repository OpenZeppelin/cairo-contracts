use core::num::traits::Zero;
use openzeppelin::access::ownable::OwnableComponent::InternalTrait;
use openzeppelin::access::ownable::OwnableComponent;
use openzeppelin::access::ownable::interface::{IOwnable, IOwnableCamelOnly};
use openzeppelin::tests::mocks::ownable_mocks::DualCaseOwnableMock;
use openzeppelin::tests::utils::constants::{ZERO, OTHER, OWNER};
use snforge_std::{spy_events, test_address, start_cheat_caller_address};

use super::common::OwnableSpyHelpers;

//
// Setup
//

type ComponentState = OwnableComponent::ComponentState<DualCaseOwnableMock::ContractState>;

fn COMPONENT_STATE() -> ComponentState {
    OwnableComponent::component_state_for_testing()
}

fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    state.initializer(OWNER());
    state
}

//
// initializer
//

#[test]
fn test_initializer_owner() {
    let mut state = COMPONENT_STATE();
    let mut spy = spy_events();

    let current_owner = state.Ownable_owner.read();
    assert!(current_owner.is_zero());

    state.initializer(OWNER());

    spy.assert_only_event_ownership_transferred(test_address(), ZERO(), OWNER());

    let new_owner = state.Ownable_owner.read();
    assert_eq!(new_owner, OWNER());
}

//
// assert_only_owner
//

#[test]
fn test_assert_only_owner() {
    let state = setup();
    start_cheat_caller_address(test_address(), OWNER());
    state.assert_only_owner();
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_assert_only_owner_when_not_owner() {
    let state = setup();
    start_cheat_caller_address(test_address(), OTHER());
    state.assert_only_owner();
}

#[test]
#[should_panic(expected: ('Caller is the zero address',))]
fn test_assert_only_owner_when_caller_zero() {
    let state = setup();
    state.assert_only_owner();
}

//
// _transfer_ownership
//

#[test]
fn test__transfer_ownership() {
    let mut state = setup();
    let mut spy = spy_events();
    state._transfer_ownership(OTHER());

    spy.assert_only_event_ownership_transferred(test_address(), OWNER(), OTHER());

    let current_owner = state.Ownable_owner.read();
    assert_eq!(current_owner, OTHER());
}

//
// transfer_ownership & transferOwnership
//

#[test]
fn test_transfer_ownership() {
    let mut state = setup();
    let mut spy = spy_events();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, OWNER());
    state.transfer_ownership(OTHER());

    spy.assert_only_event_ownership_transferred(contract_address, OWNER(), OTHER());
    assert_eq!(state.owner(), OTHER());
}

#[test]
#[should_panic(expected: ('New owner is the zero address',))]
fn test_transfer_ownership_to_zero() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OWNER());
    state.transfer_ownership(ZERO());
}

#[test]
#[should_panic(expected: ('Caller is the zero address',))]
fn test_transfer_ownership_from_zero() {
    let mut state = setup();
    state.transfer_ownership(OTHER());
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_transfer_ownership_from_nonowner() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OTHER());
    state.transfer_ownership(OTHER());
}

#[test]
fn test_transferOwnership() {
    let mut state = setup();
    let mut spy = spy_events();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, OWNER());
    state.transferOwnership(OTHER());

    spy.assert_only_event_ownership_transferred(contract_address, OWNER(), OTHER());
    assert_eq!(state.owner(), OTHER());
}

#[test]
#[should_panic(expected: ('New owner is the zero address',))]
fn test_transferOwnership_to_zero() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OWNER());
    state.transferOwnership(ZERO());
}

#[test]
#[should_panic(expected: ('Caller is the zero address',))]
fn test_transferOwnership_from_zero() {
    let mut state = setup();
    state.transferOwnership(OTHER());
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_transferOwnership_from_nonowner() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OTHER());
    state.transferOwnership(OTHER());
}

//
// renounce_ownership & renounceOwnership
//

#[test]
fn test_renounce_ownership() {
    let mut state = setup();
    let mut spy = spy_events();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, OWNER());
    state.renounce_ownership();

    spy.assert_only_event_ownership_transferred(contract_address, OWNER(), ZERO());
    assert!(state.owner().is_zero());
}

#[test]
#[should_panic(expected: ('Caller is the zero address',))]
fn test_renounce_ownership_from_zero_address() {
    let mut state = setup();
    state.renounce_ownership();
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_renounce_ownership_from_nonowner() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OTHER());
    state.renounce_ownership();
}

#[test]
fn test_renounceOwnership() {
    let mut state = setup();
    let mut spy = spy_events();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, OWNER());
    state.renounceOwnership();

    spy.assert_only_event_ownership_transferred(contract_address, OWNER(), ZERO());
    assert!(state.owner().is_zero());
}

#[test]
#[should_panic(expected: ('Caller is the zero address',))]
fn test_renounceOwnership_from_zero_address() {
    let mut state = setup();
    state.renounceOwnership();
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_renounceOwnership_from_nonowner() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OTHER());
    state.renounceOwnership();
}
