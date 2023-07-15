use openzeppelin::access::ownable::Ownable;
use openzeppelin::access::ownable::Ownable::StorageTrait;
use openzeppelin::access::ownable::interface::IOwnableDispatcher;
use openzeppelin::access::ownable::interface::IOwnableDispatcherTrait;
use openzeppelin::access::ownable::interface::IOwnableCamelDispatcher;
use openzeppelin::access::ownable::interface::IOwnableCamelDispatcherTrait;
use openzeppelin::tests::mocks::dual_ownable_mocks::SnakeOwnableMock;
use openzeppelin::tests::mocks::dual_ownable_mocks::CamelOwnableMock;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::tests::utils;

use array::ArrayTrait;
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

fn internal_state() -> Ownable::ContractState {
    Ownable::contract_state_for_testing()
}

fn setup() -> Ownable::ContractState {
    let mut ownable = internal_state();
    ownable.initializer(OWNER());
    ownable
}

fn deploy_mock() -> IOwnableDispatcher {
    let mut calldata = ArrayTrait::new();
    calldata.append_serde(OWNER());
    let address = utils::deploy(SnakeOwnableMock::TEST_CLASS_HASH, calldata);
    IOwnableDispatcher { contract_address: address }
}

fn deploy_mock_camel() -> IOwnableCamelDispatcher {
    let mut calldata = ArrayTrait::new();
    calldata.append_serde(OWNER());
    let address = utils::deploy(CamelOwnableMock::TEST_CLASS_HASH, calldata);
    IOwnableCamelDispatcher { contract_address: address }
}

//
// initializer
//

#[test]
#[available_gas(2000000)]
fn test_initializer() {
    let mut ownable = internal_state();
    assert(ownable.owner().is_zero(), 'Should be zero');
    ownable.initializer(OWNER());
    assert(ownable.owner() == OWNER(), 'Owner should be set');
}

//
// assert_only_owner
//

#[test]
#[available_gas(2000000)]
fn test_assert_only_owner() {
    let mut ownable = setup();
    testing::set_caller_address(OWNER());
    ownable.assert_only_owner();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', ))]
fn test_assert_only_owner_when_not_owner() {
    let mut ownable = setup();
    testing::set_caller_address(OTHER());
    ownable.assert_only_owner();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', ))]
fn test_assert_only_owner_when_caller_zero() {
    let mut ownable = setup();
    ownable.assert_only_owner();
}

//
// _transfer_ownership
//

#[test]
#[available_gas(2000000)]
fn test__transfer_ownership() {
    let mut ownable = setup();
    testing::set_caller_address(OWNER());
    ownable._transfer_ownership(OTHER());
    assert(ownable.owner() == OTHER(), 'Owner should be OTHER');
}

//
// transfer_ownership & transferOwnership
//

#[test]
#[available_gas(2000000)]
fn test_transfer_ownership() {
    let ownable = deploy_mock();
    testing::set_contract_address(OWNER());
    ownable.transfer_ownership(OTHER());
    assert(ownable.owner() == OTHER(), 'Should transfer ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('New owner is the zero address', 'ENTRYPOINT_FAILED', ))]
fn test_transfer_ownership_to_zero() {
    let ownable = deploy_mock();
    testing::set_contract_address(OWNER());
    ownable.transfer_ownership(ZERO());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED', ))]
fn test_transfer_ownership_from_zero() {
    let ownable = deploy_mock();
    ownable.transfer_ownership(OTHER());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED', ))]
fn test_transfer_ownership_from_nonowner() {
    let ownable = deploy_mock();
    testing::set_contract_address(OTHER());
    ownable.transfer_ownership(OTHER());
}

#[test]
#[available_gas(2000000)]
fn test_transferOwnership() {
    let ownable = deploy_mock_camel();
    testing::set_contract_address(OWNER());
    ownable.transferOwnership(OTHER());
    assert(ownable.owner() == OTHER(), 'Should transfer ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('New owner is the zero address', 'ENTRYPOINT_FAILED', ))]
fn test_transferOwnership_to_zero() {
    let ownable = deploy_mock_camel();
    testing::set_contract_address(OWNER());
    ownable.transferOwnership(ZERO());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED', ))]
fn test_transferOwnership_from_zero() {
    let ownable = deploy_mock_camel();
    ownable.transferOwnership(OTHER());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED', ))]
fn test_transferOwnership_from_nonowner() {
    let ownable = deploy_mock_camel();
    testing::set_contract_address(OTHER());
    ownable.transferOwnership(OTHER());
}

//
// renounce_ownership & renounceOwnership
//

#[test]
#[available_gas(2000000)]
fn test_renounce_ownership() {
    let ownable = deploy_mock();
    testing::set_contract_address(OWNER());
    ownable.renounce_ownership();
    assert(ownable.owner() == ZERO(), 'Should renounce ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED', ))]
fn test_renounce_ownership_from_zero_address() {
    let ownable = deploy_mock();
    ownable.renounce_ownership();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED', ))]
fn test_renounce_ownership_from_nonowner() {
    let ownable = deploy_mock();
    testing::set_contract_address(OTHER());
    ownable.renounce_ownership();
}

#[test]
#[available_gas(2000000)]
fn test_renounceOwnership() {
    let ownable = deploy_mock_camel();
    testing::set_contract_address(OWNER());
    ownable.renounceOwnership();
    assert(ownable.owner() == ZERO(), 'Should renounce ownership');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED', ))]
fn test_renounceOwnership_from_zero_address() {
    let ownable = deploy_mock_camel();
    ownable.renounceOwnership();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED', ))]
fn test_renounceOwnership_from_nonowner() {
    let ownable = deploy_mock_camel();
    testing::set_contract_address(OTHER());
    ownable.renounceOwnership();
}
