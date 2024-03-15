use core::starknet::secp256_trait::Secp256PointTrait;
use openzeppelin::account::EthAccountComponent::{InternalTrait, SRC6CamelOnlyImpl};
use openzeppelin::account::EthAccountComponent::{OwnerAdded, OwnerRemoved};
use openzeppelin::account::EthAccountComponent::{PublicKeyCamelImpl, PublicKeyImpl};
use openzeppelin::account::EthAccountComponent;
use openzeppelin::account::interface::EthPublicKey;
use openzeppelin::account::interface::{EthAccountABIDispatcherTrait, EthAccountABIDispatcher};
use openzeppelin::account::interface::{ISRC6, ISRC6_ID};
use openzeppelin::account::utils::secp256k1::{
    DebugSecp256k1Point, Secp256k1PointPartialEq, Secp256k1PointSerde
};
use openzeppelin::introspection::interface::{ISRC5, ISRC5_ID};
use openzeppelin::tests::mocks::erc20_mocks::DualCaseERC20Mock;
use openzeppelin::tests::mocks::eth_account_mocks::DualCaseEthAccountMock;
use openzeppelin::tests::utils::constants::{
    ETH_PUBKEY, NEW_ETH_PUBKEY, NAME, SYMBOL, SALT, ZERO, OTHER, RECIPIENT, CALLER, QUERY_VERSION,
    MIN_TRANSACTION_VERSION
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use poseidon::poseidon_hash_span;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;
use starknet::account::Call;
use starknet::eth_signature::Signature;
use starknet::secp256k1::secp256k1_new_syscall;
use starknet::testing;

#[derive(Drop)]
struct SignedTransactionData {
    private_key: u256,
    public_key: EthPublicKey,
    transaction_hash: felt252,
    signature: Signature
}

/// This signature was computed using ethers.js.
fn SIGNED_TX_DATA() -> SignedTransactionData {
    SignedTransactionData {
        private_key: 0x45397ee6ca34cb49060f1c303c6cb7ee2d6123e617601ef3e31ccf7bf5bef1f9,
        public_key: secp256k1_new_syscall(
            0x829307f82a1883c2414503ba85fc85037f22c6fc6f80910801f6b01a4131da1e,
            0x2a23f7bddf3715d11767b1247eccc68c89e11b926e2615268db6ad1af8d8da96
        )
            .unwrap()
            .unwrap(),
        transaction_hash: 0x008f882c63d0396d216d57529fe29ad5e70b6cd51b47bd2458b0a4ccb2ba0957,
        signature: Signature {
            r: 0x82bb3efc0554ec181405468f273b0dbf935cca47182b22da78967d0770f7dcc3,
            s: 0x6719fef30c11c74add873e4da0e1234deb69eae6a6bd4daa44b816dc199f3e86,
            y_parity: true
        }
    }
}

//
// Constants
//

fn CLASS_HASH() -> felt252 {
    DualCaseEthAccountMock::TEST_CLASS_HASH
}

fn ACCOUNT_ADDRESS() -> ContractAddress {
    Zeroable::zero()
}

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
    utils::drop_event(ZERO());
    state
}

fn setup_dispatcher(data: Option<@SignedTransactionData>) -> EthAccountABIDispatcher {
    testing::set_version(MIN_TRANSACTION_VERSION);

    let mut calldata = array![];
    if data.is_some() {
        let data = data.unwrap();
        let mut serialized_signature = array![];
        data.signature.serialize(ref serialized_signature);

        testing::set_signature(serialized_signature.span());
        testing::set_transaction_hash(*data.transaction_hash);

        calldata.append_serde(*data.public_key);
    } else {
        calldata.append_serde(ETH_PUBKEY());
    }
    let address = utils::deploy(CLASS_HASH(), calldata);
    EthAccountABIDispatcher { contract_address: address }
}

fn deploy_erc20(recipient: ContractAddress, initial_supply: u256) -> IERC20Dispatcher {
    let name = NAME();
    let symbol = SYMBOL();
    let mut calldata = array![];

    calldata.append_serde(name);
    calldata.append_serde(symbol);
    calldata.append_serde(initial_supply);
    calldata.append_serde(recipient);

    let address = utils::deploy(DualCaseERC20Mock::TEST_CLASS_HASH, calldata);
    IERC20Dispatcher { contract_address: address }
}

