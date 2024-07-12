use core::num::traits::Zero;
use core::starknet::SyscallResultTrait;
use openzeppelin::account::AccountComponent::{InternalTrait, SRC6CamelOnlyImpl};
use openzeppelin::account::AccountComponent::{PublicKeyCamelImpl, PublicKeyImpl};
use openzeppelin::account::AccountComponent;
use openzeppelin::account::interface::{AccountABIDispatcherTrait, AccountABIDispatcher};
use openzeppelin::account::interface::{ISRC6, ISRC6_ID};
use openzeppelin::introspection::interface::{ISRC5, ISRC5_ID};
use openzeppelin::tests::mocks::account_mocks::DualCaseAccountMock;
use openzeppelin::tests::utils::constants::{
    SALT, ZERO, OTHER, CALLER, QUERY_OFFSET, QUERY_VERSION, MIN_TRANSACTION_VERSION
};
use openzeppelin::tests::utils::signing::stark::{
    KEY_PAIR, KEY_PAIR_2, PUBKEY, PUBKEY_2, PRIVATE_KEY
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::signature::SignerTrait;
use snforge_std::signature::stark_curve::{StarkCurveSignerImpl, StarkCurveKeyPairImpl};
use snforge_std::{
    cheat_signature_global, cheat_transaction_version_global, cheat_transaction_hash_global
};
use snforge_std::{EventSpy, spy_events, declare, test_address, start_cheat_caller_address};
use starknet::account::Call;
use starknet::contract_address_const;
use starknet::{ContractAddress, ClassHash};

use super::common::{AccountSpyHelpers, SignedTransactionData};
use super::common::{deploy_erc20, SIGNED_TX_DATA, get_accept_ownership_signature};

//
// Setup
//

type ComponentState = AccountComponent::ComponentState<DualCaseAccountMock::ContractState>;

fn CONTRACT_STATE() -> DualCaseAccountMock::ContractState {
    DualCaseAccountMock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    AccountComponent::component_state_for_testing()
}

fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    state.initializer(PUBKEY);
    state
}

fn setup_dispatcher(data: Option<@SignedTransactionData>) -> (AccountABIDispatcher, felt252) {
    let contract_class = declare("DualCaseAccountMock").unwrap_syscall();
    let calldata = if let Option::Some(data) = data {
        cheat_signature_global(array![*data.r, *data.s].span());
        cheat_transaction_hash_global(*data.tx_hash);
        array![*data.public_key]
    } else {
        array![PUBKEY]
    };

    let address = utils::deploy(contract_class, calldata);
    let dispatcher = AccountABIDispatcher { contract_address: address };

    cheat_transaction_version_global(MIN_TRANSACTION_VERSION);
    start_cheat_caller_address(address, ZERO());

    (dispatcher, contract_class.class_hash.into())
}

//
// is_valid_signature & isValidSignature
//

#[test]
fn test_is_valid_signature() {
    let mut state = COMPONENT_STATE();
    let data = SIGNED_TX_DATA(KEY_PAIR);

    let mut good_signature = array![data.r, data.s];
    let mut bad_signature = array![0x987, 0x564];

    state._set_public_key(data.public_key);

    let is_valid = state.is_valid_signature(data.tx_hash, good_signature);
    assert_eq!(is_valid, starknet::VALIDATED);

    let is_valid = state.is_valid_signature(data.tx_hash, bad_signature);
    assert!(is_valid.is_zero(), "Should reject invalid signature");
}

#[test]
fn test_isValidSignature() {
    let mut state = COMPONENT_STATE();
    let data = SIGNED_TX_DATA(KEY_PAIR);

    state._set_public_key(data.public_key);

    let good_signature = array![data.r, data.s];
    let is_valid = state.isValidSignature(data.tx_hash, good_signature);
    assert_eq!(is_valid, starknet::VALIDATED);

    let bad_signature = array!['BAD', 'SIGNATURE'];
    let is_valid = state.isValidSignature(data.tx_hash, bad_signature);
    assert!(is_valid.is_zero(), "Should reject invalid signature");
}

//
// Entry points
//

#[test]
fn test_validate_deploy() {
    let (account, class_hash) = setup_dispatcher(Option::Some(@SIGNED_TX_DATA(KEY_PAIR)));

    // `__validate_deploy__` does not directly use the passed arguments. Their
    // values are already integrated in the tx hash. The passed arguments in this
    // testing context are decoupled from the signature and have no effect on the test.
    let is_valid = account.__validate_deploy__(class_hash, SALT, PUBKEY);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('Account: invalid signature',))]
fn test_validate_deploy_invalid_signature_data() {
    let mut data = SIGNED_TX_DATA(KEY_PAIR);
    data.tx_hash += 1;
    let (account, class_hash) = setup_dispatcher(Option::Some(@data));

    account.__validate_deploy__(class_hash, SALT, PUBKEY);
}

