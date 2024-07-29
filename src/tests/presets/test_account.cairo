use core::num::traits::Zero;
use openzeppelin::account::interface::ISRC6_ID;
use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::presets::AccountUpgradeable;
use openzeppelin::presets::interfaces::account::{
    AccountUpgradeableABISafeDispatcher, AccountUpgradeableABISafeDispatcherTrait
};
use openzeppelin::presets::interfaces::{
    AccountUpgradeableABIDispatcher, AccountUpgradeableABIDispatcherTrait
};
use openzeppelin::tests::account::starknet::common::{
    get_accept_ownership_signature, deploy_erc20, SIGNED_TX_DATA,
};
use openzeppelin::tests::account::starknet::common::{AccountSpyHelpers, SignedTransactionData};
use openzeppelin::tests::upgrades::common::UpgradeableSpyHelpers;
use openzeppelin::tests::utils::constants::stark::{KEY_PAIR, KEY_PAIR_2};
use openzeppelin::tests::utils::constants::{
    SALT, QUERY_OFFSET, QUERY_VERSION, MIN_TRANSACTION_VERSION
};
use openzeppelin::tests::utils::constants::{ZERO, CALLER, RECIPIENT, OTHER, CLASS_HASH_ZERO};
use openzeppelin::tests::utils::signing::{StarkKeyPair, StarkKeyPairExt};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::interface::IERC20DispatcherTrait;
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::{
    cheat_signature_global, cheat_transaction_version_global, cheat_transaction_hash_global
};
use snforge_std::{spy_events, test_address, start_cheat_caller_address};
use starknet::account::Call;
use starknet::{ContractAddress, ClassHash};

//
// Setup
//

fn declare_v2_class() -> ClassHash {
    utils::declare_class("SnakeAccountMock").class_hash
}

fn setup_dispatcher(key_pair: StarkKeyPair) -> (ContractAddress, AccountUpgradeableABIDispatcher) {
    let calldata = array![key_pair.public_key];
    let account_address = utils::declare_and_deploy("AccountUpgradeable", calldata);
    let dispatcher = AccountUpgradeableABIDispatcher { contract_address: account_address };

    (account_address, dispatcher)
}

fn setup_dispatcher_with_data(
    key_pair: StarkKeyPair, data: SignedTransactionData
) -> (AccountUpgradeableABIDispatcher, felt252) {
    let account_class = utils::declare_class("AccountUpgradeable");
    let calldata = array![key_pair.public_key];
    let contract_address = utils::deploy(account_class, calldata);
    let account_dispatcher = AccountUpgradeableABIDispatcher { contract_address };

    cheat_signature_global(array![data.r, data.s].span());
    cheat_transaction_hash_global(data.tx_hash);
    cheat_transaction_version_global(MIN_TRANSACTION_VERSION);
    start_cheat_caller_address(contract_address, ZERO());

    (account_dispatcher, account_class.class_hash.into())
}

//
// constructor
//

#[test]
fn test_constructor() {
    let mut state = AccountUpgradeable::contract_state_for_testing();
    let mut spy = spy_events();
    let key_pair = KEY_PAIR();
    let account_address = test_address();
    AccountUpgradeable::constructor(ref state, key_pair.public_key);

    spy.assert_only_event_owner_added(account_address, key_pair.public_key);

    let public_key = AccountUpgradeable::AccountMixinImpl::get_public_key(@state);
    assert_eq!(public_key, key_pair.public_key);

    let supports_isrc5 = AccountUpgradeable::AccountMixinImpl::supports_interface(@state, ISRC5_ID);
    assert!(supports_isrc5);

    let supports_isrc6 = AccountUpgradeable::AccountMixinImpl::supports_interface(@state, ISRC6_ID);
    assert!(supports_isrc6);
}

//
// set_public_key & setPublicKey
//

