use array::ArrayTrait;
use core::traits::Into;
use openzeppelin::account::Account::OwnerAdded;
use openzeppelin::account::Account::OwnerRemoved;
use openzeppelin::account::Account::PublicKeyCamelImpl;
use openzeppelin::account::Account::PublicKeyImpl;
use openzeppelin::account::Account;
use openzeppelin::account::AccountABIDispatcher;
use openzeppelin::account::AccountABIDispatcherTrait;
use openzeppelin::account::QUERY_VERSION;
use openzeppelin::account::TRANSACTION_VERSION;
use openzeppelin::account::interface::ISRC6_ID;
use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::tests::utils;
use openzeppelin::tests::utils::constants::ZERO;
use openzeppelin::token::erc20::ERC20;
use openzeppelin::token::erc20::interface::IERC20Dispatcher;
use openzeppelin::token::erc20::interface::IERC20DispatcherTrait;
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use option::OptionTrait;
use serde::Serde;
use starknet::ContractAddress;
use starknet::account::Call;
use starknet::contract_address_const;
use starknet::testing;

//
// Constants
//

const PUBLIC_KEY: felt252 = 0x333333;
const NEW_PUBKEY: felt252 = 0x789789;
const SALT: felt252 = 123;

#[derive(Drop)]
struct SignedTransactionData {
    private_key: felt252,
    public_key: felt252,
    transaction_hash: felt252,
    r: felt252,
    s: felt252
}

fn STATE() -> Account::ContractState {
    Account::contract_state_for_testing()
}
fn CLASS_HASH() -> felt252 {
    Account::TEST_CLASS_HASH
}
fn ACCOUNT_ADDRESS() -> ContractAddress {
    contract_address_const::<0x111111>()
}
fn SIGNED_TX_DATA() -> SignedTransactionData {
    SignedTransactionData {
        private_key: 1234,
        public_key: 883045738439352841478194533192765345509759306772397516907181243450667673002,
        transaction_hash: 2717105892474786771566982177444710571376803476229898722748888396642649184538,
        r: 3068558690657879390136740086327753007413919701043650133111397282816679110801,
        s: 3355728545224320878895493649495491771252432631648740019139167265522817576501
    }
}

//
// Setup
//