#[test]
#[should_panic(expected: ('Account: invalid signature',))]
fn test_validate_deploy_invalid_signature_length() {
    let (account, class_hash) = setup_dispatcher(Option::Some(@SIGNED_TX_DATA(KEY_PAIR)));
    let signature = array![0x1];
    cheat_signature_global(signature.span());

    account.__validate_deploy__(class_hash, SALT, PUBKEY);
}

#[test]
#[should_panic(expected: ('Account: invalid signature',))]
fn test_validate_deploy_empty_signature() {
    let (account, class_hash) = setup_dispatcher(Option::Some(@SIGNED_TX_DATA(KEY_PAIR)));
    let empty_sig = array![];

    cheat_signature_global(empty_sig.span());
    account.__validate_deploy__(class_hash, SALT, PUBKEY);
}

#[test]
fn test_validate_declare() {
    let (account, class_hash) = setup_dispatcher(Option::Some(@SIGNED_TX_DATA(KEY_PAIR)));

    // `__validate_declare__` does not directly use the class_hash argument. Its
    // value is already integrated in the tx hash. The class_hash argument in this
    // testing context is decoupled from the signature and has no effect on the test.
    let is_valid = account.__validate_declare__(class_hash);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('Account: invalid signature',))]
fn test_validate_declare_invalid_signature_data() {
    let mut data = SIGNED_TX_DATA(KEY_PAIR);
    data.tx_hash += 1;
    let (account, class_hash) = setup_dispatcher(Option::Some(@data));

    account.__validate_declare__(class_hash);
}

#[test]
#[should_panic(expected: ('Account: invalid signature',))]
fn test_validate_declare_invalid_signature_length() {
    let (account, class_hash) = setup_dispatcher(Option::Some(@SIGNED_TX_DATA(KEY_PAIR)));
    let mut signature = array![];

    signature.append(0x1);
    cheat_signature_global(signature.span());

    account.__validate_declare__(class_hash);
}

#[test]
#[should_panic(expected: ('Account: invalid signature',))]
fn test_validate_declare_empty_signature() {
    let (account, class_hash) = setup_dispatcher(Option::Some(@SIGNED_TX_DATA(KEY_PAIR)));
    let empty_sig = array![];

    cheat_signature_global(empty_sig.span());

    account.__validate_declare__(class_hash);
}

fn test_execute_with_version(version: Option<felt252>) {
    let data = SIGNED_TX_DATA(KEY_PAIR);
    let (account, _) = setup_dispatcher(Option::Some(@data));
    let erc20 = deploy_erc20(account.contract_address, 1000);
    let recipient = contract_address_const::<0x123>();

    // Craft call and add to calls array
    let mut calldata = array![];
    let amount: u256 = 200;
    calldata.append_serde(recipient);
    calldata.append_serde(amount);
    let call = Call {
        to: erc20.contract_address, selector: selectors::transfer, calldata: calldata.span()
    };
    let calls = array![call];

    // Handle version for test
    if let Option::Some(version) = version {
        cheat_transaction_version_global(version);
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
    let calls = array![];
    let (account, _) = setup_dispatcher(Option::Some(@SIGNED_TX_DATA(KEY_PAIR)));

    let is_valid = account.__validate__(calls);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('Account: invalid signature',))]
fn test_validate_invalid() {
    let calls = array![];
    let mut data = SIGNED_TX_DATA(KEY_PAIR);
    data.tx_hash += 1;
    let (account, _) = setup_dispatcher(Option::Some(@data));

    account.__validate__(calls);
}

#[test]
fn test_multicall() {
    let (account, _) = setup_dispatcher(Option::Some(@SIGNED_TX_DATA(KEY_PAIR)));
    let erc20 = deploy_erc20(account.contract_address, 1000);
    let recipient1 = contract_address_const::<0x123>();
    let recipient2 = contract_address_const::<0x456>();

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

    // Bundle calls and exeute
    let calls = array![call1, call2];
    let ret = account.__execute__(calls);

    // Assert that the transfers were successful
    assert_eq!(erc20.balance_of(account.contract_address), 200, "Should have remainder");
    assert_eq!(erc20.balance_of(recipient1), 300, "Should have transferred from call1");
    assert_eq!(erc20.balance_of(recipient2), 500, "Should have transferred from call2");

    // Test return values
    let mut call1_serialized_retval = *ret.at(0);
    let mut call2_serialized_retval = *ret.at(1);

    let call1_retval = Serde::<bool>::deserialize(ref call1_serialized_retval);
    assert!(call1_retval.unwrap());

    let call2_retval = Serde::<bool>::deserialize(ref call2_serialized_retval);
    assert!(call2_retval.unwrap());
}

#[test]
fn test_multicall_zero_calls() {
    let (account, _) = setup_dispatcher(Option::Some(@SIGNED_TX_DATA(KEY_PAIR)));
    let calls = array![];

    let response = account.__execute__(calls);
    assert!(response.is_empty());
}

#[test]
#[should_panic(expected: ('Account: invalid caller',))]
fn test_account_called_from_contract() {
    let state = setup();
    let calls = array![];
    let account_address = test_address();

    start_cheat_caller_address(account_address, CALLER());

    state.__execute__(calls);
}

