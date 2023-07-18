use openzeppelin::access::ownable::Ownable;
use openzeppelin::access::ownable::OwnableCamel;

use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing;
use zeroable::Zeroable;

fn ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

fn OWNER() -> ContractAddress {
    contract_address_const::<10>()
}

fn OTHER() -> ContractAddress {
    contract_address_const::<20>()
}

//
// Setup
//

fn STATE() -> Ownable::ContractState {
    Ownable::contract_state_for_testing()
}

fn setup() -> Ownable::ContractState {
    let mut state = STATE();
    Ownable::StorageTrait::initializer(ref state, OWNER());
    state
}

fn setup_camel() -> OwnableCamel::ContractState {
    let mut camel_state = OwnableCamel::contract_state_for_testing();
    OwnableCamel::StorageTrait::initializer(ref camel_state, OWNER());
    camel_state
}

//
// initializer
//

#[test]
#[available_gas(2000000)]
fn test_initializer() {
    let mut state = STATE();
    assert(Ownable::StorageTrait::owner(@state).is_zero(), 'Should be zero');
    Ownable::StorageTrait::initializer(ref state, OWNER());
    assert(Ownable::StorageTrait::owner(@state) == OWNER(), 'Owner should be set');
}

//
// assert_only_owner
//

#[test]
#[available_gas(2000000)]
fn test_assert_only_owner() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    Ownable::StorageTrait::assert_only_owner(@state);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_assert_only_owner_when_not_owner() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    Ownable::StorageTrait::assert_only_owner(@state);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_assert_only_owner_when_caller_zero() {
    let mut state = setup();
    Ownable::StorageTrait::assert_only_owner(@state);
}

//
// _transfer_ownership
//

#[test]
#[available_gas(2000000)]
fn test__transfer_ownership() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    Ownable::StorageTrait::_transfer_ownership(ref state, OTHER());
    assert(Ownable::StorageTrait::owner(@state) == OTHER(), 'Owner should be OTHER');
}

//
// transfer_ownership & transferOwnership
//

#[test]
#[available_gas(2000000)]
fn test_transfer_ownership() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    Ownable::IOwnableImpl::transfer_ownership(ref state, OTHER());
    assert(Ownable::IOwnableImpl::owner(@state) == OTHER(), 'Should transfer ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('New owner is the zero address', ))]
fn test_transfer_ownership_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    Ownable::IOwnableImpl::transfer_ownership(ref state, ZERO());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_transfer_ownership_from_zero() {
    let mut state = setup();
    Ownable::IOwnableImpl::transfer_ownership(ref state, OTHER());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_transfer_ownership_from_nonowner() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    Ownable::IOwnableImpl::transfer_ownership(ref state, OTHER());
}

#[test]
#[available_gas(2000000)]
fn test_transferOwnership() {
    let mut state = setup_camel();
    testing::set_caller_address(OWNER());
    OwnableCamel::IOwnableCamelImpl::transferOwnership(ref state, OTHER());
    assert(OwnableCamel::IOwnableCamelImpl::owner(@state) == OTHER(), 'Should transfer ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('New owner is the zero address', ))]
fn test_transferOwnership_to_zero() {
    let mut state = setup_camel();
    testing::set_caller_address(OWNER());
    OwnableCamel::IOwnableCamelImpl::transferOwnership(ref state, ZERO());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_transferOwnership_from_zero() {
    let mut state = setup_camel();
    OwnableCamel::IOwnableCamelImpl::transferOwnership(ref state, OTHER());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_transferOwnership_from_nonowner() {
    let mut state = setup_camel();
    testing::set_caller_address(OTHER());
    OwnableCamel::IOwnableCamelImpl::transferOwnership(ref state, OTHER());
}

//
// renounce_ownership & renounceOwnership
//

#[test]
#[available_gas(2000000)]
fn test_renounce_ownership() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    Ownable::IOwnableImpl::renounce_ownership(ref state);
    assert(Ownable::IOwnableImpl::owner(@state) == ZERO(), 'Should renounce ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_renounce_ownership_from_zero_address() {
    let mut state = setup();
    Ownable::IOwnableImpl::renounce_ownership(ref state);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_renounce_ownership_from_nonowner() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    Ownable::IOwnableImpl::renounce_ownership(ref state);
}

#[test]
#[available_gas(2000000)]
fn test_renounceOwnership() {
    let mut state = setup_camel();
    testing::set_caller_address(OWNER());
    OwnableCamel::IOwnableCamelImpl::renounceOwnership(ref state);
    assert(OwnableCamel::IOwnableCamelImpl::owner(@state) == ZERO(), 'Should renounce ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_renounceOwnership_from_zero_address() {
    let mut state = setup_camel();
    OwnableCamel::IOwnableCamelImpl::renounceOwnership(ref state);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_renounceOwnership_from_nonowner() {
    let mut state = setup_camel();
    testing::set_caller_address(OTHER());
    OwnableCamel::IOwnableCamelImpl::renounceOwnership(ref state);
}
