use openzeppelin::access::ownable::OwnableComponent::InternalTrait;
use openzeppelin::access::ownable::OwnableComponent::OwnershipTransferred;
use openzeppelin::access::ownable::interface::{IOwnable, IOwnableCamelOnly};
use openzeppelin::tests::mocks::ownable_mocks::DualCaseOwnableMock;
use openzeppelin::tests::utils::constants::{ZERO, OTHER, OWNER};
use openzeppelin::tests::utils;
use starknet::ContractAddress;
use starknet::storage::StorageMemberAccessTrait;
use starknet::testing;

//
// Setup
//

fn STATE() -> DualCaseOwnableMock::ContractState {
    DualCaseOwnableMock::contract_state_for_testing()
}

fn setup() -> DualCaseOwnableMock::ContractState {
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
fn test_initializer_owner() {
    let mut state = STATE();
    assert(state.ownable.Ownable_owner.read().is_zero(), 'Should be zero');
    state.ownable.initializer(OWNER());

    assert_event_ownership_transferred(ZERO(), OWNER());

    assert(state.ownable.Ownable_owner.read() == OWNER(), 'Owner should be set');
}

//
// assert_only_owner
//

#[test]
#[available_gas(2000000)]
fn test_assert_only_owner() {
    let state = setup();
    testing::set_caller_address(OWNER());
    state.ownable.assert_only_owner();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_assert_only_owner_when_not_owner() {
    let state = setup();
    testing::set_caller_address(OTHER());
    state.ownable.assert_only_owner();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address',))]
fn test_assert_only_owner_when_caller_zero() {
    let state = setup();
    state.ownable.assert_only_owner();
}

//
// _transfer_ownership
//

#[test]
#[available_gas(2000000)]
fn test__transfer_ownership() {
    let mut state = setup();
    state.ownable._transfer_ownership(OTHER());

    assert_event_ownership_transferred(OWNER(), OTHER());

    assert(state.ownable.Ownable_owner.read() == OTHER(), 'Owner should be OTHER');
}

//
// transfer_ownership & transferOwnership
//

#[test]
#[available_gas(2000000)]
fn test_transfer_ownership() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.ownable.transfer_ownership(OTHER());

    assert_event_ownership_transferred(OWNER(), OTHER());

    assert(state.ownable.owner() == OTHER(), 'Should transfer ownership');
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

    assert_event_ownership_transferred(OWNER(), OTHER());

    assert(state.ownable.owner() == OTHER(), 'Should transfer ownership');
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

//
// Helpers
//

fn assert_event_ownership_transferred(previous_owner: ContractAddress, new_owner: ContractAddress) {
    let event = utils::pop_log::<OwnershipTransferred>(ZERO()).unwrap();
    assert(event.previous_owner == previous_owner, 'Invalid `previous_owner`');
    assert(event.new_owner == new_owner, 'Invalid `new_owner`');
    utils::assert_no_events_left(ZERO());
}
