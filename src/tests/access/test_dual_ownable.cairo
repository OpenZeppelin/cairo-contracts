use openzeppelin::access::ownable::dual_ownable::DualCaseOwnable;
use openzeppelin::access::ownable::dual_ownable::DualCaseOwnableTrait;
use openzeppelin::access::ownable::interface::IOwnableCamelOnlyDispatcher;
use openzeppelin::access::ownable::interface::IOwnableDispatcher;
use openzeppelin::access::ownable::interface::IOwnableDispatcherTrait;
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::mocks::ownable_mocks::{
    CamelOwnableMock, CamelOwnablePanicMock, SnakeOwnableMock, SnakeOwnablePanicMock
};
use openzeppelin::tests::utils::constants::{OWNER, NEW_OWNER};
use openzeppelin::tests::utils::debug::DebugContractAddress;
use openzeppelin::tests::utils;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::testing::set_contract_address;

//
// Setup
//

fn setup_snake() -> (DualCaseOwnable, IOwnableDispatcher) {
    let mut calldata = array![];
    calldata.append_serde(OWNER());
    let target = utils::deploy(SnakeOwnableMock::TEST_CLASS_HASH, calldata);
    (DualCaseOwnable { contract_address: target }, IOwnableDispatcher { contract_address: target })
}

fn setup_camel() -> (DualCaseOwnable, IOwnableCamelOnlyDispatcher) {
    let mut calldata = array![];
    calldata.append_serde(OWNER());
    let target = utils::deploy(CamelOwnableMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseOwnable { contract_address: target },
        IOwnableCamelOnlyDispatcher { contract_address: target }
    )
}

fn setup_non_ownable() -> DualCaseOwnable {
    let calldata = array![];
    let target = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, calldata);
    DualCaseOwnable { contract_address: target }
}

fn setup_ownable_panic() -> (DualCaseOwnable, DualCaseOwnable) {
    let snake_target = utils::deploy(SnakeOwnablePanicMock::TEST_CLASS_HASH, array![]);
    let camel_target = utils::deploy(CamelOwnablePanicMock::TEST_CLASS_HASH, array![]);
    (
        DualCaseOwnable { contract_address: snake_target },
        DualCaseOwnable { contract_address: camel_target }
    )
}

//
// Case agnostic methods
//

#[test]
fn test_dual_owner() {
    let (snake_dispatcher, _) = setup_snake();
    let (camel_dispatcher, _) = setup_camel();

    let snake_owner = snake_dispatcher.owner();
    assert_eq!(snake_owner, OWNER());

    let camel_owner = camel_dispatcher.owner();
    assert_eq!(camel_owner, OWNER());
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_owner() {
    let dispatcher = setup_non_ownable();
    dispatcher.owner();
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_owner_exists_and_panics() {
    let (dispatcher, _) = setup_ownable_panic();
    dispatcher.owner();
}

//
// snake_case target
//

#[test]
fn test_dual_transfer_ownership() {
    let (dispatcher, target) = setup_snake();
    set_contract_address(OWNER());
    dispatcher.transfer_ownership(NEW_OWNER());

    let current_owner = target.owner();
    assert_eq!(current_owner, NEW_OWNER());
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_transfer_ownership() {
    let dispatcher = setup_non_ownable();
    dispatcher.transfer_ownership(NEW_OWNER());
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_transfer_ownership_exists_and_panics() {
    let (dispatcher, _) = setup_ownable_panic();
    dispatcher.transfer_ownership(NEW_OWNER());
}

#[test]
fn test_dual_renounce_ownership() {
    let (dispatcher, target) = setup_snake();
    set_contract_address(OWNER());
    dispatcher.renounce_ownership();

    let current_owner = target.owner();
    assert!(current_owner.is_zero());
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_renounce_ownership() {
    let dispatcher = setup_non_ownable();
    dispatcher.renounce_ownership();
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_renounce_ownership_exists_and_panics() {
    let (dispatcher, _) = setup_ownable_panic();
    dispatcher.renounce_ownership();
}

//
// camelCase target
//

#[test]
fn test_dual_transferOwnership() {
    let (dispatcher, _) = setup_camel();
    set_contract_address(OWNER());
    dispatcher.transfer_ownership(NEW_OWNER());

    let current_owner = dispatcher.owner();
    assert_eq!(current_owner, NEW_OWNER());
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_transferOwnership_exists_and_panics() {
    let (_, dispatcher) = setup_ownable_panic();
    dispatcher.transfer_ownership(NEW_OWNER());
}

#[test]
fn test_dual_renounceOwnership() {
    let (dispatcher, _) = setup_camel();
    set_contract_address(OWNER());
    dispatcher.renounce_ownership();

    let current_owner = dispatcher.owner();
    assert!(current_owner.is_zero());
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_renounceOwnership_exists_and_panics() {
    let (_, dispatcher) = setup_ownable_panic();
    dispatcher.renounce_ownership();
}

