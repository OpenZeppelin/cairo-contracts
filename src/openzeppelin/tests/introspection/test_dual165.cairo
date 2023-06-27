use array::ArrayTrait;
use openzeppelin::introspection::dual165::DualCaseERC165;
use openzeppelin::introspection::dual165::DualCaseERC165Trait;
use openzeppelin::introspection::interface::IERC165_ID;
use openzeppelin::introspection::interface::IERC165Dispatcher;
use openzeppelin::introspection::interface::IERC165DispatcherTrait;
use openzeppelin::introspection::interface::IERC165CamelDispatcher;
use openzeppelin::introspection::interface::IERC165CamelDispatcherTrait;
use openzeppelin::tests::mocks::dual165_mocks::CamelERC165Mock;
use openzeppelin::tests::mocks::dual165_mocks::CamelERC165PanicMock;
use openzeppelin::tests::mocks::dual165_mocks::SnakeERC165Mock;
use openzeppelin::tests::mocks::dual165_mocks::SnakeERC165PanicMock;
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::utils;

const OTHER_ID: u32 = 0x12345678_u32;

///
/// Setup
///

fn setup_snake() -> (DualCaseERC165, IERC165Dispatcher) {
    let mut calldata = ArrayTrait::new();
    let target = utils::deploy(SnakeERC165Mock::TEST_CLASS_HASH, calldata);
    (DualCaseERC165 { contract_address: target }, IERC165Dispatcher { contract_address: target })
}

fn setup_camel() -> (DualCaseERC165, IERC165CamelDispatcher) {
    let mut calldata = ArrayTrait::new();
    let target = utils::deploy(CamelERC165Mock::TEST_CLASS_HASH, calldata);
    (
        DualCaseERC165 {
            contract_address: target
            }, IERC165CamelDispatcher {
            contract_address: target
        }
    )
}

fn setup_non_erc165() -> DualCaseERC165 {
    let calldata = ArrayTrait::new();
    let target = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, calldata);
    DualCaseERC165 { contract_address: target }
}

fn setup_erc165_panic() -> (DualCaseERC165, DualCaseERC165) {
    let snake_target = utils::deploy(SnakeERC165PanicMock::TEST_CLASS_HASH, ArrayTrait::new());
    let camel_target = utils::deploy(CamelERC165PanicMock::TEST_CLASS_HASH, ArrayTrait::new());
    (
        DualCaseERC165 {
            contract_address: snake_target
            }, DualCaseERC165 {
            contract_address: camel_target
        }
    )
}

///
/// snake_case target
///

#[test]
#[available_gas(2000000)]
fn test_dual_supports_interface() {
    let (dispatcher, _) = setup_snake();
    assert(dispatcher.supports_interface(IERC165_ID), 'Should support interface');
    assert(!dispatcher.supports_interface(OTHER_ID), 'Should not support interface');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_supports_interfacef() {
    let dispatcher = setup_non_erc165();
    dispatcher.supports_interface(IERC165_ID);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_supports_interface_exists_and_panics() {
    let (dispatcher, _) = setup_erc165_panic();
    dispatcher.supports_interface(IERC165_ID);
}

///
/// camelCase target
///

#[test]
#[available_gas(2000000)]
fn test_dual_supports_interface() {
    let (dispatcher, _) = setup_camel();
    assert(dispatcher.supports_interface(IERC165_ID), 'Should support interface');
    assert(!dispatcher.supports_interface(OTHER_ID), 'Should not support interface');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_supports_interface_exists_and_panics() {
    let (_, dispatcher) = setup_erc165_panic();
    dispatcher.supports_interface(IERC165_ID);
}
