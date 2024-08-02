use core::num::traits::Zero;
use core::starknet::SyscallResultTrait;
use openzeppelin_account::AccountComponent::{InternalTrait, SRC6CamelOnlyImpl};
use openzeppelin_account::AccountComponent::{PublicKeyCamelImpl, PublicKeyImpl};
use openzeppelin_account::AccountComponent;
use openzeppelin_account::interface::{AccountABIDispatcherTrait, AccountABIDispatcher};
use openzeppelin_account::interface::{ISRC6, ISRC6_ID};
use openzeppelin_account::tests::mocks::account_mocks::DualCaseAccountMock;
use openzeppelin_introspection::interface::{ISRC5, ISRC5_ID};
use openzeppelin_token::erc20::interface::IERC20DispatcherTrait;
use openzeppelin_utils::selectors;
use openzeppelin_utils::serde::SerializedAppend;
use openzeppelin_utils::test_utils as utils;
use openzeppelin_utils::test_utils::constants::stark::{KEY_PAIR, KEY_PAIR_2};
use openzeppelin_utils::test_utils::constants::{
    SALT, ZERO, OTHER, CALLER, RECIPIENT, QUERY_OFFSET, QUERY_VERSION, MIN_TRANSACTION_VERSION
};
use openzeppelin_utils::test_utils::signing::StarkKeyPair;
use snforge_std::{
    cheat_signature_global, cheat_transaction_version_global, cheat_transaction_hash_global
};
use snforge_std::{spy_events, declare, test_address, start_cheat_caller_address};
use starknet::account::Call;
use starknet::{contract_address_const, ContractAddress, ClassHash};

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

fn setup(key_pair: StarkKeyPair) -> ComponentState {
    let mut state = COMPONENT_STATE();
    state.initializer(key_pair.public_key);
    state
}

fn setup_dispatcher(
    key_pair: StarkKeyPair, data: SignedTransactionData
) -> (AccountABIDispatcher, felt252) {
    let contract_class = declare("DualCaseAccountMock").unwrap_syscall();
    let calldata = array![key_pair.public_key];
    let address = utils::deploy(contract_class, calldata);
    let dispatcher = AccountABIDispatcher { contract_address: address };

    cheat_signature_global(array![data.r, data.s].span());
    cheat_transaction_hash_global(data.tx_hash);
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
    let key_pair = KEY_PAIR();
    let data = SIGNED_TX_DATA(key_pair);

    state._set_public_key(key_pair.public_key);

    let good_signature = array![data.r, data.s];
    let is_valid = state.is_valid_signature(data.tx_hash, good_signature);
    assert_eq!(is_valid, starknet::VALIDATED);

    let bad_signature = array!['BAD', 'SIGNATURE'];
    let is_valid = state.is_valid_signature(data.tx_hash, bad_signature);
    assert!(is_valid.is_zero(), "Should reject invalid signature");
}

#[test]
fn test_isValidSignature() {
    let mut state = COMPONENT_STATE();
    let key_pair = KEY_PAIR();
    let data = SIGNED_TX_DATA(key_pair);

    state._set_public_key(key_pair.public_key);

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
    let key_pair = KEY_PAIR();
    let (account, class_hash) = setup_dispatcher(key_pair, SIGNED_TX_DATA(key_pair));

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
    let (account, class_hash) = setup_dispatcher(key_pair, data);

    account.__validate_deploy__(class_hash, SALT, key_pair.public_key);
}

#[test]
#[should_panic(expected: ('Account: invalid signature',))]
fn test_validate_deploy_invalid_signature_length() {
    let key_pair = KEY_PAIR();
    let (account, class_hash) = setup_dispatcher(key_pair, SIGNED_TX_DATA(key_pair));
    let invalid_len_sig = array!['INVALID_LEN_SIG'];
    cheat_signature_global(invalid_len_sig.span());

    account.__validate_deploy__(class_hash, SALT, key_pair.public_key);
}

#[test]
#[should_panic(expected: ('Account: invalid signature',))]
fn test_validate_deploy_empty_signature() {
    let key_pair = KEY_PAIR();
    let (account, class_hash) = setup_dispatcher(key_pair, SIGNED_TX_DATA(key_pair));
    let empty_sig = array![];

    cheat_signature_global(empty_sig.span());
    account.__validate_deploy__(class_hash, SALT, key_pair.public_key);
}

#[test]
fn test_validate_declare() {
    let key_pair = KEY_PAIR();
    let (account, class_hash) = setup_dispatcher(key_pair, SIGNED_TX_DATA(key_pair));

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
    let (account, class_hash) = setup_dispatcher(key_pair, data);

    account.__validate_declare__(class_hash);
}

#[test]
#[should_panic(expected: ('Account: invalid signature',))]
fn test_validate_declare_invalid_signature_length() {
    let key_pair = KEY_PAIR();
    let (account, class_hash) = setup_dispatcher(key_pair, SIGNED_TX_DATA(key_pair));
    let invalid_len_sig = array!['INVALID_LEN_SIG'];
    cheat_signature_global(invalid_len_sig.span());

    account.__validate_declare__(class_hash);
}

#[test]
#[should_panic(expected: ('Account: invalid signature',))]
fn test_validate_declare_empty_signature() {
    let key_pair = KEY_PAIR();
    let (account, class_hash) = setup_dispatcher(key_pair, SIGNED_TX_DATA(key_pair));
    let empty_sig = array![];
    cheat_signature_global(empty_sig.span());

    account.__validate_declare__(class_hash);
}

