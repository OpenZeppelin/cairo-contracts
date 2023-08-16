use openzeppelin::access::ownable::Ownable::InternalImpl;
use openzeppelin::access::ownable::Ownable::OwnableCamelOnlyImpl;
use openzeppelin::access::ownable::Ownable::OwnableImpl;
use openzeppelin::access::ownable::Ownable::OwnershipTransferred;
use openzeppelin::access::ownable::Ownable::_owner::InternalContractStateTrait;
use openzeppelin::access::ownable::Ownable;
use openzeppelin::tests::utils::constants::{ZERO, OTHER, OWNER};
use openzeppelin::tests::utils;
use option::OptionTrait;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing;
use zeroable::Zeroable;

//
// Setup
//

fn STATE() -> Ownable::ContractState {
    Ownable::contract_state_for_testing()
}

fn setup() -> Ownable::ContractState {
    let mut state = STATE();
    InternalImpl::initializer(ref state, OWNER());
    utils::drop_event(ZERO());
    state
}

//
// initializer
//

#[test]
#[available_gas(2000000)]
fn test_initializer() {
    let mut state = STATE();
    assert(state._owner.read().is_zero(), 'Should be zero');
    InternalImpl::initializer(ref state, OWNER());

    assert_event_ownership_transferred(ZERO(), OWNER());

    assert(state._owner.read() == OWNER(), 'Owner should be set');
}

//
// assert_only_owner
//

#[test]
#[available_gas(2000000)]
fn test_assert_only_owner() {
    let state = setup();
    testing::set_caller_address(OWNER());
    InternalImpl::assert_only_owner(@state);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_assert_only_owner_when_not_owner() {
    let state = setup();
    testing::set_caller_address(OTHER());
    InternalImpl::assert_only_owner(@state);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_assert_only_owner_when_caller_zero() {
    let state = setup();
    InternalImpl::assert_only_owner(@state);
}

//
// _transfer_ownership
//

#[test]
#[available_gas(2000000)]
fn test__transfer_ownership() {
    let mut state = setup();
    InternalImpl::_transfer_ownership(ref state, OTHER());

    assert_event_ownership_transferred(OWNER(), OTHER());

    assert(state._owner.read() == OTHER(), 'Owner should be OTHER');
}

//
// transfer_ownership & transferOwnership
//

#[test]
#[available_gas(2000000)]
fn test_transfer_ownership() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    OwnableImpl::transfer_ownership(ref state, OTHER());

    assert_event_ownership_transferred(OWNER(), OTHER());

    assert(OwnableImpl::owner(@state) == OTHER(), 'Should transfer ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('New owner is the zero address', ))]
fn test_transfer_ownership_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    OwnableImpl::transfer_ownership(ref state, ZERO());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_transfer_ownership_from_zero() {
    let mut state = setup();
    OwnableImpl::transfer_ownership(ref state, OTHER());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_transfer_ownership_from_nonowner() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    OwnableImpl::transfer_ownership(ref state, OTHER());
}

#[test]
#[available_gas(2000000)]
fn test_transferOwnership() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    OwnableCamelOnlyImpl::transferOwnership(ref state, OTHER());

    assert_event_ownership_transferred(OWNER(), OTHER());

    assert(OwnableImpl::owner(@state) == OTHER(), 'Should transfer ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('New owner is the zero address', ))]
fn test_transferOwnership_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    OwnableCamelOnlyImpl::transferOwnership(ref state, ZERO());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_transferOwnership_from_zero() {
    let mut state = setup();
    OwnableCamelOnlyImpl::transferOwnership(ref state, OTHER());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_transferOwnership_from_nonowner() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    OwnableCamelOnlyImpl::transferOwnership(ref state, OTHER());
}

//
// renounce_ownership & renounceOwnership
//

#[test]
#[available_gas(2000000)]
fn test_renounce_ownership() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    OwnableImpl::renounce_ownership(ref state);

    assert_event_ownership_transferred(OWNER(), ZERO());

    assert(OwnableImpl::owner(@state) == ZERO(), 'Should renounce ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_renounce_ownership_from_zero_address() {
    let mut state = setup();
    OwnableImpl::renounce_ownership(ref state);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_renounce_ownership_from_nonowner() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    OwnableImpl::renounce_ownership(ref state);
}

#[test]
#[available_gas(2000000)]
fn test_renounceOwnership() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    OwnableCamelOnlyImpl::renounceOwnership(ref state);

    assert_event_ownership_transferred(OWNER(), ZERO());

    assert(OwnableImpl::owner(@state) == ZERO(), 'Should renounce ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_renounceOwnership_from_zero_address() {
    let mut state = setup();
    OwnableCamelOnlyImpl::renounceOwnership(ref state);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_renounceOwnership_from_nonowner() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    OwnableCamelOnlyImpl::renounceOwnership(ref state);
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
