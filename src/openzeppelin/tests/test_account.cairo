use array::ArrayTrait;
use core::traits::Into;
use option::OptionTrait;
use serde::Serde;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing;

use openzeppelin::account::Account;
use openzeppelin::account::AccountABIDispatcher;
use openzeppelin::account::AccountABIDispatcherTrait;
use openzeppelin::account::interface::Call;
use openzeppelin::account::interface::ERC1271_VALIDATED;
use openzeppelin::account::interface::IACCOUNT_ID;
use openzeppelin::account::QUERY_VERSION;
use openzeppelin::account::TRANSACTION_VERSION;
use openzeppelin::introspection::erc165::IERC165_ID;
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::ERC20;
use openzeppelin::token::erc20::IERC20Dispatcher;
use openzeppelin::token::erc20::IERC20DispatcherTrait;

const PUBLIC_KEY: felt252 = 0x333333;
const NEW_PUBKEY: felt252 = 0x789789;
const TRANSFER_SELECTOR: felt252 = 0x83afd3f4caedc6eebf44246fe54e38c95e3179a5ec9ea81740eca5b482d12e;
const SALT: felt252 = 123;

#[derive(Drop)]
struct SignedTransactionData {
    private_key: felt252,
    public_key: felt252,
    transaction_hash: felt252,
    r: felt252,
    s: felt252
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

fn setup_dispatcher(data: Option<@SignedTransactionData>) -> AccountABIDispatcher {
    // Set the transaction version
    testing::set_version(TRANSACTION_VERSION);

    // Deploy the account contract
    let mut calldata = ArrayTrait::new();

    if data.is_some() {
        let data = data.unwrap();

        // Set the signature and transaction hash
        let mut signature = ArrayTrait::new();
        signature.append(*data.r);
        signature.append(*data.s);
        testing::set_signature(signature.span());
        testing::set_transaction_hash(*data.transaction_hash);

        calldata.append(*data.public_key);
    } else {
        calldata.append(PUBLIC_KEY);
    }

    let address = utils::deploy(Account::TEST_CLASS_HASH, calldata);
    AccountABIDispatcher { contract_address: address }
}

fn deploy_erc20(recipient: ContractAddress, initial_supply: u256) -> IERC20Dispatcher {
    let name = 0;
    let symbol = 0;
    let mut calldata = ArrayTrait::<felt252>::new();

    calldata.append(name);
    calldata.append(symbol);
    calldata.append(initial_supply.low.into());
    calldata.append(initial_supply.high.into());
    calldata.append(recipient.into());

    let address = utils::deploy(ERC20::TEST_CLASS_HASH, calldata);
    IERC20Dispatcher { contract_address: address }
}

#[test]
#[available_gas(2000000)]
fn test_constructor() {
    Account::constructor(PUBLIC_KEY);
    assert(Account::get_public_key() == PUBLIC_KEY, 'Should return public key');
}

#[test]
#[available_gas(2000000)]
fn test_interfaces() {
    Account::constructor(PUBLIC_KEY);

    let supports_default_interface = Account::supports_interface(IERC165_ID);
    assert(supports_default_interface, 'Should support base interface');

    let supports_account_interface = Account::supports_interface(IACCOUNT_ID);
    assert(supports_account_interface, 'Should support account id');
}

#[test]
#[available_gas(2000000)]
fn test_is_valid_signature() {
    let data = SIGNED_TX_DATA();
    let message = data.transaction_hash;

    let mut good_signature = ArrayTrait::new();
    good_signature.append(data.r);
    good_signature.append(data.s);

    let mut bad_signature = ArrayTrait::new();
    bad_signature.append(0x987);
    bad_signature.append(0x564);

    Account::set_public_key(data.public_key);

    let is_valid = Account::is_valid_signature(message, good_signature);
    assert(is_valid == ERC1271_VALIDATED, 'Should accept valid signature');

    let is_valid = Account::is_valid_signature(message, bad_signature);
    assert(is_valid == 0_u32, 'Should reject invalid signature');
}

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
    let mut signature = ArrayTrait::new();

    signature.append(0x1);
    testing::set_signature(signature.span());

    account.__validate_deploy__(CLASS_HASH(), SALT, PUBLIC_KEY);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_empty_signature() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
    let empty_sig = ArrayTrait::new();

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
    let mut signature = ArrayTrait::new();