fn test_execute_with_version(version: Option<felt252>) {
    let key_pair = KEY_PAIR();
    let (account, _) = setup_dispatcher(key_pair, SIGNED_TX_DATA(key_pair));
    let erc20 = deploy_erc20(account.contract_address, 1000);
    let recipient = RECIPIENT();

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
    let key_pair = KEY_PAIR();
    let (account, _) = setup_dispatcher(key_pair, SIGNED_TX_DATA(key_pair));
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
    let (account, _) = setup_dispatcher(key_pair, data);
    let calls = array![];

    account.__validate__(calls);
}

#[test]
fn test_multicall() {
    let key_pair = KEY_PAIR();
    let (account, _) = setup_dispatcher(key_pair, SIGNED_TX_DATA(key_pair));
    let erc20 = deploy_erc20(account.contract_address, 1000);
    let recipient1 = RECIPIENT();
    let recipient2 = OTHER();

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
    let key_pair = KEY_PAIR();
    let (account, _) = setup_dispatcher(key_pair, SIGNED_TX_DATA(key_pair));
    let calls = array![];

    let response = account.__execute__(calls);
    assert!(response.is_empty());
}

#[test]
#[should_panic(expected: ('Account: invalid caller',))]
fn test_account_called_from_contract() {
    let state = setup(KEY_PAIR());
    let account_address = test_address();
    let calls = array![];

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
    let key_pair = KEY_PAIR();
    let new_key_pair = KEY_PAIR_2();
    start_cheat_caller_address(account_address, account_address);

    state._set_public_key(key_pair.public_key);
    assert_eq!(state.get_public_key(), key_pair.public_key);

    // Set key
    let mut spy = spy_events();
    let signature = get_accept_ownership_signature(
        account_address, key_pair.public_key, new_key_pair
    );
    state.set_public_key(new_key_pair.public_key, signature);

    spy.assert_event_owner_removed(account_address, key_pair.public_key);
    spy.assert_only_event_owner_added(account_address, new_key_pair.public_key);

    assert_eq!(state.get_public_key(), new_key_pair.public_key);
}

#[test]
#[should_panic(expected: ('Account: unauthorized',))]
fn test_public_key_setter_different_account() {
    let mut state = COMPONENT_STATE();
    let account_address = test_address();
    let new_public_key = KEY_PAIR_2().public_key;
    start_cheat_caller_address(account_address, CALLER());

    state.set_public_key(new_public_key, array![].span());
}

//
// setPublicKey & getPublicKey
//

#[test]
fn test_public_key_setter_and_getter_camel() {
    let mut state = COMPONENT_STATE();
    let account_address = test_address();
    let key_pair = KEY_PAIR();
    let new_key_pair = KEY_PAIR_2();
    start_cheat_caller_address(account_address, account_address);

    state._set_public_key(key_pair.public_key);
    assert_eq!(state.getPublicKey(), key_pair.public_key);

    // Set key
    let mut spy = spy_events();
    let signature = get_accept_ownership_signature(
        account_address, key_pair.public_key, new_key_pair
    );
    state.setPublicKey(new_key_pair.public_key, signature);

    spy.assert_event_owner_removed(account_address, key_pair.public_key);
    spy.assert_only_event_owner_added(account_address, new_key_pair.public_key);

    assert_eq!(state.getPublicKey(), new_key_pair.public_key);
}

#[test]
#[should_panic(expected: ('Account: unauthorized',))]
fn test_public_key_setter_different_account_camel() {
    let mut state = COMPONENT_STATE();
    let account_address = test_address();
    let new_public_key = KEY_PAIR_2().public_key;
    start_cheat_caller_address(account_address, CALLER());

    state.setPublicKey(new_public_key, array![].span());
}

//
// Test internals
//

#[test]
fn test_initializer() {
    let mut state = COMPONENT_STATE();
    let mock_state = CONTRACT_STATE();
    let account_address = test_address();
    let public_key = KEY_PAIR().public_key;
    let mut spy = spy_events();

    state.initializer(public_key);
    spy.assert_only_event_owner_added(account_address, public_key);

    assert_eq!(state.get_public_key(), public_key);

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
    let key_pair = KEY_PAIR();
    let state = setup(key_pair);
    let account_address = test_address();

    let new_key_pair = KEY_PAIR_2();
    let signature = get_accept_ownership_signature(
        account_address, key_pair.public_key, new_key_pair
    );

    state.assert_valid_new_owner(key_pair.public_key, new_key_pair.public_key, signature);
}


#[test]
#[should_panic(expected: ('Account: invalid signature',))]
fn test_assert_valid_new_owner_invalid_signature() {
    let key_pair = KEY_PAIR();
    let state = setup(key_pair);

    let new_key_pair = KEY_PAIR_2();
    let bad_signature = array!['BAD', 'SIGNATURE'];

    state
        .assert_valid_new_owner(key_pair.public_key, new_key_pair.public_key, bad_signature.span());
}

#[test]
fn test__is_valid_signature() {
    let mut state = COMPONENT_STATE();
    let key_pair = KEY_PAIR();
    let data = SIGNED_TX_DATA(key_pair);

    state._set_public_key(key_pair.public_key);

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
    let public_key = KEY_PAIR().public_key;
    let account_address = test_address();

    state._set_public_key(public_key);

    spy.assert_only_event_owner_added(account_address, public_key);
    assert_eq!(state.get_public_key(), public_key);
}
