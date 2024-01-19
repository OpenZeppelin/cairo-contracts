use openzeppelin::account::AccountComponent::{InternalTrait, SRC6CamelOnlyImpl};
use openzeppelin::account::AccountComponent::{OwnerAdded, OwnerRemoved};
use openzeppelin::account::AccountComponent::{PublicKeyCamelImpl, PublicKeyImpl};
use openzeppelin::account::AccountComponent;
use openzeppelin::account::interface::{ISRC6, ISRC6_ID};
use openzeppelin::account::{AccountABIDispatcherTrait, AccountABIDispatcher};
use openzeppelin::introspection::interface::{ISRC5, ISRC5_ID};
use openzeppelin::tests::mocks::account_mocks::DualCaseAccountMock;
use openzeppelin::tests::mocks::erc20_mocks::DualCaseERC20Mock;
use openzeppelin::tests::utils::constants::{
    PUBKEY, NEW_PUBKEY, SALT, ZERO, QUERY_OFFSET, QUERY_VERSION, MIN_TRANSACTION_VERSION
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;
use starknet::account::Call;
use starknet::contract_address_const;
use starknet::testing;

#[derive(Drop)]
struct SignedTransactionData {
    private_key: felt252,
    public_key: felt252,
    transaction_hash: felt252,
    r: felt252,
    s: felt252
}

//
// Constants
//

fn CLASS_HASH() -> felt252 {
    DualCaseAccountMock::TEST_CLASS_HASH
}

fn ACCOUNT_ADDRESS() -> ContractAddress {
    contract_address_const::<0x111111>()
}

fn SIGNED_TX_DATA() -> SignedTransactionData {
    SignedTransactionData {
        private_key: 1234,
        public_key: 0x1f3c942d7f492a37608cde0d77b884a5aa9e11d2919225968557370ddb5a5aa,
        transaction_hash: 0x601d3d2e265c10ff645e1554c435e72ce6721f0ba5fc96f0c650bfc6231191a,
        r: 0x6c8be1fb0fb5c730fbd7abaecbed9d980376ff2e660dfcd157e158d2b026891,
        s: 0x76b4669998eb933f44a59eace12b41328ab975ceafddf92602b21eb23e22e35
    }
}

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
    utils::drop_event(ZERO());
    state
}

fn setup_dispatcher(data: Option<@SignedTransactionData>) -> AccountABIDispatcher {
    testing::set_version(MIN_TRANSACTION_VERSION);

    let mut calldata = array![];
    if data.is_some() {
        let data = data.unwrap();
        testing::set_signature(array![*data.r, *data.s].span());
        testing::set_transaction_hash(*data.transaction_hash);

        calldata.append(*data.public_key);
    } else {
        calldata.append(PUBKEY);
    }
    let address = utils::deploy(CLASS_HASH(), calldata);
    AccountABIDispatcher { contract_address: address }
}

