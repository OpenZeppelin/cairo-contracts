use openzeppelin_account::EthAccountComponent::{InternalTrait, SRC6CamelOnlyImpl};
use openzeppelin_account::EthAccountComponent::{PublicKeyCamelImpl, PublicKeyImpl};
use openzeppelin_account::EthAccountComponent;
use openzeppelin_account::interface::{EthAccountABIDispatcherTrait, EthAccountABIDispatcher};
use openzeppelin_account::interface::{ISRC6, ISRC6_ID};
use openzeppelin_account::tests::mocks::eth_account_mocks::DualCaseEthAccountMock;
use openzeppelin_account::tests::mocks::simple_mock::SimpleMock;
use openzeppelin_account::tests::mocks::simple_mock::{
    ISimpleMockDispatcher, ISimpleMockDispatcherTrait
};
use openzeppelin_account::utils::secp256k1::{DebugSecp256k1Point, Secp256k1PointPartialEq};
use openzeppelin_account::utils::signature::EthSignature;
use openzeppelin_introspection::interface::{ISRC5, ISRC5_ID};
use openzeppelin_test_common::eth_account::EthAccountSpyHelpers;
use openzeppelin_test_common::eth_account::{
    SIGNED_TX_DATA, SignedTransactionData, get_accept_ownership_signature
};
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::secp256k1::{KEY_PAIR, KEY_PAIR_2};
use openzeppelin_testing::constants::{
    SALT, ZERO, OTHER, RECIPIENT, CALLER, QUERY_VERSION, MIN_TRANSACTION_VERSION
};
use openzeppelin_testing::signing::Secp256k1KeyPair;
use openzeppelin_utils::selectors;
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{
    start_cheat_signature_global, start_cheat_transaction_version_global,
    start_cheat_transaction_hash_global, start_cheat_caller_address
};
use snforge_std::{spy_events, test_address};
use starknet::account::Call;

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

fn setup(key_pair: Secp256k1KeyPair) -> ComponentState {
    let mut state = COMPONENT_STATE();
    state.initializer(key_pair.public_key);
    state
}

fn setup_dispatcher(
    key_pair: Secp256k1KeyPair, data: SignedTransactionData
) -> (EthAccountABIDispatcher, felt252) {
    let mut calldata = array![];
    calldata.append_serde(key_pair.public_key);
    let contract_class = utils::declare_class("DualCaseEthAccountMock");
    let contract_address = utils::deploy(contract_class, calldata);
    let dispatcher = EthAccountABIDispatcher { contract_address };

    let mut serialized_signature = array![];
    data.signature.serialize(ref serialized_signature);
    start_cheat_signature_global(serialized_signature.span());
    start_cheat_transaction_hash_global(data.tx_hash);
    start_cheat_transaction_version_global(MIN_TRANSACTION_VERSION);
    start_cheat_caller_address(contract_address, ZERO());

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
    let mut bad_signature = data.signature;

    bad_signature.r += 1;

    let mut serialized_good_signature = array![];
    let mut serialized_bad_signature = array![];

    data.signature.serialize(ref serialized_good_signature);
    bad_signature.serialize(ref serialized_bad_signature);

    state.initializer(key_pair.public_key);

    let is_valid = state.is_valid_signature(data.tx_hash, serialized_good_signature);
    assert_eq!(is_valid, starknet::VALIDATED);

    let is_valid = state.is_valid_signature(data.tx_hash, serialized_bad_signature);
    assert_eq!(is_valid, 0, "Should reject invalid signature");
}