//
// is_valid_signature & isValidSignature
//

#[test]
fn test_is_valid_signature() {
    let mut state = COMPONENT_STATE();
    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;
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
    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;

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
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));

    // `__validate_deploy__` does not directly use the passed arguments. Their
    // values are already integrated in the tx hash. The passed arguments in this
    // testing context are decoupled from the signature and have no effect on the test.
    let is_valid = account.__validate_deploy__(CLASS_HASH(), SALT, ETH_PUBKEY());
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('EthAccount: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_invalid_signature_data() {
    let mut data = SIGNED_TX_DATA();
    data.transaction_hash += 1;
    let account = setup_dispatcher(Option::Some(@data));

    account.__validate_deploy__(CLASS_HASH(), SALT, ETH_PUBKEY());
}

#[test]
#[should_panic(expected: ('Signature: Invalid format.', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_invalid_signature_length() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
    let signature = array![0x1];

    testing::set_signature(signature.span());

    account.__validate_deploy__(CLASS_HASH(), SALT, ETH_PUBKEY());
}

#[test]
#[should_panic(expected: ('Signature: Invalid format.', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_empty_signature() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
    let empty_sig = array![];

    testing::set_signature(empty_sig.span());
    account.__validate_deploy__(CLASS_HASH(), SALT, ETH_PUBKEY());
}

#[test]
fn test_validate_declare() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));

    // `__validate_declare__` does not directly use the class_hash argument. Its
    // value is already integrated in the tx hash. The class_hash argument in this
    // testing context is decoupled from the signature and has no effect on the test.
    let is_valid = account.__validate_declare__(CLASS_HASH());
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('EthAccount: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_declare_invalid_signature_data() {
    let mut data = SIGNED_TX_DATA();
    data.transaction_hash += 1;
    let account = setup_dispatcher(Option::Some(@data));

    account.__validate_declare__(CLASS_HASH());
}

#[test]
#[should_panic(expected: ('Signature: Invalid format.', 'ENTRYPOINT_FAILED'))]
fn test_validate_declare_invalid_signature_length() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
    let mut signature = array![];

    signature.append(0x1);
    testing::set_signature(signature.span());

    account.__validate_declare__(CLASS_HASH());
}

#[test]
#[should_panic(expected: ('Signature: Invalid format.', 'ENTRYPOINT_FAILED'))]
fn test_validate_declare_empty_signature() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
    let empty_sig = array![];

    testing::set_signature(empty_sig.span());

    account.__validate_declare__(CLASS_HASH());
}

fn test_execute_with_version(version: Option<felt252>) {
    let data = SIGNED_TX_DATA();
    let account = setup_dispatcher(Option::Some(@data));
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
    if version.is_some() {
        testing::set_version(version.unwrap());
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
#[should_panic(expected: ('EthAccount: invalid tx version', 'ENTRYPOINT_FAILED'))]
fn test_execute_invalid_version() {
    test_execute_with_version(Option::Some(MIN_TRANSACTION_VERSION - 1));
}

#[test]
fn test_validate() {
    let calls = array![];
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));

    let is_valid = account.__validate__(calls);
    assert_eq!(is_valid, starknet::VALIDATED);
}

#[test]
#[should_panic(expected: ('EthAccount: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_invalid() {
    let calls = array![];
    let mut data = SIGNED_TX_DATA();
    data.transaction_hash += 1;
    let account = setup_dispatcher(Option::Some(@data));

    account.__validate__(calls);
}

#[test]
fn test_multicall() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
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

    // Bundle calls and exeute
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
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
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

    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(CALLER());

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
    let new_public_key = NEW_ETH_PUBKEY();

    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(ACCOUNT_ADDRESS());

    state.set_public_key(new_public_key);
}

#[test]
fn test_public_key_setter_and_getter() {
    let mut state = COMPONENT_STATE();
    let public_key = ETH_PUBKEY();
    let new_public_key = NEW_ETH_PUBKEY();

    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(ACCOUNT_ADDRESS());

    state.initializer(public_key);
    utils::drop_event(ACCOUNT_ADDRESS());

    // Check default
    let current = state.get_public_key();
    assert_eq!(current, public_key);

    // Set key
    state.set_public_key(new_public_key);

    assert_event_owner_removed(ACCOUNT_ADDRESS(), current);
    assert_only_event_owner_added(ACCOUNT_ADDRESS(), new_public_key);

    let public_key = state.get_public_key();
    assert_eq!(public_key, new_public_key);
}