fn deploy_erc20(recipient: ContractAddress, initial_supply: u256) -> IERC20Dispatcher {
    let name = 0;
    let symbol = 0;
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
#[available_gas(2000000)]
fn test_is_valid_signature() {
    let mut state = COMPONENT_STATE();
    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;

    let mut good_signature = array![data.r, data.s];
    let mut bad_signature = array![0x987, 0x564];

    state.set_public_key(data.public_key);

    let is_valid = state.is_valid_signature(hash, good_signature);
    assert(is_valid == starknet::VALIDATED, 'Should accept valid signature');

    let is_valid = state.is_valid_signature(hash, bad_signature);
    assert(is_valid == 0, 'Should reject invalid signature');
}

#[test]
#[available_gas(2000000)]
fn test_isValidSignature() {
    let mut state = COMPONENT_STATE();
    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;

    let mut good_signature = array![data.r, data.s];
    let mut bad_signature = array![0x987, 0x564];

    state.set_public_key(data.public_key);

    let is_valid = state.isValidSignature(hash, good_signature);
    assert(is_valid == starknet::VALIDATED, 'Should accept valid signature');

    let is_valid = state.isValidSignature(hash, bad_signature);
    assert(is_valid == 0, 'Should reject invalid signature');
}

//
// Entry points
//

#[test]
#[available_gas(2000000)]
fn test_validate_deploy() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));

    // `__validate_deploy__` does not directly use the passed arguments. Their
    // values are already integrated in the tx hash. The passed arguments in this
    // testing context are decoupled from the signature and have no effect on the test.
    assert(
        account.__validate_deploy__(CLASS_HASH(), SALT, PUBKEY) == starknet::VALIDATED,
        'Should validate correctly'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_invalid_signature_data() {
    let mut data = SIGNED_TX_DATA();
    data.transaction_hash += 1;
    let account = setup_dispatcher(Option::Some(@data));

    account.__validate_deploy__(CLASS_HASH(), SALT, PUBKEY);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_invalid_signature_length() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
    let mut signature = array![];

    signature.append(0x1);
    testing::set_signature(signature.span());

    account.__validate_deploy__(CLASS_HASH(), SALT, PUBKEY);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_empty_signature() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
    let empty_sig = array![];

    testing::set_signature(empty_sig.span());
    account.__validate_deploy__(CLASS_HASH(), SALT, PUBKEY);
}

#[test]
#[available_gas(2000000)]
fn test_validate_declare() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));

    // `__validate_declare__` does not directly use the class_hash argument. Its
    // value is already integrated in the tx hash. The class_hash argument in this
    // testing context is decoupled from the signature and has no effect on the test.
    assert(
        account.__validate_declare__(CLASS_HASH()) == starknet::VALIDATED,
        'Should validate correctly'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_declare_invalid_signature_data() {
    let mut data = SIGNED_TX_DATA();
    data.transaction_hash += 1;
    let account = setup_dispatcher(Option::Some(@data));

    account.__validate_declare__(CLASS_HASH());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_declare_invalid_signature_length() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
    let mut signature = array![];

    signature.append(0x1);
    testing::set_signature(signature.span());

    account.__validate_declare__(CLASS_HASH());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
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
    let recipient = contract_address_const::<0x123>();

    // Craft call and add to calls array
    let mut calldata = array![];
    let amount: u256 = 200;
    calldata.append_serde(recipient);
    calldata.append_serde(amount);
    let call = Call {
        to: erc20.contract_address, selector: selectors::transfer, calldata: calldata
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
    assert(erc20.balance_of(account.contract_address) == 800, 'Should have remainder');
    assert(erc20.balance_of(recipient) == amount, 'Should have transferred');

    // Test return value
    let mut call_serialized_retval = *ret.at(0);
    let call_retval = Serde::<bool>::deserialize(ref call_serialized_retval);
    assert(call_retval.unwrap(), 'Should have succeeded');
}

#[test]
#[available_gas(2000000)]
fn test_execute() {
    test_execute_with_version(Option::None(()));
}

#[test]
fn test_execute_future_version() {
    test_execute_with_version(Option::Some(MIN_TRANSACTION_VERSION + 1));
}

#[test]
#[available_gas(2000000)]
fn test_execute_query_version() {
    test_execute_with_version(Option::Some(QUERY_VERSION));
}

#[test]
#[should_panic(expected: ('Account: invalid tx version', 'ENTRYPOINT_FAILED'))]
fn test_execute_invalid_query_version() {
    test_execute_with_version(Option::Some(QUERY_OFFSET));
}

#[test]
#[available_gas(2000000)]
fn test_execute_future_query_version() {
    test_execute_with_version(Option::Some(QUERY_VERSION + 1));
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid tx version', 'ENTRYPOINT_FAILED'))]
fn test_execute_invalid_version() {
    test_execute_with_version(Option::Some(MIN_TRANSACTION_VERSION - 1));
}

#[test]
#[available_gas(2000000)]
fn test_validate() {
    let calls = array![];
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));

    assert(account.__validate__(calls) == starknet::VALIDATED, 'Should validate correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_invalid() {
    let calls = array![];
    let mut data = SIGNED_TX_DATA();
    data.transaction_hash += 1;
    let account = setup_dispatcher(Option::Some(@data));

    account.__validate__(calls);
}

#[test]
#[available_gas(20000000)]
fn test_multicall() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
    let erc20 = deploy_erc20(account.contract_address, 1000);
    let recipient1 = contract_address_const::<0x123>();
    let recipient2 = contract_address_const::<0x456>();
    let mut calls = array![];

    // Craft call1
    let mut calldata1 = array![];
    let amount1: u256 = 300;
    calldata1.append_serde(recipient1);
    calldata1.append_serde(amount1);
    let call1 = Call {
        to: erc20.contract_address, selector: selectors::transfer, calldata: calldata1
    };

    // Craft call2
    let mut calldata2 = array![];
    let amount2: u256 = 500;
    calldata2.append_serde(recipient2);
    calldata2.append_serde(amount2);
    let call2 = Call {
        to: erc20.contract_address, selector: selectors::transfer, calldata: calldata2
    };

    // Bundle calls and exeute
    calls.append(call1);
    calls.append(call2);
    let ret = account.__execute__(calls);

    // Assert that the transfers were successful
    assert(erc20.balance_of(account.contract_address) == 200, 'Should have remainder');
    assert(erc20.balance_of(recipient1) == 300, 'Should have transferred');
    assert(erc20.balance_of(recipient2) == 500, 'Should have transferred');

    // Test return value
    let mut call1_serialized_retval = *ret.at(0);
    let mut call2_serialized_retval = *ret.at(1);
    let call1_retval = Serde::<bool>::deserialize(ref call1_serialized_retval);
    let call2_retval = Serde::<bool>::deserialize(ref call2_serialized_retval);
    assert(call1_retval.unwrap(), 'Should have succeeded');
    assert(call2_retval.unwrap(), 'Should have succeeded');
}

#[test]
#[available_gas(2000000)]
fn test_multicall_zero_calls() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
    let mut calls = array![];

    let ret = account.__execute__(calls);

    // Test return value
    assert(ret.len() == 0, 'Should have an empty response');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid caller',))]
fn test_account_called_from_contract() {
    let state = setup();
    let calls = array![];
    let caller = contract_address_const::<0x123>();

    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(caller);

    state.__execute__(calls);
}

//
// set_public_key & get_public_key
//

#[test]
#[available_gas(2000000)]
fn test_public_key_setter_and_getter() {
    let mut state = COMPONENT_STATE();
    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(ACCOUNT_ADDRESS());

    // Check default
    let public_key = state.get_public_key();
    assert(public_key == 0, 'Should be zero');

    // Set key
    state.set_public_key(NEW_PUBKEY);

    let event = utils::pop_log::<OwnerRemoved>(ACCOUNT_ADDRESS()).unwrap();
    assert(event.removed_owner_guid == 0, 'Invalid old owner key');

    let event = utils::pop_log::<OwnerAdded>(ACCOUNT_ADDRESS()).unwrap();
    assert(event.new_owner_guid == NEW_PUBKEY, 'Invalid new owner key');
    utils::assert_no_events_left(ACCOUNT_ADDRESS());

    let public_key = state.get_public_key();
    assert(public_key == NEW_PUBKEY, 'Should update key');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: unauthorized',))]
fn test_public_key_setter_different_account() {
    let mut state = COMPONENT_STATE();
    let caller = contract_address_const::<0x123>();
    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(caller);

    state.set_public_key(NEW_PUBKEY);
}

//
// setPublicKey & getPublicKey
//

#[test]
#[available_gas(2000000)]
fn test_public_key_setter_and_getter_camel() {
    let mut state = COMPONENT_STATE();
    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(ACCOUNT_ADDRESS());

    // Check default
    let public_key = state.getPublicKey();
    assert(public_key == 0, 'Should be zero');

    // Set key
    state.setPublicKey(NEW_PUBKEY);

    let event = utils::pop_log::<OwnerRemoved>(ACCOUNT_ADDRESS()).unwrap();
    assert(event.removed_owner_guid == 0, 'Invalid old owner key');

    let event = utils::pop_log::<OwnerAdded>(ACCOUNT_ADDRESS()).unwrap();
    assert(event.new_owner_guid == NEW_PUBKEY, 'Invalid new owner key');
    utils::assert_no_events_left(ACCOUNT_ADDRESS());

    let public_key = state.getPublicKey();
    assert(public_key == NEW_PUBKEY, 'Should update key');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: unauthorized',))]
fn test_public_key_setter_different_account_camel() {
    let mut state = COMPONENT_STATE();
    let caller = contract_address_const::<0x123>();
    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(caller);

    state.setPublicKey(NEW_PUBKEY);
}

//
// Test internals
//

#[test]
#[available_gas(2000000)]
fn test_initializer() {
    let mut state = COMPONENT_STATE();
    let mock_state = CONTRACT_STATE();

    state.initializer(PUBKEY);
    let event = utils::pop_log::<OwnerAdded>(ZERO()).unwrap();
    assert(event.new_owner_guid == PUBKEY, 'Invalid owner key');
    utils::assert_no_events_left(ZERO());

    assert(state.get_public_key() == PUBKEY, 'Should return PUBKEY');

    let supports_default_interface = mock_state.supports_interface(ISRC5_ID);
    assert(supports_default_interface, 'Should support base interface');

    let supports_account_interface = mock_state.supports_interface(ISRC6_ID);
    assert(supports_account_interface, 'Should support account id');
}

#[test]
#[available_gas(2000000)]
fn test_assert_only_self_true() {
    let mut state = COMPONENT_STATE();

    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(ACCOUNT_ADDRESS());
    state.assert_only_self();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: unauthorized',))]
fn test_assert_only_self_false() {
    let mut state = COMPONENT_STATE();

    testing::set_contract_address(ACCOUNT_ADDRESS());
    let other = contract_address_const::<0x4567>();
    testing::set_caller_address(other);
    state.assert_only_self();
}

#[test]
#[available_gas(2000000)]
fn test__is_valid_signature() {
    let mut state = COMPONENT_STATE();
    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;

    let mut good_signature = array![data.r, data.s];
    let mut bad_signature = array![0x987, 0x564];
    let mut invalid_length_signature = array![0x987];

    state.set_public_key(data.public_key);

    let is_valid = state._is_valid_signature(hash, good_signature.span());
    assert(is_valid, 'Should accept valid signature');

    let is_valid = state._is_valid_signature(hash, bad_signature.span());
    assert(!is_valid, 'Should reject invalid signature');

    let is_valid = state._is_valid_signature(hash, invalid_length_signature.span());
    assert(!is_valid, 'Should reject invalid length');
}

#[test]
#[available_gas(2000000)]
fn test__set_public_key() {
    let mut state = COMPONENT_STATE();
    state._set_public_key(PUBKEY);

    let event = utils::pop_log::<OwnerAdded>(ZERO()).unwrap();
    assert(event.new_owner_guid == PUBKEY, 'Invalid owner key');
    utils::assert_no_events_left(ZERO());

    let public_key = state.get_public_key();
    assert(public_key == PUBKEY, 'Should update key');
}
