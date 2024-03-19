use openzeppelin::account::dual_eth_account::{DualCaseEthAccountABI, DualCaseEthAccount};
use openzeppelin::account::interface::{EthAccountABIDispatcherTrait, EthAccountABIDispatcher};
use openzeppelin::account::utils::secp256k1::{
    DebugSecp256k1Point, Secp256k1PointPartialEq, Secp256k1PointSerde
};
use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::tests::account::test_eth_account::SIGNED_TX_DATA;
use openzeppelin::tests::mocks::eth_account_mocks::{
    CamelEthAccountPanicMock, CamelEthAccountMock, SnakeEthAccountMock, SnakeEthAccountPanicMock
};
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::utils::constants::{ETH_PUBKEY, NEW_ETH_PUBKEY};
use openzeppelin::tests::utils;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::eth_signature::Signature;
use starknet::testing;

//
// Setup
//

fn setup_snake() -> (DualCaseEthAccount, EthAccountABIDispatcher) {
    let mut calldata = array![];
    calldata.append_serde(ETH_PUBKEY());

    let target = utils::deploy(SnakeEthAccountMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseEthAccount { contract_address: target },
        EthAccountABIDispatcher { contract_address: target }
    )
}

fn setup_camel() -> (DualCaseEthAccount, EthAccountABIDispatcher) {
    let mut calldata = array![];
    calldata.append_serde(ETH_PUBKEY());

    let target = utils::deploy(CamelEthAccountMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseEthAccount { contract_address: target },
        EthAccountABIDispatcher { contract_address: target }
    )
}

fn setup_non_account() -> DualCaseEthAccount {
    let calldata = array![];
    let target = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, calldata);
    DualCaseEthAccount { contract_address: target }
}

fn setup_account_panic() -> (DualCaseEthAccount, DualCaseEthAccount) {
    let snake_target = utils::deploy(SnakeEthAccountPanicMock::TEST_CLASS_HASH, array![]);
    let camel_target = utils::deploy(CamelEthAccountPanicMock::TEST_CLASS_HASH, array![]);
    (
        DualCaseEthAccount { contract_address: snake_target },
        DualCaseEthAccount { contract_address: camel_target }
    )
}

//
// snake_case target
//

#[test]
fn test_dual_set_public_key() {
    let (snake_dispatcher, target) = setup_snake();

    testing::set_contract_address(snake_dispatcher.contract_address);

    let new_public_key = NEW_ETH_PUBKEY();
    snake_dispatcher.set_public_key(new_public_key);
    assert_eq!(target.get_public_key(), new_public_key);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_set_public_key() {
    let dispatcher = setup_non_account();
    dispatcher.set_public_key(NEW_ETH_PUBKEY());
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_set_public_key_exists_and_panics() {
    let (dispatcher, _) = setup_account_panic();
    dispatcher.set_public_key(NEW_ETH_PUBKEY());
}

#[test]
fn test_dual_get_public_key() {
    let (snake_dispatcher, _) = setup_snake();
    assert_eq!(snake_dispatcher.get_public_key(), ETH_PUBKEY());
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_get_public_key() {
    let dispatcher = setup_non_account();
    dispatcher.get_public_key();
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_get_public_key_exists_and_panics() {
    let (dispatcher, _) = setup_account_panic();
    dispatcher.get_public_key();
}

#[test]
fn test_dual_is_valid_signature() {
    let (snake_dispatcher, target) = setup_snake();

    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;
    let mut serialized_signature = array![];
    data.signature.serialize(ref serialized_signature);

    testing::set_contract_address(snake_dispatcher.contract_address);
    target.set_public_key(data.public_key);

    let is_valid = snake_dispatcher.is_valid_signature(hash, serialized_signature);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_is_valid_signature() {
    let hash = 0x0;
    let signature = array![];

    let dispatcher = setup_non_account();
    dispatcher.is_valid_signature(hash, signature);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_is_valid_signature_exists_and_panics() {
    let hash = 0x0;
    let signature = array![];

    let (dispatcher, _) = setup_account_panic();
    dispatcher.is_valid_signature(hash, signature);
}

#[test]
fn test_dual_supports_interface() {
    let (snake_dispatcher, _) = setup_snake();
    assert!(snake_dispatcher.supports_interface(ISRC5_ID), "Should implement ISRC5");
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_supports_interface() {
    let dispatcher = setup_non_account();
    dispatcher.supports_interface(ISRC5_ID);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_supports_interface_exists_and_panics() {
    let (dispatcher, _) = setup_account_panic();
    dispatcher.supports_interface(ISRC5_ID);
}

//
// camelCase target
//

#[test]
fn test_dual_setPublicKey() {
    let (camel_dispatcher, target) = setup_camel();
    let new_public_key = NEW_ETH_PUBKEY();

    testing::set_contract_address(camel_dispatcher.contract_address);

    camel_dispatcher.set_public_key(new_public_key);
    assert_eq!(target.getPublicKey(), new_public_key);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_setPublicKey_exists_and_panics() {
    let (_, dispatcher) = setup_account_panic();
    dispatcher.set_public_key(NEW_ETH_PUBKEY());
}

#[test]
fn test_dual_getPublicKey() {
    let (camel_dispatcher, _) = setup_camel();
    assert_eq!(camel_dispatcher.get_public_key(), ETH_PUBKEY());
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_getPublicKey_exists_and_panics() {
    let (_, dispatcher) = setup_account_panic();
    dispatcher.get_public_key();
}

#[test]
fn test_dual_isValidSignature() {
    let (camel_dispatcher, target) = setup_camel();

    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;
    let mut serialized_signature = array![];
    data.signature.serialize(ref serialized_signature);

    testing::set_contract_address(camel_dispatcher.contract_address);
    target.setPublicKey(data.public_key);

    let is_valid = camel_dispatcher.is_valid_signature(hash, serialized_signature);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_isValidSignature_exists_and_panics() {
    let hash = 0x0;
    let signature = array![];

    let (_, dispatcher) = setup_account_panic();
    dispatcher.is_valid_signature(hash, signature);
}
