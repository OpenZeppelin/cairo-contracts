use openzeppelin::access::ownable::OwnableComponent::InternalTrait;
use openzeppelin::access::ownable::OwnableComponent::OwnershipTransferStarted;
use openzeppelin::access::ownable::interface::{IOwnableTwoStep, IOwnableTwoStepCamelOnly};
use openzeppelin::tests::mocks::ownable_mocks::DualCaseTwoStepOwnableMock;
use openzeppelin::tests::utils::constants::{ZERO, OWNER, OTHER, NEW_OWNER};
use openzeppelin::tests::utils;
use starknet::ContractAddress;
use starknet::storage::StorageMemberAccessTrait;
use starknet::testing;
use super::test_ownable::assert_event_ownership_transferred;

//
// Setup
//

fn STATE() -> DualCaseTwoStepOwnableMock::ContractState {
    DualCaseTwoStepOwnableMock::contract_state_for_testing()
}

fn setup() -> DualCaseTwoStepOwnableMock::ContractState {
    let mut state = STATE();
    state.ownable.initializer(OWNER());
    utils::drop_event(ZERO());
    state
}

//
// initializer
//

#[test]
#[available_gas(2000000)]
fn test_initializer_owner_pending_owner() {
    let mut state = STATE();
    assert(state.ownable.Ownable_owner.read() == ZERO(), 'Owner should be ZERO');
    assert(state.ownable.Ownable_pending_owner.read() == ZERO(), 'Pending owner should be ZERO');
    state.ownable.initializer(OWNER());

    assert_event_ownership_transferred(ZERO(), OWNER());

    assert(state.ownable.Ownable_owner.read() == OWNER(), 'Owner should be set');
    assert(state.ownable.Ownable_pending_owner.read() == ZERO(), 'Pending owner should be ZERO');
}

//
// _accept_ownership
//

#[test]
#[available_gas(2000000)]
fn test__accept_ownership() {
    let mut state = setup();
    state.ownable.Ownable_pending_owner.write(OTHER());

    state.ownable._accept_ownership();

    assert_event_ownership_transferred(OWNER(), OTHER());
    assert(state.ownable.owner() == OTHER(), 'Owner should be OTHER');
    assert(state.ownable.pending_owner() == ZERO(), 'Pending owner should be ZERO');
}

//
// _propose_owner
//

#[test]
#[available_gas(2000000)]
fn test__propose_owner() {
    let mut state = setup();

    state.ownable._propose_owner(OTHER());

    assert_event_ownership_transfer_started(OWNER(), OTHER());
    assert(state.ownable.owner() == OWNER(), 'Owner should be OWNER');
    assert(state.ownable.pending_owner() == OTHER(), 'Pending owner should be OTHER');
}

// transfer_ownership & transferOwnership

#[test]
#[available_gas(2000000)]
fn test_transfer_ownership() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.ownable.transfer_ownership(OTHER());

    assert_event_ownership_transfer_started(OWNER(), OTHER());
    assert(state.ownable.owner() == OWNER(), 'Owner should be OWNER');
    assert(state.ownable.pending_owner() == OTHER(), 'Pending owner should be OTHER');

    // Transferring to yet another owner while pending is set should work
    state.ownable.transfer_ownership(NEW_OWNER());

    assert_event_ownership_transfer_started(OWNER(), NEW_OWNER());
    assert(state.ownable.owner() == OWNER(), 'Owner should be OWNER');
    assert(state.ownable.pending_owner() == NEW_OWNER(), 'Pending should be NEW_OWNER');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('New owner is the zero address',))]
fn test_transfer_ownership_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.ownable.transfer_ownership(ZERO());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address',))]
fn test_transfer_ownership_from_zero() {
    let mut state = setup();
    state.ownable.transfer_ownership(OTHER());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_transfer_ownership_from_nonowner() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    state.ownable.transfer_ownership(OTHER());
}

#[test]
#[available_gas(2000000)]
fn test_transferOwnership() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.ownable.transferOwnership(OTHER());

    assert_event_ownership_transfer_started(OWNER(), OTHER());
    assert(state.ownable.owner() == OWNER(), 'Owner should be OWNER');
    assert(state.ownable.pending_owner() == OTHER(), 'Pending owner should be OTHER');

    // Transferring to yet another owner while pending is set should work
    state.ownable.transferOwnership(NEW_OWNER());

    assert_event_ownership_transfer_started(OWNER(), NEW_OWNER());
    assert(state.ownable.owner() == OWNER(), 'Owner should be OWNER');
    assert(state.ownable.pending_owner() == NEW_OWNER(), 'Pending should be NEW_OWNER');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('New owner is the zero address',))]