#[test]
fn test_public_key_setter_and_getter() {
    let key_pair = KEY_PAIR();
    let (account_address, dispatcher) = setup_dispatcher(key_pair);
    let mut spy = spy_events();

    let new_key_pair = KEY_PAIR_2();
    let signature = get_accept_ownership_signature(
        account_address, key_pair.public_key, new_key_pair
    );
    start_cheat_caller_address(account_address, account_address);
    dispatcher.set_public_key(new_key_pair.public_key, signature);

    assert_eq!(dispatcher.get_public_key(), new_key_pair.public_key);

    spy.assert_event_owner_removed(dispatcher.contract_address, key_pair.public_key);
    spy.assert_only_event_owner_added(dispatcher.contract_address, new_key_pair.public_key);
}

#[test]
fn test_public_key_setter_and_getter_camel() {
    let key_pair = KEY_PAIR();
    let (account_address, dispatcher) = setup_dispatcher(key_pair);
    let mut spy = spy_events();

    let new_key_pair = KEY_PAIR_2();
    let signature = get_accept_ownership_signature(
        account_address, key_pair.public_key, new_key_pair
    );
    start_cheat_caller_address(account_address, account_address);
    dispatcher.setPublicKey(new_key_pair.public_key, signature);

    assert_eq!(dispatcher.getPublicKey(), new_key_pair.public_key);

    spy.assert_event_owner_removed(dispatcher.contract_address, key_pair.public_key);
    spy.assert_only_event_owner_added(dispatcher.contract_address, new_key_pair.public_key);
}

#[test]
#[should_panic(expected: ('Account: unauthorized',))]
fn test_set_public_key_different_account() {
    let key_pair = KEY_PAIR();
    let (account_address, dispatcher) = setup_dispatcher(key_pair);

    let new_key_pair = KEY_PAIR_2();
    let signature = get_accept_ownership_signature(
        account_address, key_pair.public_key, new_key_pair
    );
    dispatcher.set_public_key(new_key_pair.public_key, signature);
}

#[test]
#[should_panic(expected: ('Account: unauthorized',))]
fn test_setPublicKey_different_account() {
    let key_pair = KEY_PAIR();
    let (account_address, dispatcher) = setup_dispatcher(key_pair);

    let new_key_pair = KEY_PAIR_2();
    let signature = get_accept_ownership_signature(
        account_address, key_pair.public_key, new_key_pair
    );
    dispatcher.setPublicKey(new_key_pair.public_key, signature);
}

//
// is_valid_signature & isValidSignature
//

fn is_valid_sig_dispatcher() -> (AccountUpgradeableABIDispatcher, felt252, Array<felt252>) {
    let key_pair = KEY_PAIR();
    let (_, dispatcher) = setup_dispatcher(key_pair);

    let data = SIGNED_TX_DATA(key_pair);
    let signature = array![data.r, data.s];
    (dispatcher, data.tx_hash, signature)
}

