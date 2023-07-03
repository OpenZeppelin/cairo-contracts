use openzeppelin::access::ownable::Ownable;

use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing;
use zeroable::Zeroable;

fn ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

fn OWNER() -> ContractAddress {
    contract_address_const::<1>()
}

fn OTHER() -> ContractAddress {
    contract_address_const::<2>()
}

fn setup() {
    testing::set_caller_address(OWNER());
    Ownable::initializer();
}

///
/// initializer
///

#[test]
#[available_gas(2000000)]
fn test_initializer() {
    assert(Ownable::owner().is_zero(), 'Should be zero');
    setup();
    assert(Ownable::owner() == OWNER(), 'Owner should be set');
}

///
/// transfer_ownership & transferOwnership
///

#[test]
#[available_gas(2000000)]
fn test_transfer_ownership() {
    setup();
    Ownable::transfer_ownership(OTHER());
    assert(Ownable::owner() == OTHER(), 'Should transfer ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('New owner is the zero address', ))]
fn test_transfer_ownership_to_zero() {
    setup();
    Ownable::transfer_ownership(ZERO());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_transfer_ownership_from_zero() {
    Ownable::transfer_ownership(OTHER());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_transfer_ownership_from_nonowner() {
    setup();
    testing::set_caller_address(OTHER());
    Ownable::transfer_ownership(OTHER());
}

#[test]
#[available_gas(2000000)]
fn test_transferOwnership() {
    setup();
    Ownable::transferOwnership(OTHER());
    assert(Ownable::owner() == OTHER(), 'Should transfer ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('New owner is the zero address', ))]
fn test_transferOwnership_to_zero() {
    setup();
    Ownable::transferOwnership(ZERO());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_transferOwnership_from_zero() {
    Ownable::transferOwnership(OTHER());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_transferOwnership_from_nonowner() {
    setup();
    testing::set_caller_address(OTHER());
    Ownable::transferOwnership(OTHER());
}

///
/// renounce_ownership & renounceOwnership
///

#[test]
#[available_gas(2000000)]
fn test_renounce_ownership() {
    setup();
    Ownable::renounce_ownership();
    assert(Ownable::owner() == ZERO(), 'Should renounce ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_renounce_ownership_from_zero_address() {
    setup();
    testing::set_caller_address(ZERO());
    Ownable::renounce_ownership();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_renounce_ownership_from_nonowner() {
    setup();
    testing::set_caller_address(OTHER());
    Ownable::renounce_ownership();
}

#[test]
#[available_gas(2000000)]
fn test_renounceOwnership() {
    setup();
    Ownable::renounceOwnership();
    assert(Ownable::owner() == ZERO(), 'Should renounce ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_renounceOwnership_from_zero_address() {
    setup();
    testing::set_caller_address(ZERO());
    Ownable::renounceOwnership();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_renounceOwnership_from_nonowner() {
    setup();
    testing::set_caller_address(OTHER());
    Ownable::renounceOwnership();
}

