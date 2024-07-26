use core::num::traits::Zero;
use openzeppelin_access::ownable::OwnableComponent::InternalTrait;
use openzeppelin_access::ownable::OwnableComponent::OwnershipTransferStarted;
use openzeppelin_access::ownable::OwnableComponent;
use openzeppelin_access::ownable::interface::{IOwnableTwoStep, IOwnableTwoStepCamelOnly};
use openzeppelin_access::tests::mocks::ownable_mocks::DualCaseTwoStepOwnableMock;
use openzeppelin_utils::serde::SerializedAppend;
use openzeppelin_utils::test_utils::constants::{ZERO, OWNER, OTHER, NEW_OWNER};
use openzeppelin_utils::test_utils;
use starknet::ContractAddress;
use starknet::testing;

use super::common::assert_only_event_ownership_transferred;

//
// Setup
//

type ComponentState = OwnableComponent::ComponentState<DualCaseTwoStepOwnableMock::ContractState>;


fn COMPONENT_STATE() -> ComponentState {
    OwnableComponent::component_state_for_testing()
}

fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    state.initializer(OWNER());
    test_utils::drop_event(ZERO());
    state
}

//
// initializer
//

#[test]
fn test_initializer_owner_pending_owner() {
    let mut state = COMPONENT_STATE();
    assert!(state.Ownable_owner.read().is_zero());
    assert!(state.Ownable_pending_owner.read().is_zero());
    state.initializer(OWNER());

    assert_only_event_ownership_transferred(ZERO(), ZERO(), OWNER());

    assert_eq!(state.Ownable_owner.read(), OWNER());
    assert!(state.Ownable_pending_owner.read().is_zero());
}

//
// _accept_ownership
//

#[test]
fn test__accept_ownership() {
    let mut state = setup();
    state.Ownable_pending_owner.write(OTHER());

    state._accept_ownership();

    assert_only_event_ownership_transferred(ZERO(), OWNER(), OTHER());
    assert_eq!(state.owner(), OTHER());
    assert!(state.pending_owner().is_zero());
}

//
// _propose_owner
//

#[test]
fn test__propose_owner() {
    let mut state = setup();

    state._propose_owner(OTHER());

    assert_event_ownership_transfer_started(OWNER(), OTHER());
    assert_eq!(state.owner(), OWNER());
    assert_eq!(state.pending_owner(), OTHER());
}

// transfer_ownership & transferOwnership

#[test]
fn test_transfer_ownership() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.transfer_ownership(OTHER());

    assert_event_ownership_transfer_started(OWNER(), OTHER());
    assert_eq!(state.owner(), OWNER());
    assert_eq!(state.pending_owner(), OTHER());

    // Transferring to yet another owner while pending is set should work
    state.transfer_ownership(NEW_OWNER());

    assert_event_ownership_transfer_started(OWNER(), NEW_OWNER());
    assert_eq!(state.owner(), OWNER());
    assert_eq!(state.pending_owner(), NEW_OWNER());
}

#[test]
fn test_transfer_ownership_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.transfer_ownership(ZERO());

    assert_event_ownership_transfer_started(OWNER(), ZERO());
    assert_eq!(state.owner(), OWNER());
    assert_eq!(state.pending_owner(), ZERO());
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

    assert_event_ownership_transfer_started(OWNER(), OTHER());
    assert_eq!(state.owner(), OWNER());
    assert_eq!(state.pendingOwner(), OTHER());

    // Transferring to yet another owner while pending is set should work
    state.transferOwnership(NEW_OWNER());

    assert_event_ownership_transfer_started(OWNER(), NEW_OWNER());
    assert_eq!(state.owner(), OWNER());
    assert_eq!(state.pendingOwner(), NEW_OWNER());
}

#[test]
fn test_transferOwnership_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.transferOwnership(ZERO());

    assert_event_ownership_transfer_started(OWNER(), ZERO());
    assert_eq!(state.owner(), OWNER());
    assert!(state.pendingOwner().is_zero());
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
// accept_ownership & acceptOwnership
//

#[test]
fn test_accept_ownership() {
    let mut state = setup();
    state.Ownable_pending_owner.write(OTHER());
    testing::set_caller_address(OTHER());

    state.accept_ownership();

    assert_only_event_ownership_transferred(ZERO(), OWNER(), OTHER());
    assert_eq!(state.owner(), OTHER());
    assert!(state.pending_owner().is_zero());
}

#[test]
#[should_panic(expected: ('Caller is not the pending owner',))]
fn test_accept_ownership_from_nonpending() {
    let mut state = setup();
    state.Ownable_pending_owner.write(NEW_OWNER());
    testing::set_caller_address(OTHER());
    state.accept_ownership();
}

#[test]
fn test_acceptOwnership() {
    let mut state = setup();
    state.Ownable_pending_owner.write(OTHER());
    testing::set_caller_address(OTHER());

    state.acceptOwnership();

    assert_only_event_ownership_transferred(ZERO(), OWNER(), OTHER());
    assert_eq!(state.owner(), OTHER());
    assert!(state.pendingOwner().is_zero());
}

#[test]
#[should_panic(expected: ('Caller is not the pending owner',))]
fn test_acceptOwnership_from_nonpending() {
    let mut state = setup();
    state.Ownable_pending_owner.write(NEW_OWNER());
    testing::set_caller_address(OTHER());
    state.acceptOwnership();
}

//
// renounce_ownership & renounceOwnership
//

#[test]
fn test_renounce_ownership() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.renounce_ownership();

    assert_only_event_ownership_transferred(ZERO(), OWNER(), ZERO());

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

    assert_only_event_ownership_transferred(ZERO(), OWNER(), ZERO());

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

#[test]
fn test_full_two_step_transfer() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.transfer_ownership(OTHER());

    assert_event_ownership_transfer_started(OWNER(), OTHER());
    assert_eq!(state.owner(), OWNER());
    assert_eq!(state.pending_owner(), OTHER());

    testing::set_caller_address(OTHER());
    state.accept_ownership();

    assert_only_event_ownership_transferred(ZERO(), OWNER(), OTHER());
    assert_eq!(state.owner(), OTHER());
    assert!(state.pending_owner().is_zero());
}

#[test]
fn test_pending_accept_after_owner_renounce() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.transfer_ownership(OTHER());

    assert_event_ownership_transfer_started(OWNER(), OTHER());
    assert_eq!(state.owner(), OWNER());
    assert_eq!(state.pending_owner(), OTHER());

    state.renounce_ownership();

    assert_only_event_ownership_transferred(ZERO(), OWNER(), ZERO());
    assert!(state.owner().is_zero());

    testing::set_caller_address(OTHER());
    state.accept_ownership();

    assert_only_event_ownership_transferred(ZERO(), ZERO(), OTHER());
    assert_eq!(state.owner(), OTHER());
    assert!(state.pending_owner().is_zero());
}

//
// Helpers
//

fn assert_event_ownership_transfer_started(
    previous_owner: ContractAddress, new_owner: ContractAddress
) {
    let event = test_utils::pop_log::<OwnableComponent::Event>(ZERO()).unwrap();
    let expected = OwnableComponent::Event::OwnershipTransferStarted(
        OwnershipTransferStarted { previous_owner, new_owner }
    );
    assert!(event == expected);
    test_utils::assert_no_events_left(ZERO());

    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("OwnershipTransferStarted"));
    indexed_keys.append_serde(previous_owner);
    indexed_keys.append_serde(new_owner);
    test_utils::assert_indexed_keys(event, indexed_keys.span());
}
