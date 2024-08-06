use openzeppelin_account::dual_account::{DualCaseAccountABI, DualCaseAccount};
use openzeppelin_account::interface::{AccountABIDispatcherTrait, AccountABIDispatcher};
use openzeppelin_introspection::interface::ISRC5_ID;

use openzeppelin_test_common::account::{SIGNED_TX_DATA, get_accept_ownership_signature};
use openzeppelin_test_utils as utils;
use openzeppelin_test_utils::constants::TRANSACTION_HASH;
use openzeppelin_test_utils::constants::stark::{KEY_PAIR, KEY_PAIR_2};
use openzeppelin_test_utils::signing::{StarkKeyPair, StarkKeyPairExt};
use snforge_std::{declare, start_cheat_caller_address};

//
// Setup
//

fn setup_snake(key_pair: StarkKeyPair) -> (DualCaseAccount, AccountABIDispatcher) {
    let calldata = array![key_pair.public_key];
    let contract_address = utils::declare_and_deploy("SnakeAccountMock", calldata);
    (DualCaseAccount { contract_address }, AccountABIDispatcher { contract_address })
}

fn setup_camel(key_pair: StarkKeyPair) -> (DualCaseAccount, AccountABIDispatcher) {
    let calldata = array![key_pair.public_key];
    let contract_address = utils::declare_and_deploy("CamelAccountMock", calldata);
    (DualCaseAccount { contract_address }, AccountABIDispatcher { contract_address })
}

fn setup_non_account() -> DualCaseAccount {
    let calldata = array![];
    let contract_address = utils::declare_and_deploy("NonImplementingMock", calldata);
    DualCaseAccount { contract_address }
}

fn setup_account_panic() -> (DualCaseAccount, DualCaseAccount) {
    let snake_target = utils::declare_and_deploy("SnakeAccountPanicMock", array![]);
    let camel_target = utils::declare_and_deploy("CamelAccountPanicMock", array![]);
    (
        DualCaseAccount { contract_address: snake_target },
        DualCaseAccount { contract_address: camel_target }
    )
}

//
// snake_case target
//

#[test]
fn test_dual_set_public_key() {
    let key_pair = KEY_PAIR();
    let (snake_dispatcher, target) = setup_snake(key_pair);
    let new_key_pair = KEY_PAIR_2();
    let signature = get_accept_ownership_signature(
        snake_dispatcher.contract_address, key_pair.public_key, new_key_pair
    );
    start_cheat_caller_address(target.contract_address, target.contract_address);

    snake_dispatcher.set_public_key(new_key_pair.public_key, signature);

    assert_eq!(target.get_public_key(), new_key_pair.public_key);
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_set_public_key() {
    let dispatcher = setup_non_account();
    let new_public_key = KEY_PAIR_2().public_key;
    dispatcher.set_public_key(new_public_key, array![].span());
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_set_public_key_exists_and_panics() {
    let (snake_dispatcher, _) = setup_account_panic();
    let new_public_key = KEY_PAIR_2().public_key;
    snake_dispatcher.set_public_key(new_public_key, array![].span());
}

#[test]
fn test_dual_get_public_key() {
    let key_pair = KEY_PAIR();
    let (snake_dispatcher, _) = setup_snake(key_pair);
    let expected_public_key = key_pair.public_key;
    assert_eq!(snake_dispatcher.get_public_key(), expected_public_key);
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
    let (snake_dispatcher, _) = setup_account_panic();
    snake_dispatcher.get_public_key();
}

#[test]
fn test_dual_is_valid_signature() {
    let key_pair = KEY_PAIR();
    let (snake_dispatcher, _) = setup_snake(key_pair);
    let tx_hash = TRANSACTION_HASH;
    let serialized_signature = key_pair.serialized_sign(tx_hash);

    let is_valid = snake_dispatcher.is_valid_signature(tx_hash, serialized_signature);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_is_valid_signature() {
    let signature = array![];

    let dispatcher = setup_non_account();
    dispatcher.is_valid_signature(TRANSACTION_HASH, signature);
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_is_valid_signature_exists_and_panics() {
    let signature = array![];
    let (snake_dispatcher, _) = setup_account_panic();

    snake_dispatcher.is_valid_signature(TRANSACTION_HASH, signature);
}

#[test]
fn test_dual_supports_interface() {
    let (snake_dispatcher, _) = setup_snake(KEY_PAIR());
    let supports_isrc5 = snake_dispatcher.supports_interface(ISRC5_ID);
    assert!(supports_isrc5);
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
    let (snake_dispatcher, _) = setup_account_panic();
    snake_dispatcher.supports_interface(ISRC5_ID);
}

//
// camelCase target
//

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
fn test_dual_setPublicKey() {
    let key_pair = KEY_PAIR();
    let (camel_dispatcher, target) = setup_camel(key_pair);
    let new_key_pair = KEY_PAIR_2();
    let signature = get_accept_ownership_signature(
        camel_dispatcher.contract_address, key_pair.public_key, new_key_pair
    );
    start_cheat_caller_address(target.contract_address, target.contract_address);

    camel_dispatcher.set_public_key(new_key_pair.public_key, signature);

    assert_eq!(target.getPublicKey(), new_key_pair.public_key);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
#[should_panic(expected: ("Some error",))]
fn test_dual_setPublicKey_exists_and_panics() {
    let (_, camel_dispatcher) = setup_account_panic();
    let new_public_key = KEY_PAIR_2().public_key;
    camel_dispatcher.set_public_key(new_public_key, array![].span());
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
fn test_dual_getPublicKey() {
    let key_pair = KEY_PAIR();
    let (camel_dispatcher, _) = setup_camel(key_pair);
    let expected_public_key = key_pair.public_key;
    assert_eq!(camel_dispatcher.get_public_key(), expected_public_key);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
#[should_panic(expected: ("Some error",))]
fn test_dual_getPublicKey_exists_and_panics() {
    let (_, camel_dispatcher) = setup_account_panic();
    camel_dispatcher.get_public_key();
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
fn test_dual_isValidSignature() {
    let key_pair = KEY_PAIR();
    let (camel_dispatcher, _) = setup_camel(key_pair);
    let tx_hash = TRANSACTION_HASH;
    let serialized_signature = key_pair.serialized_sign(tx_hash);

    let is_valid = camel_dispatcher.is_valid_signature(tx_hash, serialized_signature);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
#[should_panic(expected: ("Some error",))]
fn test_dual_isValidSignature_exists_and_panics() {
    let signature = array![];

    let (_, camel_dispatcher) = setup_account_panic();
    camel_dispatcher.is_valid_signature(TRANSACTION_HASH, signature);
}