#[test]
fn test_is_valid_signature() {
    let (dispatcher, hash, signature) = is_valid_sig_dispatcher();

    let is_valid = dispatcher.is_valid_signature(hash, signature);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
fn test_is_valid_signature_bad_sig() {
    let (dispatcher, tx_hash, _) = is_valid_sig_dispatcher();
    let bad_signature = array!['BAD', 'SIG'];

    let is_valid = dispatcher.is_valid_signature(tx_hash, bad_signature);
    assert!(is_valid.is_zero(), "Should reject invalid signature");
}

#[test]
fn test_is_valid_signature_invalid_len_sig() {
    let (dispatcher, tx_hash, _) = is_valid_sig_dispatcher();
    let invalid_len_sig = array!['INVALID_LEN'];

    let is_valid = dispatcher.is_valid_signature(tx_hash, invalid_len_sig);
    assert!(is_valid.is_zero(), "Should reject signature of invalid length");
}

#[test]
fn test_isValidSignature() {
    let (dispatcher, tx_hash, signature) = is_valid_sig_dispatcher();

    let is_valid = dispatcher.isValidSignature(tx_hash, signature);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
fn test_isValidSignature_bad_sig() {
    let (dispatcher, tx_hash, _) = is_valid_sig_dispatcher();
    let bad_signature = array!['BAD', 'SIG'];

    let is_valid = dispatcher.isValidSignature(tx_hash, bad_signature);
    assert!(is_valid.is_zero(), "Should reject invalid signature");
}

#[test]
fn test_isValidSignature_invalid_len_sig() {
    let (dispatcher, tx_hash, _) = is_valid_sig_dispatcher();
    let invalid_len_sig = array!['INVALID_LEN'];

    let is_valid = dispatcher.isValidSignature(tx_hash, invalid_len_sig);
    assert!(is_valid.is_zero(), "Should reject signature of invalid length");
}

//
// supports_interface
//

#[test]
fn test_supports_interface() {
    let key_pair = KEY_PAIR();
    let (_, dispatcher) = setup_dispatcher(key_pair);

    let supports_isrc5 = dispatcher.supports_interface(ISRC5_ID);
    assert!(supports_isrc5);

    let supports_isrc6 = dispatcher.supports_interface(ISRC6_ID);
    assert!(supports_isrc6);

    let doesnt_support_0x123 = !dispatcher.supports_interface('DUMMY_INTERFACE_ID');
    assert!(doesnt_support_0x123);
}

//
// Entry points
//

#[test]
fn test_validate_deploy() {
    let key_pair = KEY_PAIR();
    let (account, class_hash) = setup_dispatcher_with_data(key_pair, SIGNED_TX_DATA(key_pair));

    // `__validate_deploy__` does not directly use the passed arguments. Their
    // values are already integrated in the tx hash. The passed arguments in this
    // testing context are decoupled from the signature and have no effect on the test.
    let is_valid = account.__validate_deploy__(class_hash, SALT, key_pair.public_key);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('Account: invalid signature',))]
fn test_validate_deploy_invalid_signature_data() {
    let key_pair = KEY_PAIR();
    let mut data = SIGNED_TX_DATA(key_pair);
    data.tx_hash += 1;
    let (account, class_hash) = setup_dispatcher_with_data(key_pair, data);

    account.__validate_deploy__(class_hash, SALT, key_pair.public_key);
}

#[test]
#[should_panic(expected: ('Account: invalid signature',))]
fn test_validate_deploy_invalid_signature_length() {
    let key_pair = KEY_PAIR();
    let (account, class_hash) = setup_dispatcher_with_data(key_pair, SIGNED_TX_DATA(key_pair));

    let invalid_len_sig = array!['INVALID_LEN'];
    cheat_signature_global(invalid_len_sig.span());

    account.__validate_deploy__(class_hash, SALT, key_pair.public_key);
}

#[test]
#[should_panic(expected: ('Account: invalid signature',))]
fn test_validate_deploy_empty_signature() {
    let key_pair = KEY_PAIR();
    let (account, class_hash) = setup_dispatcher_with_data(key_pair, SIGNED_TX_DATA(key_pair));

    let empty_sig = array![];
    cheat_signature_global(empty_sig.span());

    account.__validate_deploy__(class_hash, SALT, key_pair.public_key);
}

#[test]
fn test_validate_declare() {
    let key_pair = KEY_PAIR();
    let (account, class_hash) = setup_dispatcher_with_data(key_pair, SIGNED_TX_DATA(key_pair));

    // `__validate_declare__` does not directly use the class_hash argument. Its
    // value is already integrated in the tx hash. The class_hash argument in this
    // testing context is decoupled from the signature and has no effect on the test.
    let is_valid = account.__validate_declare__(class_hash);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('Account: invalid signature',))]
fn test_validate_declare_invalid_signature_data() {
    let key_pair = KEY_PAIR();
    let mut data = SIGNED_TX_DATA(key_pair);
    data.tx_hash += 1;
    let (account, class_hash) = setup_dispatcher_with_data(key_pair, data);

    account.__validate_declare__(class_hash);
}

#[test]
#[should_panic(expected: ('Account: invalid signature',))]
fn test_validate_declare_invalid_signature_length() {
    let key_pair = KEY_PAIR();
    let (account, class_hash) = setup_dispatcher_with_data(key_pair, SIGNED_TX_DATA(key_pair));

    let invalid_len_sig = array!['INVALID_LEN'];
    cheat_signature_global(invalid_len_sig.span());

    account.__validate_declare__(class_hash);
}

