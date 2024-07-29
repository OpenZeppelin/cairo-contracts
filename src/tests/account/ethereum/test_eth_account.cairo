use core::starknet::SyscallResultTrait;
use openzeppelin::account::EthAccountComponent::{InternalTrait, SRC6CamelOnlyImpl};
use openzeppelin::account::EthAccountComponent::{PublicKeyCamelImpl, PublicKeyImpl};
use openzeppelin::account::EthAccountComponent;
use openzeppelin::account::interface::{EthAccountABIDispatcherTrait, EthAccountABIDispatcher};
use openzeppelin::account::interface::{ISRC6, ISRC6_ID};
use openzeppelin::account::utils::secp256k1::{
    DebugSecp256k1Point, Secp256k1PointPartialEq, Secp256k1PointSerde
};
use openzeppelin::account::utils::signature::EthSignature;
use openzeppelin::introspection::interface::{ISRC5, ISRC5_ID};
use openzeppelin::tests::mocks::eth_account_mocks::DualCaseEthAccountMock;
use openzeppelin::tests::utils::constants::secp256k1::KEY_PAIR;
use openzeppelin::tests::utils::constants::{
    ETH_PUBKEY, NEW_ETH_PUBKEY, SALT, ZERO, OTHER, RECIPIENT, CALLER, QUERY_VERSION,
    MIN_TRANSACTION_VERSION
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::interface::IERC20DispatcherTrait;
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::{
    cheat_signature_global, cheat_transaction_version_global, cheat_transaction_hash_global,
    start_cheat_caller_address
};
use snforge_std::{spy_events, test_address};
use starknet::ContractAddress;
use starknet::account::Call;

use super::common::EthAccountSpyHelpers;
use super::common::{
    deploy_erc20, SIGNED_TX_DATA, SignedTransactionData, get_accept_ownership_signature
};

//
// Setup
//

type ComponentState = EthAccountComponent::ComponentState<DualCaseEthAccountMock::ContractState>;

fn CONTRACT_STATE() -> DualCaseEthAccountMock::ContractState {
    DualCaseEthAccountMock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    EthAccountComponent::component_state_for_testing()
}

fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    state.initializer(ETH_PUBKEY());
    state
}

fn setup_dispatcher(data: Option<@SignedTransactionData>) -> (EthAccountABIDispatcher, felt252) {
    let mut calldata = array![];
    if let Option::Some(data) = data {
        let mut serialized_signature = array![];
        data.signature.serialize(ref serialized_signature);

        cheat_signature_global(serialized_signature.span());
        cheat_transaction_hash_global(*data.tx_hash);

        calldata.append_serde(*data.public_key);
    } else {
        calldata.append_serde(ETH_PUBKEY());
    };

    let contract_class = utils::declare_class("DualCaseEthAccountMock");
    let address = utils::deploy(contract_class, calldata);
    let dispatcher = EthAccountABIDispatcher { contract_address: address };

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
    let data = SIGNED_TX_DATA(KEY_PAIR());
    let hash = data.tx_hash;
    let mut bad_signature = data.signature;

    bad_signature.r += 1;

    let mut serialized_good_signature = array![];
    let mut serialized_bad_signature = array![];

    data.signature.serialize(ref serialized_good_signature);
    bad_signature.serialize(ref serialized_bad_signature);

    state.initializer(data.public_key);

    let is_valid = state.is_valid_signature(hash, serialized_good_signature);
    assert_eq!(is_valid, starknet::VALIDATED);

    let is_valid = state.is_valid_signature(hash, serialized_bad_signature);
    assert_eq!(is_valid, 0, "Should reject invalid signature");
}

#[test]
fn test_isValidSignature() {
    let mut state = COMPONENT_STATE();
    let data = SIGNED_TX_DATA(KEY_PAIR());
    let hash = data.tx_hash;

    let mut bad_signature = data.signature;

    bad_signature.r += 1;

    let mut serialized_good_signature = array![];
    let mut serialized_bad_signature = array![];

    data.signature.serialize(ref serialized_good_signature);
    bad_signature.serialize(ref serialized_bad_signature);

    state.initializer(data.public_key);

    let is_valid = state.isValidSignature(hash, serialized_good_signature);
    assert_eq!(is_valid, starknet::VALIDATED);

    let is_valid = state.isValidSignature(hash, serialized_bad_signature);
    assert_eq!(is_valid, 0, "Should reject invalid signature");
}

