use openzeppelin::account::dual_account::{DualCaseAccountABI, DualCaseAccount};
use openzeppelin::account::interface::{AccountABIDispatcherTrait, AccountABIDispatcher};
use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::tests::account::starknet::common::SIGNED_TX_DATA;
use openzeppelin::tests::mocks::account_mocks::{
    CamelAccountPanicMock, CamelAccountMock, SnakeAccountMock, SnakeAccountPanicMock
};
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::utils::constants::ZERO;
use openzeppelin::tests::utils::signing::stark::{KEY_PAIR, KEY_PAIR_2, PUBKEY, PUBKEY_2};
use openzeppelin::tests::utils;
use snforge_std::{EventSpy, declare, start_cheat_caller_address};

use super::common::get_accept_ownership_signature;

//
// Setup
//

fn setup_snake() -> (DualCaseAccount, AccountABIDispatcher) {
    let calldata = array![PUBKEY];
    let target = utils::declare_and_deploy("SnakeAccountMock", calldata);
    (
        DualCaseAccount { contract_address: target },
        AccountABIDispatcher { contract_address: target }
    )
}

fn setup_camel() -> (DualCaseAccount, AccountABIDispatcher) {
    let calldata = array![PUBKEY];
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

const NEW_PUBKEY: felt252 = PUBKEY_2;

#[test]
fn test_dual_set_public_key() {
    let (snake_dispatcher, target) = setup_snake();
    let signature = get_accept_ownership_signature(
        snake_dispatcher.contract_address, PUBKEY, KEY_PAIR_2
    );
    start_cheat_caller_address(target.contract_address, target.contract_address);

    snake_dispatcher.set_public_key(NEW_PUBKEY, signature);

    let public_key = target.get_public_key();
    assert_eq!(public_key, NEW_PUBKEY);
}

#[test]
#[ignore] // REASON: inconsistent ENTRYPOINT_NOT_FOUND panic message
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_set_public_key() {
    let dispatcher = setup_non_account();
    dispatcher.set_public_key(NEW_PUBKEY, array![].span());
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_set_public_key_exists_and_panics() {
    let (snake_dispatcher, _) = setup_account_panic();
    snake_dispatcher.set_public_key(NEW_PUBKEY, array![].span());
}

#[test]
fn test_dual_get_public_key() {
    let (snake_dispatcher, _) = setup_snake();
    let public_key = snake_dispatcher.get_public_key();
    assert_eq!(public_key, PUBKEY);
}

#[test]
#[ignore] // REASON: inconsistent ENTRYPOINT_NOT_FOUND panic message
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
    let data = SIGNED_TX_DATA(KEY_PAIR_2);
    let signature = get_accept_ownership_signature(target.contract_address, PUBKEY, KEY_PAIR_2);
    start_cheat_caller_address(target.contract_address, target.contract_address);

    target.set_public_key(data.public_key, signature);

    let signature = array![data.r, data.s];
    let is_valid = snake_dispatcher.is_valid_signature(data.tx_hash, signature);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[ignore] // REASON: inconsistent ENTRYPOINT_NOT_FOUND panic message
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

    let (snake_dispatcher, _) = setup_account_panic();
    snake_dispatcher.is_valid_signature(hash, signature);
}

#[test]
fn test_dual_supports_interface() {
    let (snake_dispatcher, _) = setup_snake();
    let supports_isrc5 = snake_dispatcher.supports_interface(ISRC5_ID);
    assert!(supports_isrc5);
}

#[test]
#[ignore] // REASON: inconsistent ENTRYPOINT_NOT_FOUND panic message
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
#[ignore] // REASON: lack of error handling causes try_selector_with_fallback to fail
fn test_dual_setPublicKey() {
    let (camel_dispatcher, target) = setup_camel();
    let signature = get_accept_ownership_signature(
        camel_dispatcher.contract_address, PUBKEY, KEY_PAIR_2
    );
    start_cheat_caller_address(target.contract_address, target.contract_address);

    camel_dispatcher.set_public_key(NEW_PUBKEY, signature);

    let public_key = target.getPublicKey();
    assert_eq!(public_key, NEW_PUBKEY);
}

#[test]
#[ignore] // REASON: lack of error handling causes try_selector_with_fallback to fail
#[should_panic(expected: ("Some error",))]
fn test_dual_setPublicKey_exists_and_panics() {
    let (_, camel_dispatcher) = setup_account_panic();
    camel_dispatcher.set_public_key(NEW_PUBKEY, array![].span());
}

#[test]
#[ignore] // REASON: lack of error handling causes try_selector_with_fallback to fail
fn test_dual_getPublicKey() {
    let (camel_dispatcher, _) = setup_camel();
    let public_key = camel_dispatcher.get_public_key();
    assert_eq!(public_key, PUBKEY);
}

#[test]
#[ignore] // REASON: lack of error handling causes try_selector_with_fallback to fail
#[should_panic(expected: ("Some error",))]
fn test_dual_getPublicKey_exists_and_panics() {
    let (_, camel_dispatcher) = setup_account_panic();
    camel_dispatcher.get_public_key();
}

#[test]
#[ignore] // REASON: lack of error handling causes try_selector_with_fallback to fail
fn test_dual_isValidSignature() {
    let (camel_dispatcher, target) = setup_camel();

    let data = SIGNED_TX_DATA(KEY_PAIR_2);
    let signature = array![data.r, data.s];
    start_cheat_caller_address(target.contract_address, target.contract_address);
    let accept_signature = get_accept_ownership_signature(
        camel_dispatcher.contract_address, PUBKEY, KEY_PAIR_2
    );

    target.setPublicKey(data.public_key, accept_signature);

    let is_valid = camel_dispatcher.is_valid_signature(data.tx_hash, signature);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[ignore] // REASON: lack of error handling causes try_selector_with_fallback to fail
#[should_panic(expected: ("Some error",))]
fn test_dual_isValidSignature_exists_and_panics() {
    let hash = 0x0;
    let signature = array![];

    let (_, camel_dispatcher) = setup_account_panic();
    camel_dispatcher.is_valid_signature(hash, signature);
}