#[test]
#[should_panic(expected: ('Account: invalid signature',))]
fn test_validate_declare_empty_signature() {
    let key_pair = KEY_PAIR();
    let (account, class_hash) = setup_dispatcher_with_data(key_pair, SIGNED_TX_DATA(key_pair));

    let empty_sig = array![];
    cheat_signature_global(empty_sig.span());

    account.__validate_declare__(class_hash);
}

fn test_execute_with_version(version: Option<felt252>) {
    let key_pair = KEY_PAIR();
    let data = SIGNED_TX_DATA(key_pair);
    let (account, _) = setup_dispatcher_with_data(key_pair, data);
    let erc20 = deploy_erc20(account.contract_address, 1000);

    // Craft call and add to calls array
    let amount: u256 = 200;

    let recipient = RECIPIENT();
    let mut calldata = array![];
    calldata.append_serde(recipient);
    calldata.append_serde(amount);

    let call = Call {
        to: erc20.contract_address, selector: selectors::transfer, calldata: calldata.span()
    };
    let calls = array![call];

    // Handle version for test
    if let Option::Some(version) = version {
        cheat_transaction_version_global(version)
    }

    // Execute
    let ret = account.__execute__(calls);

    // Assert that the transfer was successful
    assert_eq!(erc20.balance_of(account.contract_address), 800, "Should have remainder");
    assert_eq!(erc20.balance_of(recipient), amount, "Should have transferred");

    // Test return value
    let mut call_serialized_retval = *ret.at(0);
    let call_retval = Serde::<bool>::deserialize(ref call_serialized_retval);
    assert!(call_retval.unwrap());
}

#[test]
fn test_execute() {
    test_execute_with_version(Option::None);
}

#[test]
fn test_execute_future_version() {
    test_execute_with_version(Option::Some(MIN_TRANSACTION_VERSION + 1));
}

#[test]
fn test_execute_query_version() {
    test_execute_with_version(Option::Some(QUERY_VERSION));
}

#[test]
#[should_panic(expected: ('Account: invalid tx version',))]
fn test_execute_invalid_query_version() {
    test_execute_with_version(Option::Some(QUERY_OFFSET));
}

#[test]
fn test_execute_future_query_version() {
    test_execute_with_version(Option::Some(QUERY_VERSION + 1));
}

#[test]
#[should_panic(expected: ('Account: invalid tx version',))]
fn test_execute_invalid_version() {
    test_execute_with_version(Option::Some(MIN_TRANSACTION_VERSION - 1));
}

#[test]
fn test_validate() {
    let key_pair = KEY_PAIR();
    let (account, _) = setup_dispatcher_with_data(key_pair, SIGNED_TX_DATA(key_pair));

    let calls = array![];
    let is_valid = account.__validate__(calls);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('Account: invalid signature',))]
fn test_validate_invalid() {
    let key_pair = KEY_PAIR();
    let mut data = SIGNED_TX_DATA(key_pair);
    data.tx_hash += 1;
    let (account, _) = setup_dispatcher_with_data(key_pair, data);

    let calls = array![];
    account.__validate__(calls);
}

#[test]
fn test_multicall() {
    let key_pair = KEY_PAIR();
    let (account, _) = setup_dispatcher_with_data(key_pair, SIGNED_TX_DATA(key_pair));
    let erc20 = deploy_erc20(account.contract_address, 1000);
    let recipient1 = RECIPIENT();
    let recipient2 = OTHER();
    let mut calls = array![];

    // Craft call1
    let mut calldata1 = array![];
    let amount1: u256 = 300;
    calldata1.append_serde(recipient1);
    calldata1.append_serde(amount1);
    let call1 = Call {
        to: erc20.contract_address, selector: selectors::transfer, calldata: calldata1.span()
    };

    // Craft call2
    let mut calldata2 = array![];
    let amount2: u256 = 500;
    calldata2.append_serde(recipient2);
    calldata2.append_serde(amount2);
    let call2 = Call {
        to: erc20.contract_address, selector: selectors::transfer, calldata: calldata2.span()
    };

    // Bundle calls and execute
    calls.append(call1);
    calls.append(call2);
    let ret = account.__execute__(calls);

    // Assert that the transfers were successful
    assert_eq!(erc20.balance_of(account.contract_address), 200, "Should have remainder");
    assert_eq!(erc20.balance_of(recipient1), 300, "Should have transferred");
    assert_eq!(erc20.balance_of(recipient2), 500, "Should have transferred");

    // Test return value
    let mut call1_serialized_retval = *ret.at(0);
    let mut call2_serialized_retval = *ret.at(1);

    let call1_retval = Serde::<bool>::deserialize(ref call1_serialized_retval);
    assert!(call1_retval.unwrap());

    let call2_retval = Serde::<bool>::deserialize(ref call2_serialized_retval);
    assert!(call2_retval.unwrap());
}