//
// Entry points
//

#[test]
fn test_validate_deploy() {
    let (account, class_hash) = setup_dispatcher(Option::Some(@SIGNED_TX_DATA(KEY_PAIR())));

    // `__validate_deploy__` does not directly use the passed arguments. Their
    // values are already integrated in the tx hash. The passed arguments in this
    // testing context are decoupled from the signature and have no effect on the test.
    let is_valid = account.__validate_deploy__(class_hash, SALT, ETH_PUBKEY());
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('EthAccount: invalid signature',))]
fn test_validate_deploy_invalid_signature_data() {
    let mut data = SIGNED_TX_DATA(KEY_PAIR());
    data.tx_hash += 1;
    let (account, class_hash) = setup_dispatcher(Option::Some(@data));

    account.__validate_deploy__(class_hash, SALT, ETH_PUBKEY());
}

#[test]
#[should_panic(expected: ('Signature: Invalid format.',))]
fn test_validate_deploy_invalid_signature_length() {
    let (account, class_hash) = setup_dispatcher(Option::Some(@SIGNED_TX_DATA(KEY_PAIR())));
    let signature = array![0x1];

    cheat_signature_global(signature.span());

    account.__validate_deploy__(class_hash, SALT, ETH_PUBKEY());
}

#[test]
#[should_panic(expected: ('Signature: Invalid format.',))]
fn test_validate_deploy_empty_signature() {
    let (account, class_hash) = setup_dispatcher(Option::Some(@SIGNED_TX_DATA(KEY_PAIR())));
    let empty_sig = array![];

    cheat_signature_global(empty_sig.span());
    account.__validate_deploy__(class_hash, SALT, ETH_PUBKEY());
}

#[test]
fn test_validate_declare() {
    let (account, class_hash) = setup_dispatcher(Option::Some(@SIGNED_TX_DATA(KEY_PAIR())));

    // `__validate_declare__` does not directly use the class_hash argument. Its
    // value is already integrated in the tx hash. The class_hash argument in this
    // testing context is decoupled from the signature and has no effect on the test.
    let is_valid = account.__validate_declare__(class_hash);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('EthAccount: invalid signature',))]
fn test_validate_declare_invalid_signature_data() {
    let mut data = SIGNED_TX_DATA(KEY_PAIR());
    data.tx_hash += 1;
    let (account, class_hash) = setup_dispatcher(Option::Some(@data));

    account.__validate_declare__(class_hash);
}

#[test]
#[should_panic(expected: ('Signature: Invalid format.',))]
fn test_validate_declare_invalid_signature_length() {
    let (account, class_hash) = setup_dispatcher(Option::Some(@SIGNED_TX_DATA(KEY_PAIR())));
    let mut signature = array![];

    signature.append(0x1);
    cheat_signature_global(signature.span());

    account.__validate_declare__(class_hash);
}

#[test]
#[should_panic(expected: ('Signature: Invalid format.',))]
fn test_validate_declare_empty_signature() {
    let (account, class_hash) = setup_dispatcher(Option::Some(@SIGNED_TX_DATA(KEY_PAIR())));
    let empty_sig = array![];

    cheat_signature_global(empty_sig.span());

    account.__validate_declare__(class_hash);
}

fn test_execute_with_version(version: Option<felt252>) {
    let data = SIGNED_TX_DATA(KEY_PAIR());
    let (account, _) = setup_dispatcher(Option::Some(@data));
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
    let mut calls = array![];
    calls.append(call);

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
    test_execute_with_version(Option::None(()));
}

#[test]
fn test_execute_query_version() {
    test_execute_with_version(Option::Some(QUERY_VERSION));
}

#[test]
#[should_panic(expected: ('EthAccount: invalid tx version',))]
fn test_execute_invalid_version() {
    test_execute_with_version(Option::Some(MIN_TRANSACTION_VERSION - 1));
}

