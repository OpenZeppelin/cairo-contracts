use openzeppelin::account::dual_account::{DualCaseAccountABI, DualCaseAccount};
use openzeppelin::account::interface::{AccountABIDispatcherTrait, AccountABIDispatcher};
use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::tests::account::starknet::common::SIGNED_TX_DATA;
use openzeppelin::tests::mocks::account_mocks::{
    CamelAccountPanicMock, CamelAccountMock, SnakeAccountMock, SnakeAccountPanicMock
};
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::utils::constants::TRANSACTION_HASH;
use openzeppelin::tests::utils::constants::stark::{KEY_PAIR, KEY_PAIR_2};
use openzeppelin::tests::utils;
use snforge_std::{declare, start_cheat_caller_address};

use super::common::get_accept_ownership_signature;

//
// Setup
//

fn setup_snake() -> (DualCaseAccount, AccountABIDispatcher) {
    let key_pair = KEY_PAIR();
    let calldata = array![key_pair.public_key];
    let target = utils::declare_and_deploy("SnakeAccountMock", calldata);
    (
        DualCaseAccount { contract_address: target },
        AccountABIDispatcher { contract_address: target }
    )
}

fn setup_camel() -> (DualCaseAccount, AccountABIDispatcher) {
    let key_pair = KEY_PAIR();
    let calldata = array![key_pair.public_key];
    let target = utils::declare_and_deploy("CamelAccountMock", calldata);
    (
        DualCaseAccount { contract_address: target },
        AccountABIDispatcher { contract_address: target }
    )
}

fn setup_non_account() -> DualCaseAccount {
    let calldata = array![];
    let target = utils::declare_and_deploy("NonImplementingMock", calldata);
    DualCaseAccount { contract_address: target }
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
    let (snake_dispatcher, target) = setup_snake();
    let public_key = KEY_PAIR().public_key;
    let new_key_pair = KEY_PAIR_2();
    let new_public_key = new_key_pair.public_key;
    let signature = get_accept_ownership_signature(
        snake_dispatcher.contract_address, public_key, new_key_pair
    );
    start_cheat_caller_address(target.contract_address, target.contract_address);

    snake_dispatcher.set_public_key(new_public_key, signature);

    assert_eq!(target.get_public_key(), new_public_key);
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
    let (snake_dispatcher, _) = setup_snake();
    let expected_public_key = KEY_PAIR().public_key;
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
    let (snake_dispatcher, target) = setup_snake();
    let public_key = KEY_PAIR().public_key;
    let new_key_pair = KEY_PAIR_2();
    let data = SIGNED_TX_DATA(new_key_pair);
    start_cheat_caller_address(target.contract_address, target.contract_address);
    let accept_signature = get_accept_ownership_signature(
        snake_dispatcher.contract_address, public_key, new_key_pair
    );

    target.set_public_key(data.public_key, accept_signature);

    let signature = array![data.r, data.s];
    let is_valid = snake_dispatcher.is_valid_signature(data.tx_hash, signature);
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
    let (snake_dispatcher, _) = setup_snake();
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
    let (camel_dispatcher, target) = setup_camel();
    let public_key = KEY_PAIR().public_key;
    let new_key_pair = KEY_PAIR_2();
    let new_public_key = new_key_pair.public_key;
    let signature = get_accept_ownership_signature(
        camel_dispatcher.contract_address, public_key, new_key_pair
    );
    start_cheat_caller_address(target.contract_address, target.contract_address);

    camel_dispatcher.set_public_key(new_public_key, signature);

    assert_eq!(target.getPublicKey(), new_public_key);
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
    let (camel_dispatcher, _) = setup_camel();
    let expected_public_key = KEY_PAIR().public_key;
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
    let (camel_dispatcher, target) = setup_camel();
    let public_key = KEY_PAIR().public_key;
    let new_key_pair = KEY_PAIR_2();
    let data = SIGNED_TX_DATA(new_key_pair);
    let signature = array![data.r, data.s];
    start_cheat_caller_address(target.contract_address, target.contract_address);
    let accept_signature = get_accept_ownership_signature(
        camel_dispatcher.contract_address, public_key, new_key_pair
    );

    target.setPublicKey(data.public_key, accept_signature);

    let is_valid = camel_dispatcher.is_valid_signature(data.tx_hash, signature);
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