#[test]
fn test_multicall_zero_calls() {
    let key_pair = KEY_PAIR();
    let (account, _) = setup_dispatcher_with_data(key_pair, SIGNED_TX_DATA(key_pair));

    let calls = array![];
    let response = account.__execute__(calls);
    assert!(response.is_empty());
}

#[test]
#[should_panic(expected: ('Account: invalid caller',))]
fn test_account_called_from_contract() {
    let key_pair = KEY_PAIR();
    let (account_address, dispatcher) = setup_dispatcher(key_pair);

    let calls = array![];
    start_cheat_caller_address(account_address, CALLER());
    dispatcher.__execute__(calls);
}

//
// upgrade
//

#[test]
#[should_panic(expected: ('Account: unauthorized',))]
fn test_upgrade_access_control() {
    let key_pair = KEY_PAIR();
    let (_, v1_dispatcher) = setup_dispatcher(key_pair);

    v1_dispatcher.upgrade(CLASS_HASH_ZERO());
}

#[test]
#[should_panic(expected: ('Class hash cannot be zero',))]
fn test_upgrade_with_class_hash_zero() {
    let key_pair = KEY_PAIR();
    let (account_address, v1_dispatcher) = setup_dispatcher(key_pair);

    start_cheat_caller_address(account_address, account_address);
    v1_dispatcher.upgrade(CLASS_HASH_ZERO());
}

#[test]
fn test_upgraded_event() {
    let key_pair = KEY_PAIR();
    let (account_address, v1_dispatcher) = setup_dispatcher(key_pair);
    let mut spy = spy_events();

    let v2_class_hash = declare_v2_class();
    start_cheat_caller_address(account_address, account_address);
    v1_dispatcher.upgrade(v2_class_hash);

    spy.assert_only_event_upgraded(account_address, v2_class_hash);
}

#[test]
#[feature("safe_dispatcher")]
fn test_v2_missing_camel_selector() {
    let key_pair = KEY_PAIR();
    let (account_address, v1_dispatcher) = setup_dispatcher(key_pair);

    let v2_class_hash = declare_v2_class();
    start_cheat_caller_address(account_address, account_address);
    v1_dispatcher.upgrade(v2_class_hash);

    let safe_dispatcher = AccountUpgradeableABISafeDispatcher { contract_address: account_address };
    let result = safe_dispatcher.getPublicKey();

    utils::assert_entrypoint_not_found_error(result, selector!("getPublicKey"), account_address)
}

#[test]
fn test_state_persists_after_upgrade() {
    let key_pair = KEY_PAIR();
    let (account_address, v1_dispatcher) = setup_dispatcher(key_pair);

    let new_key_pair = KEY_PAIR_2();
    let accept_ownership_sig = get_accept_ownership_signature(
        account_address, key_pair.public_key, new_key_pair
    );
    start_cheat_caller_address(account_address, account_address);
    v1_dispatcher.set_public_key(new_key_pair.public_key, accept_ownership_sig);

    let expected_public_key = new_key_pair.public_key;
    let camel_public_key = v1_dispatcher.getPublicKey();
    assert_eq!(camel_public_key, expected_public_key);

    let v2_class_hash = declare_v2_class();
    v1_dispatcher.upgrade(v2_class_hash);
    let snake_public_key = v1_dispatcher.get_public_key();

    assert_eq!(snake_public_key, expected_public_key);
}