#[test]
fn test_isValidSignature() {
    let mut state = COMPONENT_STATE();
    let key_pair = KEY_PAIR();
    let data = SIGNED_TX_DATA(key_pair);

    let mut bad_signature = data.signature;

    bad_signature.r += 1;

    let mut serialized_good_signature = array![];
    let mut serialized_bad_signature = array![];

    data.signature.serialize(ref serialized_good_signature);
    bad_signature.serialize(ref serialized_bad_signature);

    state.initializer(key_pair.public_key);

    let is_valid = state.isValidSignature(data.tx_hash, serialized_good_signature);
    assert_eq!(is_valid, starknet::VALIDATED);

    let is_valid = state.isValidSignature(data.tx_hash, serialized_bad_signature);
    assert_eq!(is_valid, 0, "Should reject invalid signature");
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
#[should_panic(expected: ('EthAccount: invalid signature',))]
fn test_validate_deploy_invalid_signature_data() {
    let key_pair = KEY_PAIR();
    let mut data = SIGNED_TX_DATA(key_pair);
    data.tx_hash += 1;
    let (account, class_hash) = setup_dispatcher(key_pair, data);

    account.__validate_deploy__(class_hash, SALT, key_pair.public_key);
}

#[test]
#[should_panic(expected: ('Signature: Invalid format.',))]
fn test_validate_deploy_invalid_signature_length() {
    let key_pair = KEY_PAIR();
    let (account, class_hash) = setup_dispatcher(key_pair, SIGNED_TX_DATA(key_pair));

    let invalid_len_sig = array!['INVALID_LEN'];
    start_cheat_signature_global(invalid_len_sig.span());

    account.__validate_deploy__(class_hash, SALT, key_pair.public_key);
}

#[test]
#[should_panic(expected: ('Signature: Invalid format.',))]
fn test_validate_deploy_empty_signature() {
    let key_pair = KEY_PAIR();
    let (account, class_hash) = setup_dispatcher(key_pair, SIGNED_TX_DATA(key_pair));
    let empty_sig = array![];

    start_cheat_signature_global(empty_sig.span());
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
#[should_panic(expected: ('EthAccount: invalid signature',))]
fn test_validate_declare_invalid_signature_data() {
    let key_pair = KEY_PAIR();
    let mut data = SIGNED_TX_DATA(key_pair);
    data.tx_hash += 1;
    let (account, class_hash) = setup_dispatcher(key_pair, data);

    account.__validate_declare__(class_hash);
}

#[test]
#[should_panic(expected: ('Signature: Invalid format.',))]
fn test_validate_declare_invalid_signature_length() {
    let key_pair = KEY_PAIR();
    let (account, class_hash) = setup_dispatcher(key_pair, SIGNED_TX_DATA(key_pair));

    let invalid_len_sig = array!['INVALID_LEN'];
    start_cheat_signature_global(invalid_len_sig.span());

    account.__validate_declare__(class_hash);
}

#[test]
#[should_panic(expected: ('Signature: Invalid format.',))]
fn test_validate_declare_empty_signature() {
    let key_pair = KEY_PAIR();
    let (account, class_hash) = setup_dispatcher(key_pair, SIGNED_TX_DATA(key_pair));
    let empty_sig = array![];

    start_cheat_signature_global(empty_sig.span());

    account.__validate_declare__(class_hash);
}

fn test_execute_with_version(version: Option<felt252>) {
    let key_pair = KEY_PAIR();
    let data = SIGNED_TX_DATA(key_pair);
    let (account, _) = setup_dispatcher(key_pair, data);

    // Deploy target contract
    let calldata = array![];
    let address = utils::declare_and_deploy("SimpleMock", calldata);
    let simple_mock = ISimpleMockDispatcher { contract_address: address };

    // Craft call and add to calls array
    let amount = 200;
    let calldata = array![amount];
    let call = Call {
        to: simple_mock.contract_address,
        selector: selector!("increase_balance"),
        calldata: calldata.span()
    };
    let calls = array![call];

    // Handle version for test
    if let Option::Some(version) = version {
        start_cheat_transaction_version_global(version);
    }

    // Execute
    let ret = account.__execute__(calls);

    // Assert that the call was successful
    assert_eq!(simple_mock.get_balance(), amount);

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
    let key_pair = KEY_PAIR();
    let calls = array![];
    let (account, _) = setup_dispatcher(key_pair, SIGNED_TX_DATA(key_pair));

    let is_valid = account.__validate__(calls);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('EthAccount: invalid signature',))]
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

    // Deploy target contract
    let calldata = array![];
    let address = utils::declare_and_deploy("SimpleMock", calldata);
    let simple_mock = ISimpleMockDispatcher { contract_address: address };

    // Craft 1st call
    let amount1 = 300;
    let calldata1 = array![amount1];
    let call1 = Call {
        to: simple_mock.contract_address,
        selector: selector!("increase_balance"),
        calldata: calldata1.span()
    };

    // Craft 2nd call
    let amount2 = 500;
    let calldata2 = array![amount2];
    let call2 = Call {
        to: simple_mock.contract_address,
        selector: selector!("increase_balance"),
        calldata: calldata2.span()
    };

    // Bundle calls and execute
    let calls = array![call1, call2];
    let ret = account.__execute__(calls);

    // Assert that the txs were successful
    let total_balance = amount1 + amount2;
    assert_eq!(simple_mock.get_balance(), total_balance);

    // Test return value
    let mut call1_serialized_retval = *ret.at(0);
    let call1_retval = Serde::<bool>::deserialize(ref call1_serialized_retval);
    assert!(call1_retval.unwrap());

    let mut call2_serialized_retval = *ret.at(1);
    let call2_retval = Serde::<bool>::deserialize(ref call2_serialized_retval);
    assert!(call2_retval.unwrap());
}