    signature.append(0x1);
    testing::set_signature(signature.span());

    account.__validate_declare__(CLASS_HASH());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_declare_empty_signature() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
    let empty_sig = ArrayTrait::new();

    testing::set_signature(empty_sig.span());

    account.__validate_declare__(CLASS_HASH());
}

fn test_execute_with_version(version: Option<felt252>) {
    let data = SIGNED_TX_DATA();
    let account = setup_dispatcher(Option::Some(@data));
    let erc20 = deploy_erc20(account.contract_address, 1000);
    let recipient = contract_address_const::<0x123>();

    // Craft call and add to calls array
    let mut calldata = ArrayTrait::new();
    let amount: u256 = 200;
    calldata.append(recipient.into());
    calldata.append(amount.low.into());
    calldata.append(amount.high.into());
    let call = Call { to: erc20.contract_address, selector: TRANSFER_SELECTOR, calldata: calldata };
    let mut calls = ArrayTrait::new();
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
    let calls = ArrayTrait::new();
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));

    assert(account.__validate__(calls) == starknet::VALIDATED, 'Should validate correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_invalid() {
    let calls = ArrayTrait::new();
    let mut data = SIGNED_TX_DATA();
    data.transaction_hash += 1;
    let account = setup_dispatcher(Option::Some(@data));

    account.__validate__(calls);
}

#[test]
#[available_gas(2000000)]
fn test_multicall() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));
    let erc20 = deploy_erc20(account.contract_address, 1000);
    let recipient1 = contract_address_const::<0x123>();
    let recipient2 = contract_address_const::<0x456>();
    let mut calls = ArrayTrait::new();

    // Craft call1
    let mut calldata1 = ArrayTrait::new();
    let amount1: u256 = 300;
    calldata1.append(recipient1.into());
    calldata1.append(amount1.low.into());
    calldata1.append(amount1.high.into());
    let call1 = Call {
        to: erc20.contract_address, selector: TRANSFER_SELECTOR, calldata: calldata1
    };

    // Craft call2
    let mut calldata2 = ArrayTrait::new();
    let amount2: u256 = 500;
    calldata2.append(recipient2.into());
    calldata2.append(amount2.low.into());
    calldata2.append(amount2.high.into());
    let call2 = Call {
        to: erc20.contract_address, selector: TRANSFER_SELECTOR, calldata: calldata2
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
    let mut calls = ArrayTrait::new();

    let ret = account.__execute__(calls);

    // Test return value
    assert(ret.len() == 0, 'Should have an empty response');
}

#[test]
#[available_gas(2000000)]
fn test_public_key_setter_and_getter() {
    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(ACCOUNT_ADDRESS());
    Account::set_public_key(NEW_PUBKEY);

    let public_key = Account::get_public_key();
    assert(public_key == NEW_PUBKEY, 'Should update key');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: unauthorized', ))]
fn test_public_key_setter_different_account() {
    let caller = contract_address_const::<0x123>();
    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(caller);
    Account::set_public_key(NEW_PUBKEY);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid caller', ))]
fn test_account_called_from_contract() {
    let calls = ArrayTrait::new();
    let caller = contract_address_const::<0x123>();
    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(caller);
    Account::__execute__(calls);
}

//
// Test internals
//

#[test]
#[available_gas(2000000)]
fn test_initializer() {
    Account::initializer(PUBLIC_KEY);
    assert(Account::get_public_key() == PUBLIC_KEY, 'Should return public key');
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
    let data = SIGNED_TX_DATA();
    let message = data.transaction_hash;

    let mut good_signature = ArrayTrait::new();
    good_signature.append(data.r);
    good_signature.append(data.s);

    let mut bad_signature = ArrayTrait::new();
    bad_signature.append(0x987);
    bad_signature.append(0x564);

    let mut invalid_length_signature = ArrayTrait::new();
    invalid_length_signature.append(0x987);

    Account::set_public_key(data.public_key);

    let is_valid = Account::_is_valid_signature(message, good_signature.span());
    assert(is_valid, 'Should accept valid signature');

    let is_valid = Account::_is_valid_signature(message, bad_signature.span());
    assert(!is_valid, 'Should reject invalid signature');

    let is_valid = Account::_is_valid_signature(message, invalid_length_signature.span());
    assert(!is_valid, 'Should reject invalid length');
}
