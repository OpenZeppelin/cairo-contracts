use openzeppelin::access::ownable::Ownable;
use openzeppelin::access::ownable::Ownable::InternalImpl;
//use openzeppelin::access::ownable::OwnableCamelOnly;

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
    InternalImpl::initializer(ref state, OWNER());
    state
}

//fn setup_camel() -> OwnableCamel::ContractState {
//    let mut camel_state = OwnableCamel::contract_state_for_testing();
//    OwnableCamel::InternalImpl::initializer(ref camel_state, OWNER());
//    camel_state
//}

//
// initializer
//

#[test]
#[available_gas(2000000)]
fn test_initializer() {
    let mut state = STATE();
    assert(InternalImpl::owner(@state).is_zero(), 'Should be zero');
    InternalImpl::initializer(ref state, OWNER());
    assert(InternalImpl::owner(@state) == OWNER(), 'Owner should be set');
}

//
// assert_only_owner
//

#[test]
#[available_gas(2000000)]
fn test_assert_only_owner() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    InternalImpl::assert_only_owner(@state);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_assert_only_owner_when_not_owner() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    InternalImpl::assert_only_owner(@state);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_assert_only_owner_when_caller_zero() {
    let mut state = setup();
    InternalImpl::assert_only_owner(@state);
}

//
// _transfer_ownership
//

#[test]
#[available_gas(2000000)]
fn test__transfer_ownership() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    InternalImpl::_transfer_ownership(ref state, OTHER());
    assert(InternalImpl::owner(@state) == OTHER(), 'Owner should be OTHER');
}

//
// transfer_ownership & transferOwnership
//

#[test]
#[available_gas(2000000)]
fn test_transfer_ownership() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    Ownable::OwnableImpl::transfer_ownership(ref state, OTHER());
    assert(Ownable::OwnableImpl::owner(@state) == OTHER(), 'Should transfer ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('New owner is the zero address', ))]
fn test_transfer_ownership_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    Ownable::OwnableImpl::transfer_ownership(ref state, ZERO());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_transfer_ownership_from_zero() {
    let mut state = setup();
    Ownable::OwnableImpl::transfer_ownership(ref state, OTHER());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_transfer_ownership_from_nonowner() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    Ownable::OwnableImpl::transfer_ownership(ref state, OTHER());
}

#[test]
#[available_gas(2000000)]
fn test_transferOwnership() {
    let mut state = setup_camel();
    testing::set_caller_address(OWNER());
    OwnableCamel::OwnableCamelImpl::transferOwnership(ref state, OTHER());
    assert(OwnableCamel::OwnableCamelImpl::owner(@state) == OTHER(), 'Should transfer ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('New owner is the zero address', ))]
fn test_transferOwnership_to_zero() {
    let mut state = setup_camel();
    testing::set_caller_address(OWNER());
    OwnableCamel::OwnableCamelImpl::transferOwnership(ref state, ZERO());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_transferOwnership_from_zero() {
    let mut state = setup_camel();
    OwnableCamel::OwnableCamelImpl::transferOwnership(ref state, OTHER());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_transferOwnership_from_nonowner() {
    let mut state = setup_camel();
    testing::set_caller_address(OTHER());
    OwnableCamel::OwnableCamelImpl::transferOwnership(ref state, OTHER());
}

//
// renounce_ownership & renounceOwnership
//

#[test]
#[available_gas(2000000)]
fn test_renounce_ownership() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    Ownable::OwnableImpl::renounce_ownership(ref state);
    assert(Ownable::OwnableImpl::owner(@state) == ZERO(), 'Should renounce ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_renounce_ownership_from_zero_address() {
    let mut state = setup();
    Ownable::OwnableImpl::renounce_ownership(ref state);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_renounce_ownership_from_nonowner() {
    let mut state = setup();
    testing::set_caller_address(OTHER());
    Ownable::OwnableImpl::renounce_ownership(ref state);
}

#[test]
#[available_gas(2000000)]
fn test_renounceOwnership() {
    let mut state = setup_camel();
    testing::set_caller_address(OWNER());
    OwnableCamel::OwnableCamelImpl::renounceOwnership(ref state);
    assert(OwnableCamel::OwnableCamelImpl::owner(@state) == ZERO(), 'Should renounce ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_renounceOwnership_from_zero_address() {
    let mut state = setup_camel();
    OwnableCamel::OwnableCamelImpl::renounceOwnership(ref state);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_renounceOwnership_from_nonowner() {
    let mut state = setup_camel();
    testing::set_caller_address(OTHER());
    OwnableCamel::OwnableCamelImpl::renounceOwnership(ref state);
}
