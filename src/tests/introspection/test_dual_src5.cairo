use array::ArrayTrait;
use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::introspection::interface::ISRC5Dispatcher;
use openzeppelin::introspection::interface::ISRC5DispatcherTrait;
use openzeppelin::introspection::interface::ISRC5CamelDispatcher;
use openzeppelin::introspection::interface::ISRC5CamelDispatcherTrait;
use openzeppelin::introspection::dual_src5::DualCaseSRC5;
use openzeppelin::introspection::dual_src5::DualCaseSRC5Trait;
use openzeppelin::tests::mocks::src5_mocks::SnakeSRC5Mock;
use openzeppelin::tests::mocks::src5_mocks::CamelSRC5Mock;
use openzeppelin::tests::mocks::src5_mocks::SnakeSRC5PanicMock;
use openzeppelin::tests::mocks::src5_mocks::CamelSRC5PanicMock;
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::utils;

//
// Setup
//

fn setup_snake() -> DualCaseSRC5 {
    let mut calldata = array![];
    let target = utils::deploy(SnakeSRC5Mock::TEST_CLASS_HASH, calldata);
    DualCaseSRC5 { contract_address: target }
}

fn setup_camel() -> DualCaseSRC5 {
    let mut calldata = array![];
    let target = utils::deploy(CamelSRC5Mock::TEST_CLASS_HASH, calldata);
    DualCaseSRC5 { contract_address: target }
}

fn setup_non_src5() -> DualCaseSRC5 {
    let calldata = array![];
    let target = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, calldata);
    DualCaseSRC5 { contract_address: target }
}

fn setup_src5_panic() -> (DualCaseSRC5, DualCaseSRC5) {
    let snake_target = utils::deploy(SnakeSRC5PanicMock::TEST_CLASS_HASH, array![]);
    let camel_target = utils::deploy(CamelSRC5PanicMock::TEST_CLASS_HASH, array![]);
    (
        DualCaseSRC5 {
            contract_address: snake_target
            }, DualCaseSRC5 {
            contract_address: camel_target
        }
    )
}

//
// snake_case target
//

#[test]
#[available_gas(2000000)]
fn test_dual_supports_interface() {
    let dispatcher = setup_snake();
    assert(dispatcher.supports_interface(ISRC5_ID), 'Should support base interface');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', ))]
fn test_dual_no_supports_interface() {
    let dispatcher = setup_non_src5();
    dispatcher.supports_interface(ISRC5_ID);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_supports_interface_exists_and_panics() {
    let (dispatcher, _) = setup_src5_panic();
    dispatcher.supports_interface(ISRC5_ID);
}

//
// camelCase target
//

#[test]
#[available_gas(2000000)]
fn test_dual_supportsInterface() {
    let dispatcher = setup_camel();
    assert(dispatcher.supports_interface(ISRC5_ID), 'Should support base interface');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED', ))]
fn test_dual_supportsInterface_exists_and_panics() {
    let (_, dispatcher) = setup_src5_panic();
    dispatcher.supports_interface(ISRC5_ID);
}
