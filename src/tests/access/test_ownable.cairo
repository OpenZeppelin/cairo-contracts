use openzeppelin::access::ownable::OwnableComponent::InternalTrait;
use openzeppelin::access::ownable::OwnableComponent::OwnershipTransferred;
use openzeppelin::access::ownable::OwnableComponent;
use openzeppelin::access::ownable::interface::{IOwnable, IOwnableCamelOnly};
use openzeppelin::tests::mocks::ownable_mocks::DualCaseOwnableMock;
use openzeppelin::tests::utils::constants::{ZERO, OTHER, OWNER};
use openzeppelin::tests::utils::debug::DebugContractAddress;
use openzeppelin::tests::utils;
use starknet::ContractAddress;
use starknet::storage::StorageMemberAccessTrait;
use starknet::testing;

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
    utils::drop_event(ZERO());
    state
}

//
// initializer
//

#[test]
fn test_initializer_owner() {
    let mut state = COMPONENT_STATE();

    let current_owner = state.Ownable_owner.read();
    assert!(current_owner.is_zero());

    state.initializer(OWNER());

    assert_event_ownership_transferred(ZERO(), OWNER());

    let new_owner = state.Ownable_owner.read();
    assert_eq!(new_owner, OWNER());
}

//
// assert_only_owner
//

#[test]
fn test_assert_only_owner() {
    let state = setup();
    testing::set_caller_address(OWNER());
    state.assert_only_owner();
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_assert_only_owner_when_not_owner() {
    let state = setup();
    testing::set_caller_address(OTHER());
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
    state._transfer_ownership(OTHER());

    assert_event_ownership_transferred(OWNER(), OTHER());

    let current_owner = state.Ownable_owner.read();
    assert_eq!(current_owner, OTHER());
}

//
// transfer_ownership & transferOwnership
//

#[test]
fn test_transfer_ownership() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.transfer_ownership(OTHER());

    assert_event_ownership_transferred(OWNER(), OTHER());
    assert_eq!(state.owner(), OTHER());
}

#[test]
#[should_panic(expected: ('New owner is the zero address',))]
fn test_transfer_ownership_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
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
    testing::set_caller_address(OTHER());
    state.transfer_ownership(OTHER());
}

#[test]
fn test_transferOwnership() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.transferOwnership(OTHER());

    assert_event_ownership_transferred(OWNER(), OTHER());
    assert_eq!(state.owner(), OTHER());
}

#[test]
#[should_panic(expected: ('New owner is the zero address',))]
fn test_transferOwnership_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
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
    testing::set_caller_address(OTHER());
    state.transferOwnership(OTHER());
}

//
// renounce_ownership & renounceOwnership
//

#[test]
fn test_renounce_ownership() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.renounce_ownership();

    assert_event_ownership_transferred(OWNER(), ZERO());
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
    testing::set_caller_address(OTHER());
    state.renounce_ownership();
}

#[test]
fn test_renounceOwnership() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.renounceOwnership();

    assert_event_ownership_transferred(OWNER(), ZERO());
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
    testing::set_caller_address(OTHER());
    state.renounceOwnership();
}

//
// Helpers
//

fn assert_event_ownership_transferred(previous_owner: ContractAddress, new_owner: ContractAddress) {
    let event = utils::pop_log::<OwnershipTransferred>(ZERO(), selector!("OwnershipTransferred")).unwrap();
    assert_eq!(event.previous_owner, previous_owner);
    assert_eq!(event.new_owner, new_owner);
    utils::assert_no_events_left(ZERO());
}