#[test]
fn test_multicall_zero_calls() {
    let key_pair = KEY_PAIR();
    let (account, _) = setup_dispatcher(key_pair, SIGNED_TX_DATA(key_pair));
    let calls = array![];

    let ret = account.__execute__(calls);

    // Test return value
    assert_eq!(ret.len(), 0, "Should have an empty response");
}

#[test]
#[should_panic(expected: ('EthAccount: invalid caller',))]
fn test_account_called_from_contract() {
    let key_pair = KEY_PAIR();
    let state = setup(key_pair);

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
    let state = COMPONENT_STATE();
    state.get_public_key();
}

#[test]
#[should_panic(expected: ('Secp256k1Point: Invalid point.',))]
fn test_cannot_set_without_initialize() {
    let key_pair = KEY_PAIR();
    let mut state = COMPONENT_STATE();

    start_cheat_caller_address(test_address(), test_address());
    state.set_public_key(key_pair.public_key, array![].span());
}

#[test]
fn test_public_key_setter_and_getter() {
    let mut state = COMPONENT_STATE();
    let key_pair = KEY_PAIR();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, contract_address);
    state.initializer(key_pair.public_key);

    // Check default
    assert_eq!(state.get_public_key(), key_pair.public_key);

    // Set key
    let mut spy = spy_events();
    let new_key_pair = KEY_PAIR_2();
    let signature = get_accept_ownership_signature(
        contract_address, key_pair.public_key, new_key_pair
    );
    state.set_public_key(new_key_pair.public_key, signature);

    spy.assert_event_owner_removed(contract_address, key_pair.public_key);
    spy.assert_only_event_owner_added(contract_address, new_key_pair.public_key);

    assert_eq!(state.get_public_key(), new_key_pair.public_key);
}

#[test]
#[should_panic(expected: ('EthAccount: unauthorized',))]
fn test_public_key_setter_different_account() {
    let mut state = COMPONENT_STATE();
    let key_pair = KEY_PAIR();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, CALLER());

    let new_key_pair = KEY_PAIR_2();
    let signature = get_accept_ownership_signature(
        contract_address, key_pair.public_key, new_key_pair
    );
    state.set_public_key(new_key_pair.public_key, signature);
}

//
// setPublicKey & getPublicKey
//

#[test]
fn test_public_key_setter_and_getter_camel() {
    let mut state = COMPONENT_STATE();
    let key_pair = KEY_PAIR();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, contract_address);
    state.initializer(key_pair.public_key);

    assert_eq!(state.getPublicKey(), key_pair.public_key);

    let mut spy = spy_events();
    let new_key_pair = KEY_PAIR_2();
    let signature = get_accept_ownership_signature(
        contract_address, key_pair.public_key, new_key_pair
    );
    state.setPublicKey(new_key_pair.public_key, signature);

    spy.assert_event_owner_removed(contract_address, key_pair.public_key);
    spy.assert_only_event_owner_added(contract_address, new_key_pair.public_key);

    assert_eq!(state.getPublicKey(), new_key_pair.public_key);
}