#[test]
fn test_validate() {
    let calls = array![];
    let (account, _) = setup_dispatcher(Option::Some(@SIGNED_TX_DATA(KEY_PAIR())));

    let is_valid = account.__validate__(calls);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('EthAccount: invalid signature',))]
fn test_validate_invalid() {
    let calls = array![];
    let mut data = SIGNED_TX_DATA(KEY_PAIR());
    data.tx_hash += 1;
    let (account, _) = setup_dispatcher(Option::Some(@data));

    account.__validate__(calls);
}

#[test]
fn test_multicall() {
    let (account, _) = setup_dispatcher(Option::Some(@SIGNED_TX_DATA(KEY_PAIR())));
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
    assert_eq!(erc20.balance_of(recipient1), 300, "Should have transferred in call 1");
    assert_eq!(erc20.balance_of(recipient2), 500, "Should have transferred in call 2");

    // Test return value
    let mut call1_serialized_retval = *ret.at(0);
    let mut call2_serialized_retval = *ret.at(1);
    let call1_retval = Serde::<bool>::deserialize(ref call1_serialized_retval);
    let call2_retval = Serde::<bool>::deserialize(ref call2_serialized_retval);
    assert!(call1_retval.unwrap());
    assert!(call2_retval.unwrap());
}

#[test]
fn test_multicall_zero_calls() {
    let (account, _) = setup_dispatcher(Option::Some(@SIGNED_TX_DATA(KEY_PAIR())));
    let mut calls = array![];

    let ret = account.__execute__(calls);

    // Test return value
    assert_eq!(ret.len(), 0, "Should have an empty response");
}

#[test]
#[should_panic(expected: ('EthAccount: invalid caller',))]
fn test_account_called_from_contract() {
    let state = setup();
    let calls = array![];

    start_cheat_caller_address(test_address(), CALLER());
    state.__execute__(calls);
}

//
// set_public_key & get_public_key
//

#[test]
#[should_panic(expected: ('Secp256k1Point: Invalid point.',))]
fn test_cannot_get_without_initialize() {
    let mut state = COMPONENT_STATE();
    state.get_public_key();
}

#[test]
#[should_panic(expected: ('Secp256k1Point: Invalid point.',))]
fn test_cannot_set_without_initialize() {
    let mut state = COMPONENT_STATE();

    start_cheat_caller_address(test_address(), test_address());
    state.set_public_key(NEW_ETH_PUBKEY(), array![].span());
}

#[test]
fn test_public_key_setter_and_getter() {
    let mut state = COMPONENT_STATE();
    let public_key = ETH_PUBKEY();
    let key_pair = KEY_PAIR();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, contract_address);
    state.initializer(public_key);

    // Check default
    let current = state.get_public_key();
    assert_eq!(current, public_key);

    let mut spy = spy_events();

    // Set key
    let signature = get_accept_ownership_signature(contract_address, ETH_PUBKEY(), key_pair);
    state.set_public_key(key_pair.public_key, signature);

    spy.assert_event_owner_removed(contract_address, current);
    spy.assert_only_event_owner_added(contract_address, key_pair.public_key);

    let public_key = state.get_public_key();
    assert_eq!(public_key, key_pair.public_key);
}

#[test]
#[should_panic(expected: ('EthAccount: unauthorized',))]
fn test_public_key_setter_different_account() {
    let mut state = COMPONENT_STATE();
    let key_pair = KEY_PAIR();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, CALLER());

    let signature = get_accept_ownership_signature(contract_address, ETH_PUBKEY(), key_pair);
    state.set_public_key(key_pair.public_key, signature);
}

//
// setPublicKey & getPublicKey
//