fn setup_dispatcher(data: Option<@SignedTransactionData>) -> AccountABIDispatcher {
    testing::set_version(TRANSACTION_VERSION);

    let mut calldata = array![];
    if data.is_some() {
        let data = data.unwrap();
        testing::set_signature(array![*data.r, *data.s].span());
        testing::set_transaction_hash(*data.transaction_hash);

        calldata.append(*data.public_key);
    } else {
        calldata.append(PUBLIC_KEY);
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

    let address = utils::deploy(ERC20::TEST_CLASS_HASH, calldata);
    IERC20Dispatcher { contract_address: address }
}

//
// constructor
//

#[test]
#[available_gas(2000000)]
fn test_constructor() {
    let mut state = STATE();
    Account::constructor(ref state, PUBLIC_KEY);

    let event = testing::pop_log::<OwnerAdded>(ZERO()).unwrap();
    assert(event.new_owner_guid == PUBLIC_KEY, 'Invalid owner key');
    utils::assert_no_events_left(ZERO());

    assert(PublicKeyImpl::get_public_key(@state) == PUBLIC_KEY, 'Should return public key');
}

//
// supports_interface & supportsInterface
//

#[test]
#[available_gas(2000000)]
fn test_supports_interface() {
    let mut state = STATE();
    Account::constructor(ref state, PUBLIC_KEY);

    let supports_default_interface = Account::SRC5Impl::supports_interface(@state, ISRC5_ID);
    assert(supports_default_interface, 'Should support base interface');

    let supports_account_interface = Account::SRC5Impl::supports_interface(@state, ISRC6_ID);
    assert(supports_account_interface, 'Should support account id');
}

#[test]
#[available_gas(2000000)]
fn test_supportsInterface() {
    let mut state = STATE();
    Account::constructor(ref state, PUBLIC_KEY);

    let supports_default_interface = Account::SRC5CamelImpl::supportsInterface(@state, ISRC5_ID);
    assert(supports_default_interface, 'Should support base interface');

    let supports_account_interface = Account::SRC5CamelImpl::supportsInterface(@state, ISRC6_ID);
    assert(supports_account_interface, 'Should support account id');
}

//
// is_valid_signature & isValidSignature
//

#[test]
#[available_gas(2000000)]
fn test_is_valid_signature() {
    let mut state = STATE();
    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;

    let mut good_signature = array![data.r, data.s];
    let mut bad_signature = array![0x987, 0x564];

    PublicKeyImpl::set_public_key(ref state, data.public_key);

    let is_valid = Account::SRC6Impl::is_valid_signature(@state, hash, good_signature);
    assert(is_valid == starknet::VALIDATED, 'Should accept valid signature');

    let is_valid = Account::SRC6Impl::is_valid_signature(@state, hash, bad_signature);
    assert(is_valid == 0, 'Should reject invalid signature');
}

#[test]
#[available_gas(2000000)]
fn test_isValidSignature() {
    let mut state = STATE();
    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;

    let mut good_signature = array![data.r, data.s];
    let mut bad_signature = array![0x987, 0x564];

    PublicKeyImpl::set_public_key(ref state, data.public_key);

    let is_valid = Account::SRC6CamelOnlyImpl::isValidSignature(@state, hash, good_signature);
    assert(is_valid == starknet::VALIDATED, 'Should accept valid signature');

    let is_valid = Account::SRC6CamelOnlyImpl::isValidSignature(@state, hash, bad_signature);
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
        account.__validate_deploy__(CLASS_HASH(), SALT, PUBLIC_KEY) == starknet::VALIDATED,
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

    account.__validate_deploy__(CLASS_HASH(), SALT, PUBLIC_KEY);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_invalid_signature_length() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
    let mut signature = array![];

    signature.append(0x1);
    testing::set_signature(signature.span());

    account.__validate_deploy__(CLASS_HASH(), SALT, PUBLIC_KEY);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_empty_signature() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
    let empty_sig = array![];

    testing::set_signature(empty_sig.span());
    account.__validate_deploy__(CLASS_HASH(), SALT, PUBLIC_KEY);
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
#[available_gas(2000000)]
fn test_execute_query_version() {
    test_execute_with_version(Option::Some(QUERY_VERSION));
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid tx version', 'ENTRYPOINT_FAILED'))]
fn test_execute_invalid_version() {
    test_execute_with_version(Option::Some(TRANSACTION_VERSION - 1));
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
#[should_panic(expected: ('Account: invalid caller', ))]
fn test_account_called_from_contract() {
    let calls = array![];
    let caller = contract_address_const::<0x123>();

    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(caller);

    Account::SRC6Impl::__execute__(@STATE(), calls);
}

//
// set_public_key & get_public_key
//

#[test]
#[available_gas(2000000)]
fn test_public_key_setter_and_getter() {
    let mut state = STATE();
    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(ACCOUNT_ADDRESS());

    // Check default
    let public_key = PublicKeyImpl::get_public_key(@state);
    assert(public_key == 0, 'Should be zero');

    // Set key
    PublicKeyImpl::set_public_key(ref state, NEW_PUBKEY);

    let event = testing::pop_log::<OwnerRemoved>(ACCOUNT_ADDRESS()).unwrap();
    assert(event.removed_owner_guid == 0, 'Invalid old owner key');

    let event = testing::pop_log::<OwnerAdded>(ACCOUNT_ADDRESS()).unwrap();
    assert(event.new_owner_guid == NEW_PUBKEY, 'Invalid new owner key');
    utils::assert_no_events_left(ACCOUNT_ADDRESS());

    let public_key = PublicKeyImpl::get_public_key(@state);
    assert(public_key == NEW_PUBKEY, 'Should update key');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: unauthorized', ))]
fn test_public_key_setter_different_account() {
    let mut state = STATE();
    let caller = contract_address_const::<0x123>();
    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(caller);

    PublicKeyImpl::set_public_key(ref state, NEW_PUBKEY);
}

//
// setPublicKey & getPublicKey
//

#[test]
#[available_gas(2000000)]
fn test_public_key_setter_and_getter_camel() {
    let mut state = STATE();
    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(ACCOUNT_ADDRESS());

    // Check default
    let public_key = PublicKeyCamelImpl::getPublicKey(@state);
    assert(public_key == 0, 'Should be zero');

    // Set key
    PublicKeyCamelImpl::setPublicKey(ref state, NEW_PUBKEY);

    let event = testing::pop_log::<OwnerRemoved>(ACCOUNT_ADDRESS()).unwrap();
    assert(event.removed_owner_guid == 0, 'Invalid old owner key');

    let event = testing::pop_log::<OwnerAdded>(ACCOUNT_ADDRESS()).unwrap();
    assert(event.new_owner_guid == NEW_PUBKEY, 'Invalid new owner key');
    utils::assert_no_events_left(ACCOUNT_ADDRESS());

    let public_key = PublicKeyCamelImpl::getPublicKey(@state);
    assert(public_key == NEW_PUBKEY, 'Should update key');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: unauthorized', ))]
fn test_public_key_setter_different_account_camel() {
    let mut state = STATE();
    let caller = contract_address_const::<0x123>();
    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(caller);

    PublicKeyCamelImpl::setPublicKey(ref state, NEW_PUBKEY);
}

//
// Test internals
//

#[test]
#[available_gas(2000000)]
fn test_initializer() {
    let mut state = STATE();
    Account::InternalImpl::initializer(ref state, PUBLIC_KEY);

    let event = testing::pop_log::<OwnerAdded>(ZERO()).unwrap();
    assert(event.new_owner_guid == PUBLIC_KEY, 'Invalid owner key');
    utils::assert_no_events_left(ZERO());

    assert(PublicKeyImpl::get_public_key(@state) == PUBLIC_KEY, 'Should return public key');
}

#[test]
#[available_gas(2000000)]
fn test_assert_only_self_true() {
    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(ACCOUNT_ADDRESS());
    Account::assert_only_self();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: unauthorized', ))]
fn test_assert_only_self_false() {
    testing::set_contract_address(ACCOUNT_ADDRESS());
    let other = contract_address_const::<0x4567>();
    testing::set_caller_address(other);
    Account::assert_only_self();
}

#[test]
#[available_gas(2000000)]
fn test__is_valid_signature() {
    let mut state = STATE();
    let data = SIGNED_TX_DATA();
    let hash = data.transaction_hash;

    let mut good_signature = array![data.r, data.s];
    let mut bad_signature = array![0x987, 0x564];
    let mut invalid_length_signature = array![0x987];

    PublicKeyImpl::set_public_key(ref state, data.public_key);

    let is_valid = Account::InternalImpl::_is_valid_signature(@state, hash, good_signature.span());
    assert(is_valid, 'Should accept valid signature');

    let is_valid = Account::InternalImpl::_is_valid_signature(@state, hash, bad_signature.span());
    assert(!is_valid, 'Should reject invalid signature');

    let is_valid = Account::InternalImpl::_is_valid_signature(
        @state, hash, invalid_length_signature.span()
    );
    assert(!is_valid, 'Should reject invalid length');
}

#[test]
#[available_gas(2000000)]
fn test__set_public_key() {
    let mut state = STATE();
    Account::InternalImpl::_set_public_key(ref state, PUBLIC_KEY);

    let event = testing::pop_log::<OwnerAdded>(ZERO()).unwrap();
    assert(event.new_owner_guid == PUBLIC_KEY, 'Invalid owner key');
    utils::assert_no_events_left(ZERO());

    let public_key = PublicKeyImpl::get_public_key(@state);
    assert(public_key == PUBLIC_KEY, 'Should update key');
}