//
// set_public_key & get_public_key
//

#[test]
fn test_public_key_setter_and_getter() {
    let mut state = COMPONENT_STATE();
    let account_address = test_address();
    start_cheat_caller_address(account_address, account_address);

    state._set_public_key(PUBKEY);
    let public_key = state.get_public_key();
    assert_eq!(public_key, PUBKEY);
    let mut spy = spy_events();

    // Set key
    let signature = get_accept_ownership_signature(account_address, PUBKEY, KEY_PAIR_2);
    state.set_public_key(PUBKEY_2, signature);

    spy.assert_event_owner_removed(account_address, PUBKEY);
    spy.assert_only_event_owner_added(account_address, PUBKEY_2);

    let public_key = state.get_public_key();
    assert_eq!(public_key, PUBKEY_2);
}

#[test]
#[should_panic(expected: ('Account: unauthorized',))]
fn test_public_key_setter_different_account() {
    let mut state = COMPONENT_STATE();
    let account_address = test_address();
    start_cheat_caller_address(account_address, CALLER());

    state.set_public_key(PUBKEY_2, array![].span());
}

//
// setPublicKey & getPublicKey
//

#[test]
fn test_public_key_setter_and_getter_camel() {
    let mut state = COMPONENT_STATE();
    let account_address = test_address();
    start_cheat_caller_address(account_address, account_address);

    state._set_public_key(PUBKEY);
    let public_key = state.getPublicKey();
    assert_eq!(public_key, PUBKEY);
    let mut spy = spy_events();

    // Set key
    let signature = get_accept_ownership_signature(account_address, PUBKEY, KEY_PAIR_2);
    state.setPublicKey(PUBKEY_2, signature);

    spy.assert_event_owner_removed(account_address, PUBKEY);
    spy.assert_only_event_owner_added(account_address, PUBKEY_2);

    let public_key = state.getPublicKey();
    assert_eq!(public_key, PUBKEY_2);
}

#[test]
#[should_panic(expected: ('Account: unauthorized',))]
fn test_public_key_setter_different_account_camel() {
    let mut state = COMPONENT_STATE();
    let account_address = test_address();
    start_cheat_caller_address(account_address, CALLER());

    state.setPublicKey(PUBKEY_2, array![].span());
}

//
// Test internals
//

#[test]
fn test_initializer() {
    let mut state = COMPONENT_STATE();
    let mock_state = CONTRACT_STATE();
    let account_address = test_address();
    let mut spy = spy_events();

    state.initializer(PUBKEY);
    spy.assert_only_event_owner_added(account_address, PUBKEY);

    let public_key = state.get_public_key();
    assert_eq!(public_key, PUBKEY);

    let supports_isrc5 = mock_state.supports_interface(ISRC5_ID);
    assert!(supports_isrc5);

    let supports_isrc6 = mock_state.supports_interface(ISRC6_ID);
    assert!(supports_isrc6);
}

#[test]
fn test_assert_only_self_true() {
    let mut state = COMPONENT_STATE();
    let account_address = test_address();
    start_cheat_caller_address(account_address, account_address);

    state.assert_only_self();
}

#[test]
#[should_panic(expected: ('Account: unauthorized',))]
fn test_assert_only_self_false() {
    let mut state = COMPONENT_STATE();
    let account_address = test_address();
    start_cheat_caller_address(account_address, OTHER());

    state.assert_only_self();
}

#[test]
fn test_assert_valid_new_owner() {
    let state = setup();
    let account_address = test_address();
    let signature = get_accept_ownership_signature(account_address, PUBKEY, KEY_PAIR_2);

    state.assert_valid_new_owner(PUBKEY, PUBKEY_2, signature);
}


#[test]
#[should_panic(expected: ('Account: invalid signature',))]
fn test_assert_valid_new_owner_invalid_signature() {
    let state = setup();
    let bad_signature = array!['BAD', 'SIGNATURE'];

    state.assert_valid_new_owner(PUBKEY, PUBKEY_2, bad_signature.span());
}

#[test]
fn test__is_valid_signature() {
    let mut state = COMPONENT_STATE();
    let data = SIGNED_TX_DATA(KEY_PAIR);

    state._set_public_key(data.public_key);

    let good_signature = array![data.r, data.s];
    assert!(state._is_valid_signature(data.tx_hash, good_signature.span()));

    let bad_signature = array!['BAD', 'SIGNATURE'];
    assert!(!state._is_valid_signature(data.tx_hash, bad_signature.span()));

    let invalid_length_signature = array!['SINGLE_ELEMENT'];
    assert!(!state._is_valid_signature(data.tx_hash, invalid_length_signature.span()));
}

#[test]
fn test__set_public_key() {
    let mut state = COMPONENT_STATE();
    let mut spy = spy_events();
    let account_address = test_address();

    state._set_public_key(PUBKEY);

    spy.assert_only_event_owner_added(account_address, PUBKEY);

    let public_key = state.get_public_key();
    assert_eq!(public_key, PUBKEY);
}