#[test]
fn test_public_key_setter_and_getter_camel() {
    let mut state = COMPONENT_STATE();
    let public_key = ETH_PUBKEY();
    let key_pair = KEY_PAIR();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, contract_address);
    state.initializer(public_key);

    let current = state.getPublicKey();
    assert_eq!(current, public_key);

    let mut spy = spy_events();

    let signature = get_accept_ownership_signature(contract_address, ETH_PUBKEY(), key_pair);
    state.setPublicKey(key_pair.public_key, signature);

    spy.assert_event_owner_removed(contract_address, public_key);
    spy.assert_only_event_owner_added(contract_address, key_pair.public_key);

    let public_key = state.getPublicKey();
    assert_eq!(public_key, key_pair.public_key);
}

#[test]
#[should_panic(expected: ('EthAccount: unauthorized',))]
fn test_public_key_setter_different_account_camel() {
    let mut state = COMPONENT_STATE();
    let key_pair = KEY_PAIR();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, CALLER());

    let signature = get_accept_ownership_signature(contract_address, ETH_PUBKEY(), key_pair);
    state.setPublicKey(key_pair.public_key, signature);
}

//
// Test internals
//

#[test]
fn test_initializer() {
    let mut state = COMPONENT_STATE();
    let mock_state = CONTRACT_STATE();
    let public_key = ETH_PUBKEY();
    let mut spy = spy_events();

    state.initializer(public_key);

    spy.assert_only_event_owner_added(test_address(), public_key);

    assert_eq!(state.get_public_key(), public_key);

    let supports_default_interface = mock_state.supports_interface(ISRC5_ID);
    assert!(supports_default_interface, "Should support ISRC5");

    let supports_account_interface = mock_state.supports_interface(ISRC6_ID);
    assert!(supports_account_interface, "Should support ISRC6");
}

#[test]
fn test_assert_only_self_true() {
    let mut state = COMPONENT_STATE();

    start_cheat_caller_address(test_address(), test_address());
    state.assert_only_self();
}

#[test]
#[should_panic(expected: ('EthAccount: unauthorized',))]
fn test_assert_only_self_false() {
    let mut state = COMPONENT_STATE();

    start_cheat_caller_address(test_address(), OTHER());
    state.assert_only_self();
}

#[test]
fn test_assert_valid_new_owner() {
    let mut state = setup();
    let contract_address = test_address();

    let key_pair = KEY_PAIR();
    let signature = get_accept_ownership_signature(contract_address, ETH_PUBKEY(), key_pair);

    state.assert_valid_new_owner(ETH_PUBKEY(), key_pair.public_key, signature);
}

#[test]
#[should_panic(expected: ('EthAccount: invalid signature',))]
fn test_assert_valid_new_owner_invalid_signature() {
    let mut state = setup();

    start_cheat_caller_address(test_address(), test_address());
    let mut bad_signature = array![];
    EthSignature {
        r: 0xe2c02fbaa03809019ce6501cb5e57fc4a1e96e09dd8becfde8508ceddb53330b,
        s: 0x6811f854c0f5793a0086f53e4a23c3773fd8afee401b1c4ef148a1554eede5e1,
    }
        .serialize(ref bad_signature);
    state.assert_valid_new_owner(ETH_PUBKEY(), NEW_ETH_PUBKEY(), bad_signature.span());
}

#[test]
fn test__is_valid_signature() {
    let mut state = COMPONENT_STATE();
    let data = SIGNED_TX_DATA(KEY_PAIR());
    let hash = data.tx_hash;

    let mut bad_signature = data.signature;

    bad_signature.r += 1;

    let mut serialized_good_signature = array![];
    let mut serialized_bad_signature = array![];

    data.signature.serialize(ref serialized_good_signature);
    bad_signature.serialize(ref serialized_bad_signature);

    state.initializer(data.public_key);

    let is_valid = state._is_valid_signature(hash, serialized_good_signature.span());
    assert!(is_valid);

    let is_not_valid = !state._is_valid_signature(hash, serialized_bad_signature.span());
    assert!(is_not_valid);
}

#[test]
fn test__set_public_key() {
    let mut state = COMPONENT_STATE();
    let public_key = ETH_PUBKEY();
    let mut spy = spy_events();

    state._set_public_key(public_key);

    spy.assert_only_event_owner_added(test_address(), public_key);

    let public_key = state.get_public_key();
    assert_eq!(public_key, ETH_PUBKEY());
}