#[test]
#[should_panic(expected: ('EthAccount: unauthorized',))]
fn test_public_key_setter_different_account() {
    let mut state = COMPONENT_STATE();
    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(CALLER());

    state.set_public_key(NEW_ETH_PUBKEY());
}

//
// setPublicKey & getPublicKey
//

#[test]
fn test_public_key_setter_and_getter_camel() {
    let mut state = COMPONENT_STATE();
    let public_key = ETH_PUBKEY();
    let new_public_key = NEW_ETH_PUBKEY();

    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(ACCOUNT_ADDRESS());

    state.initializer(public_key);
    utils::drop_event(ACCOUNT_ADDRESS());

    let current = state.getPublicKey();
    assert_eq!(current, public_key);

    state.setPublicKey(new_public_key);

    assert_event_owner_removed(ACCOUNT_ADDRESS(), public_key);
    assert_only_event_owner_added(ACCOUNT_ADDRESS(), new_public_key);

    let public_key = state.getPublicKey();
    assert_eq!(public_key, new_public_key);
}

#[test]
#[should_panic(expected: ('EthAccount: unauthorized',))]
fn test_public_key_setter_different_account_camel() {
    let mut state = COMPONENT_STATE();
    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(CALLER());

    state.setPublicKey(NEW_ETH_PUBKEY());
}

//
// Test internals
//

#[test]
fn test_initializer() {
    let mut state = COMPONENT_STATE();
    let mock_state = CONTRACT_STATE();
    let public_key = ETH_PUBKEY();

    state.initializer(public_key);

    assert_only_event_owner_added(ZERO(), public_key);

    assert_eq!(state.get_public_key(), public_key);

    let supports_default_interface = mock_state.supports_interface(ISRC5_ID);
    assert!(supports_default_interface, "Should support ISRC5");

    let supports_account_interface = mock_state.supports_interface(ISRC6_ID);
    assert!(supports_account_interface, "Should support ISRC6");
}

#[test]
fn test_assert_only_self_true() {
    let mut state = COMPONENT_STATE();

    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(ACCOUNT_ADDRESS());
    state.assert_only_self();
}

#[test]
#[should_panic(expected: ('EthAccount: unauthorized',))]
fn test_assert_only_self_false() {
    let mut state = COMPONENT_STATE();

    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(OTHER());
    state.assert_only_self();
}

#[test]
fn test__is_valid_signature() {
    let mut state = COMPONENT_STATE();
    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;

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
    state._set_public_key(public_key);

    assert_only_event_owner_added(ZERO(), public_key);

    let public_key = state.get_public_key();
    assert_eq!(public_key, ETH_PUBKEY());
}

//
// Helpers
//

fn assert_event_owner_added(contract: ContractAddress, public_key: EthPublicKey) {
    let event = utils::pop_log::<EthAccountComponent::Event>(contract).unwrap();
    let new_owner_guid = get_guid_from_public_key(public_key);
    let expected = EthAccountComponent::Event::OwnerAdded(OwnerAdded { new_owner_guid });
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("OwnerAdded"));
    indexed_keys.append_serde(new_owner_guid);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_only_event_owner_added(contract: ContractAddress, public_key: EthPublicKey) {
    assert_event_owner_added(contract, public_key);
    utils::assert_no_events_left(contract);
}

fn assert_event_owner_removed(contract: ContractAddress, public_key: EthPublicKey) {
    let event = utils::pop_log::<EthAccountComponent::Event>(contract).unwrap();
    let removed_owner_guid = get_guid_from_public_key(public_key);
    let expected = EthAccountComponent::Event::OwnerRemoved(OwnerRemoved { removed_owner_guid });
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("OwnerRemoved"));
    indexed_keys.append_serde(removed_owner_guid);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn get_guid_from_public_key(public_key: EthPublicKey) -> felt252 {
    let (x, y) = public_key.get_coordinates().unwrap_syscall();
    poseidon_hash_span(array![x.low.into(), x.high.into(), y.low.into(), y.high.into()].span())
}
