use core::traits::Into;
use array::ArrayTrait;
use array::SpanTrait;
use core::result::ResultTrait;
use option::OptionTrait;
use serde::Serde;
use starknet::class_hash::Felt252TryIntoClassHash;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::syscalls;
use starknet::testing;
use traits::TryInto;

use openzeppelin::account::Account;
use openzeppelin::account::IAccountDispatcher;
use openzeppelin::account::IAccountDispatcherTrait;
use openzeppelin::account::ERC165_ACCOUNT_ID;
use openzeppelin::account::ERC1271_VALIDATED;
use openzeppelin::account::TRANSACTION_VERSION;
use openzeppelin::account::QUERY_VERSION;
use openzeppelin::account::Call;
use openzeppelin::token::erc20::ERC20;
use openzeppelin::token::erc20::IERC20Dispatcher;
use openzeppelin::token::erc20::IERC20DispatcherTrait;
use openzeppelin::introspection::erc165::IERC165_ID;

const PUBLIC_KEY: felt252 = 0x333333;
const NEW_PUBKEY: felt252 = 0x789789;
const SET_PUBLIC_KEY_SELECTOR: felt252 =
    0x2e3e21ff5952b2531241e37999d9c4c8b3034cccc89a202a6bf019bdf5294f9;
const TRANSFER_SELECTOR: felt252 = 0x83afd3f4caedc6eebf44246fe54e38c95e3179a5ec9ea81740eca5b482d12e;

#[derive(Drop)]
struct SignedTransactionData {
    private_key: felt252,
    public_key: felt252,
    transaction_hash: felt252,
    r: felt252,
    s: felt252
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

fn setup_dispatcher(data: Option<@SignedTransactionData>) -> IAccountDispatcher {
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

    let (address, _) = syscalls::deploy_syscall(
        Account::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();

    IAccountDispatcher { contract_address: address }
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

    let (address, _) = syscalls::deploy_syscall(
        ERC20::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();

    IERC20Dispatcher { contract_address: address }
}

#[test]
#[available_gas(2000000)]
fn test_constructor() {
    let account = setup_dispatcher(Option::None(()));
    let public_key: felt252 = account.get_public_key();
    assert(public_key == PUBLIC_KEY, 'Should return public key');
}

#[test]
#[available_gas(2000000)]
fn test_interfaces() {
    Account::constructor(PUBLIC_KEY);

    let supports_default_interface = Account::supports_interface(IERC165_ID);
    assert(supports_default_interface, 'Should support base interface');

    let supports_account_interface = Account::supports_interface(ERC165_ACCOUNT_ID);
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

    assert(
        account.__validate_deploy__(0, 0, 0) == starknet::VALIDATED, 'Should validate correctly'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_deploy_invalid() {
    let mut data = SIGNED_TX_DATA();
    data.transaction_hash += 1;
    let account = setup_dispatcher(Option::Some(@data));

    account.__validate_deploy__(0, 0, 0);
}

#[test]
#[available_gas(2000000)]
fn test_validate_declare() {
    let account = setup_dispatcher(Option::Some(@SIGNED_TX_DATA()));

    assert(account.__validate_declare__(0) == starknet::VALIDATED, 'Should validate correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_validate_declare_invalid() {
    let mut data = SIGNED_TX_DATA();
    data.transaction_hash += 1;
    let account = setup_dispatcher(Option::Some(@data));

    account.__validate_declare__(0);
}

fn test_execute_with_version(version: Option<felt252>) {
    let data = SIGNED_TX_DATA();
    let account = setup_dispatcher(Option::Some(@data));
    let initial_public_key = data.public_key;
    let mut calls = ArrayTrait::new();

    let mut calldata = ArrayTrait::new();
    calldata.append(NEW_PUBKEY);
    let call = Call {
        to: account.contract_address, selector: SET_PUBLIC_KEY_SELECTOR, calldata: calldata
    };
    calls.append(call);

    if version.is_some() {
        testing::set_version(version.unwrap());
    }
    let ret = account.__execute__(calls);

    assert(account.get_public_key() == NEW_PUBKEY, 'Should get new public key');
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

    let mut calldata1 = ArrayTrait::new();
    let amount1: u256 = 300;
    calldata1.append(recipient1.into());
    calldata1.append(amount1.low.into());
    calldata1.append(amount1.high.into());
    let call1 = Call {
        to: erc20.contract_address, selector: TRANSFER_SELECTOR, calldata: calldata1
    };

    let mut calldata2 = ArrayTrait::new();
    let amount2: u256 = 500;
    calldata2.append(recipient2.into());
    calldata2.append(amount2.low.into());
    calldata2.append(amount2.high.into());
    let call2 = Call {
        to: erc20.contract_address, selector: TRANSFER_SELECTOR, calldata: calldata2
    };

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
// test internals
//

#[test]
#[available_gas(2000000)]
fn test__assert_only_self_true() {
    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(ACCOUNT_ADDRESS());
    Account::_assert_only_self();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: unauthorized', ))]
fn test__assert_only_self_false() {
    testing::set_contract_address(ACCOUNT_ADDRESS());
    let other = contract_address_const::<0x4567>();
    testing::set_caller_address(other);
    Account::_assert_only_self();
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
    assert(!is_valid, 'Should reject invalid signature');
}
