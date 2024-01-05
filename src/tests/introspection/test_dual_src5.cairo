use openzeppelin::introspection::dual_src5::DualCaseSRC5;
use openzeppelin::introspection::dual_src5::DualCaseSRC5Trait;
use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::mocks::src5_mocks::CamelSRC5Mock;
use openzeppelin::tests::mocks::src5_mocks::CamelSRC5PanicMock;
use openzeppelin::tests::mocks::src5_mocks::SnakeSRC5Mock;
use openzeppelin::tests::mocks::src5_mocks::SnakeSRC5PanicMock;
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
        DualCaseSRC5 { contract_address: snake_target },
        DualCaseSRC5 { contract_address: camel_target }
    )
}

//
// snake_case target
//

#[test]
fn test_dual_supports_interface() {
    let dispatcher = setup_snake();
    let supported = dispatcher.supports_interface(ISRC5_ID);
    assert!(supported, "Should implement ISRC5");
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_supports_interface() {
    let dispatcher = setup_non_src5();
    dispatcher.supports_interface(ISRC5_ID);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_supports_interface_exists_and_panics() {
    let (dispatcher, _) = setup_src5_panic();
    dispatcher.supports_interface(ISRC5_ID);
}

//
// camelCase target
//

#[test]
fn test_dual_supportsInterface() {
    let dispatcher = setup_camel();
    let supported = dispatcher.supports_interface(ISRC5_ID);
    assert!(supported, "Should implement ISRC5");
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_supportsInterface_exists_and_panics() {
    let (_, dispatcher) = setup_src5_panic();
    dispatcher.supports_interface(ISRC5_ID);
}
