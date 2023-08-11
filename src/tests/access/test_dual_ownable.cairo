use openzeppelin::access::ownable::dual_ownable::DualCaseOwnable;
use openzeppelin::access::ownable::dual_ownable::DualCaseOwnableTrait;
use openzeppelin::access::ownable::interface::IOwnableCamelOnlyDispatcher;
use openzeppelin::access::ownable::interface::IOwnableCamelOnlyDispatcherTrait;
use openzeppelin::access::ownable::interface::IOwnableDispatcher;
use openzeppelin::access::ownable::interface::IOwnableDispatcherTrait;
use openzeppelin::tests::mocks::dual_ownable_mocks::CamelOwnableMock;
use openzeppelin::tests::mocks::dual_ownable_mocks::CamelOwnablePanicMock;
use openzeppelin::tests::mocks::dual_ownable_mocks::SnakeOwnableMock;
use openzeppelin::tests::mocks::dual_ownable_mocks::SnakeOwnablePanicMock;
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::utils;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing::set_caller_address;
use starknet::testing::set_contract_address;
use zeroable::Zeroable;

//
// Constants
//

fn OWNER() -> ContractAddress {
    contract_address_const::<10>()
}

fn NEW_OWNER() -> ContractAddress {
    contract_address_const::<20>()
}

//
// Setup
//

fn setup_snake() -> (DualCaseOwnable, IOwnableDispatcher) {
    let mut calldata = ArrayTrait::new();
    calldata.append_serde(OWNER());
    let target = utils::deploy(SnakeOwnableMock::TEST_CLASS_HASH, calldata);
    (DualCaseOwnable { contract_address: target }, IOwnableDispatcher { contract_address: target })
}

fn setup_camel() -> (DualCaseOwnable, IOwnableCamelOnlyDispatcher) {
    let mut calldata = ArrayTrait::new();
    calldata.append_serde(OWNER());
    let target = utils::deploy(CamelOwnableMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseOwnable {
            contract_address: target
            }, IOwnableCamelOnlyDispatcher {
            contract_address: target
        }
    )
}

fn setup_non_ownable() -> DualCaseOwnable {
    let calldata = ArrayTrait::new();
    let target = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, calldata);
    DualCaseOwnable { contract_address: target }
}

fn setup_ownable_panic() -> (DualCaseOwnable, DualCaseOwnable) {
    let snake_target = utils::deploy(SnakeOwnablePanicMock::TEST_CLASS_HASH, ArrayTrait::new());
    let camel_target = utils::deploy(CamelOwnablePanicMock::TEST_CLASS_HASH, ArrayTrait::new());
    (
        DualCaseOwnable {
            contract_address: snake_target
            }, DualCaseOwnable {
            contract_address: camel_target
        }
    )
}

//
// Case agnostic methods
//

#[test]
#[available_gas(2000000)]
fn test_dual_owner() {
    let (snake_dispatcher, _) = setup_snake();
    let (camel_dispatcher, _) = setup_camel();
    assert(snake_dispatcher.owner() == OWNER(), 'Should return OWNER');
    assert(camel_dispatcher.owner() == OWNER(), 'Should return OWNER');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_owner() {
    let dispatcher = setup_non_ownable();
    dispatcher.owner();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_owner_exists_and_panics() {
    let (dispatcher, _) = setup_ownable_panic();
    dispatcher.owner();
}

//
// snake_case target
//

#[test]
#[available_gas(2000000)]
fn test_dual_transfer_ownership() {
    let (dispatcher, target) = setup_snake();
    set_contract_address(OWNER());
    dispatcher.transfer_ownership(NEW_OWNER());
    assert(target.owner() == NEW_OWNER(), 'Should be new owner');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_transfer_ownership() {
    let dispatcher = setup_non_ownable();
    dispatcher.transfer_ownership(NEW_OWNER());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_transfer_ownership_exists_and_panics() {
    let (dispatcher, _) = setup_ownable_panic();
    dispatcher.transfer_ownership(NEW_OWNER());
}

#[test]
#[available_gas(2000000)]
fn test_dual_renounce_ownership() {
    let (dispatcher, target) = setup_snake();
    set_contract_address(OWNER());
    dispatcher.renounce_ownership();
    assert(target.owner().is_zero(), 'Should be zero');
}


#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_renounce_ownership() {
    let dispatcher = setup_non_ownable();
    dispatcher.renounce_ownership();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_renounce_ownership_exists_and_panics() {
    let (dispatcher, _) = setup_ownable_panic();
    dispatcher.renounce_ownership();
}

//
// camelCase target
//

#[test]
#[available_gas(2000000)]
fn test_dual_transferOwnership() {
    let (dispatcher, _) = setup_camel();
    set_contract_address(OWNER());
    dispatcher.transfer_ownership(NEW_OWNER());
    assert(dispatcher.owner() == NEW_OWNER(), 'Should be new owner');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_transferOwnership_exists_and_panics() {
    let (_, dispatcher) = setup_ownable_panic();
    dispatcher.transfer_ownership(NEW_OWNER());
}

#[test]
#[available_gas(2000000)]
fn test_dual_renounceOwnership() {
    let (dispatcher, _) = setup_camel();
    set_contract_address(OWNER());
    dispatcher.renounce_ownership();
    assert(dispatcher.owner().is_zero(), 'Should be zero');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_renounceOwnership_exists_and_panics() {
    let (_, dispatcher) = setup_ownable_panic();
    dispatcher.renounce_ownership();
}