fn test_transferOwnership_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.ownable.transferOwnership(ZERO());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address',))]
fn test_transferOwnership_from_zero() {
    let mut state = setup();
    state.ownable.transferOwnership(OTHER());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_transferOwnership_from_nonowner() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    state.ownable.transferOwnership(OTHER());
}

//
// accept_ownership & acceptOwnership
//

#[test]
#[available_gas(2000000)]
fn test_accept_ownership() {
    let mut state = setup();
    state.ownable.Ownable_pending_owner.write(OTHER());
    testing::set_caller_address(OTHER());

    state.ownable.accept_ownership();

    assert_event_ownership_transferred(OWNER(), OTHER());
    assert(state.ownable.owner() == OTHER(), 'Owner should be OTHER');
    assert(state.ownable.pending_owner() == ZERO(), 'Pending owner should be ZERO');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the pending owner',))]
fn test_accept_ownership_from_nonpending() {
    let mut state = setup();
    state.ownable.Ownable_pending_owner.write(NEW_OWNER());
    testing::set_caller_address(OTHER());
    state.ownable.accept_ownership();
}

#[test]
#[available_gas(2000000)]
fn test_acceptOwnership() {
    let mut state = setup();
    state.ownable.Ownable_pending_owner.write(OTHER());
    testing::set_caller_address(OTHER());

    state.ownable.acceptOwnership();

    assert_event_ownership_transferred(OWNER(), OTHER());
    assert(state.ownable.owner() == OTHER(), 'Owner should be OTHER');
    assert(state.ownable.pending_owner() == ZERO(), 'Pending owner should be ZERO');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the pending owner',))]
fn test_acceptOwnership_from_nonpending() {
    let mut state = setup();
    state.ownable.Ownable_pending_owner.write(NEW_OWNER());
    testing::set_caller_address(OTHER());
    state.ownable.acceptOwnership();
}

//
// renounce_ownership & renounceOwnership
//

#[test]
#[available_gas(2000000)]
fn test_renounce_ownership() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.ownable.renounce_ownership();

    assert_event_ownership_transferred(OWNER(), ZERO());

    assert(state.ownable.owner() == ZERO(), 'Should renounce ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address',))]
fn test_renounce_ownership_from_zero_address() {
    let mut state = setup();
    state.ownable.renounce_ownership();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_renounce_ownership_from_nonowner() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    state.ownable.renounce_ownership();
}

#[test]
#[available_gas(2000000)]
fn test_renounceOwnership() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.ownable.renounceOwnership();

    assert_event_ownership_transferred(OWNER(), ZERO());

    assert(state.ownable.owner() == ZERO(), 'Should renounce ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address',))]
fn test_renounceOwnership_from_zero_address() {
    let mut state = setup();
    state.ownable.renounceOwnership();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_renounceOwnership_from_nonowner() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    state.ownable.renounceOwnership();
}

#[test]
#[available_gas(2000000)]
fn test_full_two_step_transfer() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.ownable.transfer_ownership(OTHER());

    assert_event_ownership_transfer_started(OWNER(), OTHER());
    assert(state.ownable.owner() == OWNER(), 'Owner should be OWNER');
    assert(state.ownable.pending_owner() == OTHER(), 'Pending owner should be OTHER');

    testing::set_caller_address(OTHER());
    state.ownable.accept_ownership();

    assert_event_ownership_transferred(OWNER(), OTHER());
    assert(state.ownable.owner() == OTHER(), 'Owner should be OTHER');
    assert(state.ownable.pending_owner() == ZERO(), 'Pending owner should be ZERO');
}

#[test]
#[available_gas(2000000)]
fn test_pending_accept_after_owner_renounce() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.ownable.transfer_ownership(OTHER());

    assert_event_ownership_transfer_started(OWNER(), OTHER());
    assert(state.ownable.owner() == OWNER(), 'Owner should be OWNER');
    assert(state.ownable.pending_owner() == OTHER(), 'Pending owner should be OTHER');

    state.ownable.renounce_ownership();

    assert_event_ownership_transferred(OWNER(), ZERO());
    assert(state.ownable.owner() == ZERO(), 'Should renounce ownership');

    testing::set_caller_address(OTHER());
    state.ownable.accept_ownership();

    assert_event_ownership_transferred(ZERO(), OTHER());
    assert(state.ownable.owner() == OTHER(), 'Owner should be OTHER');
    assert(state.ownable.pending_owner() == ZERO(), 'Pending owner should be ZERO');
}

//
// Helpers
//

fn assert_event_ownership_transfer_started(
    previous_owner: ContractAddress, new_owner: ContractAddress
) {
    let event = utils::pop_log::<OwnershipTransferStarted>(ZERO()).unwrap();
    assert(event.previous_owner == previous_owner, 'Invalid `previous_owner`');
    assert(event.new_owner == new_owner, 'Invalid `new_owner`');
    utils::assert_no_events_left(ZERO());
}