#[test]
#[should_panic(expected: ('EthAccount: unauthorized',))]
fn test_public_key_setter_different_account_camel() {
    let mut state = COMPONENT_STATE();
    let key_pair = KEY_PAIR();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, CALLER());

    let new_key_pair = KEY_PAIR_2();
    let signature = get_accept_ownership_signature(
        contract_address, key_pair.public_key, new_key_pair
    );
    state.setPublicKey(new_key_pair.public_key, signature);
}

//
// Test internals
//

#[test]
fn test_initializer() {
    let mut state = COMPONENT_STATE();
    let mock_state = CONTRACT_STATE();
    let key_pair = KEY_PAIR();
    let mut spy = spy_events();

    state.initializer(key_pair.public_key);

    spy.assert_only_event_owner_added(test_address(), key_pair.public_key);

    assert_eq!(state.get_public_key(), key_pair.public_key);

    let supports_default_interface = mock_state.supports_interface(ISRC5_ID);
    assert!(supports_default_interface, "Should support ISRC5");

    let supports_account_interface = mock_state.supports_interface(ISRC6_ID);
    assert!(supports_account_interface, "Should support ISRC6");
}

#[test]
fn test_assert_only_self_true() {
    let state = COMPONENT_STATE();

    start_cheat_caller_address(test_address(), test_address());
    state.assert_only_self();
}

#[test]
#[should_panic(expected: ('EthAccount: unauthorized',))]
fn test_assert_only_self_false() {
    let state = COMPONENT_STATE();

    start_cheat_caller_address(test_address(), OTHER());
    state.assert_only_self();
}

#[test]
fn test_assert_valid_new_owner() {
    let key_pair = KEY_PAIR();
    let state = setup(key_pair);
    let contract_address = test_address();

    let new_key_pair = KEY_PAIR_2();
    let signature = get_accept_ownership_signature(
        contract_address, key_pair.public_key, new_key_pair
    );

    state.assert_valid_new_owner(key_pair.public_key, new_key_pair.public_key, signature);
}

#[test]
#[should_panic(expected: ('EthAccount: invalid signature',))]
fn test_assert_valid_new_owner_invalid_signature() {
    let key_pair = KEY_PAIR();
    let state = setup(key_pair);

    start_cheat_caller_address(test_address(), test_address());
    let mut bad_signature = array![];
    EthSignature { r: 'BAD'.into(), s: 'SIG'.into() }.serialize(ref bad_signature);
    let new_key_pair = KEY_PAIR_2();

    state
        .assert_valid_new_owner(key_pair.public_key, new_key_pair.public_key, bad_signature.span());
}

#[test]
fn test__is_valid_signature() {
    let key_pair = KEY_PAIR();
    let mut state = COMPONENT_STATE();
    let data = SIGNED_TX_DATA(key_pair);

    let mut bad_signature = data.signature;

    bad_signature.r += 1;

    let mut serialized_good_signature = array![];
    let mut serialized_bad_signature = array![];

    data.signature.serialize(ref serialized_good_signature);
    bad_signature.serialize(ref serialized_bad_signature);

    state.initializer(key_pair.public_key);

    let is_valid = state._is_valid_signature(data.tx_hash, serialized_good_signature.span());
    assert!(is_valid);

    let is_not_valid = !state._is_valid_signature(data.tx_hash, serialized_bad_signature.span());
    assert!(is_not_valid);
}

#[test]
fn test__set_public_key() {
    let key_pair = KEY_PAIR();
    let mut state = COMPONENT_STATE();
    let mut spy = spy_events();

    state._set_public_key(key_pair.public_key);

    spy.assert_only_event_owner_added(test_address(), key_pair.public_key);

    assert_eq!(state.get_public_key(), key_pair.public_key);
}
