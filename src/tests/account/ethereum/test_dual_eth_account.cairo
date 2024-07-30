use openzeppelin::account::dual_eth_account::{DualCaseEthAccountABI, DualCaseEthAccount};
use openzeppelin::account::interface::{EthAccountABIDispatcherTrait, EthAccountABIDispatcher};
use openzeppelin::account::utils::secp256k1::{
    DebugSecp256k1Point, Secp256k1PointPartialEq, Secp256k1PointSerde
};
use openzeppelin::account::utils::signature::EthSignature;
use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::tests::utils::constants::secp256k1::{KEY_PAIR, KEY_PAIR_2};
use openzeppelin::tests::utils::constants::{TRANSACTION_HASH};
use openzeppelin::tests::utils::signing::{Secp256k1KeyPair, Secp256k1KeyPairExt};
use openzeppelin::tests::utils;
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::start_cheat_caller_address;

use super::common::get_accept_ownership_signature;

//
// Setup
//

fn setup_snake(key_pair: Secp256k1KeyPair) -> (DualCaseEthAccount, EthAccountABIDispatcher) {
    let mut calldata = array![];
    calldata.append_serde(key_pair.public_key);

    let contract_address = utils::declare_and_deploy("SnakeEthAccountMock", calldata);
    (DualCaseEthAccount { contract_address }, EthAccountABIDispatcher { contract_address })
}

fn setup_camel(key_pair: Secp256k1KeyPair) -> (DualCaseEthAccount, EthAccountABIDispatcher) {
    let mut calldata = array![];
    calldata.append_serde(key_pair.public_key);

    let contract_address = utils::declare_and_deploy("CamelEthAccountMock", calldata);
    (DualCaseEthAccount { contract_address }, EthAccountABIDispatcher { contract_address })
}

fn setup_non_account() -> DualCaseEthAccount {
    let calldata = array![];
    let contract_address = utils::declare_and_deploy("NonImplementingMock", calldata);
    DualCaseEthAccount { contract_address }
}

fn setup_account_panic() -> (DualCaseEthAccount, DualCaseEthAccount) {
    let snake_target = utils::declare_and_deploy("SnakeEthAccountPanicMock", array![]);
    let camel_target = utils::declare_and_deploy("CamelEthAccountPanicMock", array![]);
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
    let key_pair = KEY_PAIR();
    let (snake_dispatcher, target) = setup_snake(key_pair);
    let contract_address = snake_dispatcher.contract_address;

    start_cheat_caller_address(contract_address, contract_address);

    let key_pair = KEY_PAIR();
    let signature = get_accept_ownership_signature(contract_address, key_pair.public_key, key_pair);

    snake_dispatcher.set_public_key(key_pair.public_key, signature);
    assert_eq!(target.get_public_key(), key_pair.public_key);
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_set_public_key() {
    let dispatcher = setup_non_account();
    dispatcher.set_public_key(KEY_PAIR().public_key, array![].span());
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_set_public_key_exists_and_panics() {
    let (dispatcher, _) = setup_account_panic();
    dispatcher.set_public_key(KEY_PAIR().public_key, array![].span());
}

#[test]
fn test_dual_get_public_key() {
    let key_pair = KEY_PAIR();
    let (snake_dispatcher, _) = setup_snake(key_pair);
    assert_eq!(snake_dispatcher.get_public_key(), key_pair.public_key);
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_get_public_key() {
    let dispatcher = setup_non_account();
    dispatcher.get_public_key();
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_get_public_key_exists_and_panics() {
    let (dispatcher, _) = setup_account_panic();
    dispatcher.get_public_key();
}

#[test]
fn test_dual_is_valid_signature() {
    let key_pair = KEY_PAIR();
    let (snake_dispatcher, target) = setup_snake(key_pair);
    let contract_address = snake_dispatcher.contract_address;

    start_cheat_caller_address(contract_address, contract_address);
    let new_key_pair = KEY_PAIR_2();
    let signature = get_accept_ownership_signature(
        contract_address, key_pair.public_key, new_key_pair
    );

    target.set_public_key(new_key_pair.public_key, signature);
    let serialized_signature = new_key_pair.serialized_sign(TRANSACTION_HASH.into());

    let is_valid = snake_dispatcher.is_valid_signature(TRANSACTION_HASH, serialized_signature);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_is_valid_signature() {
    let hash = 0x0;
    let signature = array![];

    let dispatcher = setup_non_account();
    dispatcher.is_valid_signature(hash, signature);
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_is_valid_signature_exists_and_panics() {
    let hash = 0x0;
    let signature = array![];

    let (dispatcher, _) = setup_account_panic();
    dispatcher.is_valid_signature(hash, signature);
}

#[test]
fn test_dual_supports_interface() {
    let (snake_dispatcher, _) = setup_snake(KEY_PAIR());
    assert!(snake_dispatcher.supports_interface(ISRC5_ID), "Should implement ISRC5");
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_supports_interface() {
    let dispatcher = setup_non_account();
    dispatcher.supports_interface(ISRC5_ID);
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_supports_interface_exists_and_panics() {
    let (dispatcher, _) = setup_account_panic();
    dispatcher.supports_interface(ISRC5_ID);
}

//
// camelCase target
//

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
fn test_dual_setPublicKey() {
    let key_pair = KEY_PAIR();
    let (camel_dispatcher, target) = setup_camel(key_pair);
    let contract_address = camel_dispatcher.contract_address;

    start_cheat_caller_address(contract_address, contract_address);

    let new_key_pair = KEY_PAIR_2();
    let signature = get_accept_ownership_signature(
        contract_address, key_pair.public_key, new_key_pair
    );

    camel_dispatcher.set_public_key(key_pair.public_key, signature);
    assert_eq!(target.getPublicKey(), key_pair.public_key);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
#[should_panic(expected: ("Some error",))]
fn test_dual_setPublicKey_exists_and_panics() {
    let (_, dispatcher) = setup_account_panic();
    dispatcher.set_public_key(KEY_PAIR().public_key, array![].span());
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
fn test_dual_getPublicKey() {
    let key_pair = KEY_PAIR();
    let (camel_dispatcher, _) = setup_camel(key_pair);
    assert_eq!(camel_dispatcher.get_public_key(), key_pair.public_key);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
#[should_panic(expected: ("Some error",))]
fn test_dual_getPublicKey_exists_and_panics() {
    let (_, dispatcher) = setup_account_panic();
    dispatcher.get_public_key();
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
fn test_dual_isValidSignature() {
    let key_pair = KEY_PAIR();
    let (camel_dispatcher, target) = setup_camel(key_pair);
    let contract_address = camel_dispatcher.contract_address;

    start_cheat_caller_address(contract_address, contract_address);

    let new_key_pair = KEY_PAIR();
    let signature = get_accept_ownership_signature(
        contract_address, key_pair.public_key, new_key_pair
    );

    target.setPublicKey(new_key_pair.public_key, signature);
    let serialized_signature = new_key_pair.serialized_sign(TRANSACTION_HASH.into());

    let is_valid = camel_dispatcher.is_valid_signature(TRANSACTION_HASH, serialized_signature);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
#[should_panic(expected: ("Some error",))]
fn test_dual_isValidSignature_exists_and_panics() {
    let hash = 0x0;
    let signature = array![];

    let (_, dispatcher) = setup_account_panic();
    dispatcher.is_valid_signature(hash, signature);
}
