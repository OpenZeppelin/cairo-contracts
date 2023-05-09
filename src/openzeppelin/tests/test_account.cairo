use core::traits::Into;
use array::ArrayTrait;
use core::result::ResultTrait;
use debug::PrintTrait;
use option::OptionTrait;
use starknet::class_hash::Felt252TryIntoClassHash;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::syscalls::deploy_syscall;
use starknet::testing;
use traits::TryInto;

use openzeppelin::account::Account;
use openzeppelin::account::IAccountDispatcher;
use openzeppelin::account::IAccountDispatcherTrait;
use openzeppelin::account::ERC165_ACCOUNT_ID;
use openzeppelin::account::ERC1271_VALIDATED;
use openzeppelin::account::TRANSACTION_VERSION;
use openzeppelin::account::Call;
use openzeppelin::introspection::erc165::IERC165_ID;

#[derive(Drop)]
struct SignedTransactionData {
    private_key: felt252,
    public_key: felt252,
    transaction_hash: felt252,
    r: felt252,
    s: felt252
}

fn NEW_KEY() -> felt252 {
    0x444444
}
fn PUBLIC_KEY() -> felt252 {
    0x333333
}
fn OTHER() -> ContractAddress {
    contract_address_const::<0x222222>()
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
fn CALLS() -> Array::<Call> {
    let mut calls = ArrayTrait::new();

    calls
        .append(
            Call {
                to: contract_address_const::<123456>(), selector: 0x123, calldata: ArrayTrait::new()
            }
        );

    calls
}

fn setup_dispatcher(data: Option<SignedTransactionData>) -> IAccountDispatcher {
    // Set the transaction version
    testing::set_version(TRANSACTION_VERSION);

    // Deploy the account contract
    let mut calldata = ArrayTrait::<felt252>::new();

    if data.is_some() {
        let data = data.unwrap();

        // Set the signature and transaction hash
        let mut signature = ArrayTrait::new();
        signature.append(data.r);
        signature.append(data.s);
        testing::set_signature(signature.span());
        testing::set_transaction_hash(data.transaction_hash);

        calldata.append(data.public_key);
    } else {
        calldata.append(PUBLIC_KEY());
    }

    let (address, _) = deploy_syscall(
        Account::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();

    IAccountDispatcher { contract_address: address }
}

#[test]
#[available_gas(2000000)]
fn test_counterfactual_deployment() {}

#[test]
#[available_gas(2000000)]
fn test_constructor() {
    let account = setup_dispatcher(Option::None(()));
    let public_key: felt252 = account.get_public_key();
    assert(public_key == PUBLIC_KEY(), 'Should return pub key');
}

#[test]
#[available_gas(2000000)]
fn test_interface() {
    Account::constructor(PUBLIC_KEY());

    let supports_default_interface: bool = Account::supports_interface(IERC165_ID);
    assert(supports_default_interface, 'Should support base interface');

    let supports_account_interface: bool = Account::supports_interface(ERC165_ACCOUNT_ID);
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
fn test_validate() {
    let calls = ArrayTrait::new();
    let account = setup_dispatcher(Option::Some(SIGNED_TX_DATA()));

    assert(account.__validate__(calls) == starknet::VALIDATED, 'Should validate correctly');
}

#[test]
#[available_gas(2000000)]
fn test_declare() { // todo: requires mocking TxInfo
// setup();
// let class_hash: felt252 = 0x123;
// Account::__validate_declare__(class_hash);
}

#[test]
#[available_gas(2000000)]
fn test_validate_declare() {
    let class_hash = 0x123;
    let account = setup_dispatcher(Option::Some(SIGNED_TX_DATA()));

    assert(
        account.__validate_declare__(class_hash) == starknet::VALIDATED, 'Should validate correctly'
    );
}

#[test]
#[available_gas(2000000)]
fn test_execute() {
    let data = SIGNED_TX_DATA();
    let initial_public_key = data.public_key;
    let account = setup_dispatcher(Option::Some(data));

    assert(account.get_public_key() == initial_public_key, 'Should get initial public key');

    // Call itself for updating the public key
    let new_public_key = 1313113211;
    let mut calls = ArrayTrait::new();
    let mut calldata = ArrayTrait::new();
    // Selector of the set_public_key external function
    let selector = 0x2e3e21ff5952b2531241e37999d9c4c8b3034cccc89a202a6bf019bdf5294f9;

    calldata.append(new_public_key);
    calls.append(Call { to: account.contract_address, selector: selector, calldata: calldata });
    account.__execute__(calls);

    assert(account.get_public_key() == 1313113211, 'Should get new public key');
}

#[test]
#[available_gas(2000000)]
fn test_multicall() { // todo: requires call_contract_syscall
// let mut CALLS = setup();

// CALLS.append(Call{
//     to: contract_address_const::<123456>(),
//     selector: 0x123,
//     calldata: ArrayTrait::new()
// });

// CALLS.append(Call{
//     to: contract_address_const::<123456>(),
//     selector: 0x123,
//     calldata: ArrayTrait::new()
// });

// Account::__execute__(CALLS);
}

#[test]
#[available_gas(2000000)]
fn test_test_retun_value() { // todo: requires call_contract_syscall
}

#[test]
#[available_gas(2000000)]
fn test_nonce() { // todo: requires call_contract_syscall
}

#[test]
#[available_gas(2000000)]
fn test_public_key_setter() {
    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(ACCOUNT_ADDRESS());
    Account::set_public_key(NEW_KEY());

    let public_key = Account::get_public_key();
    assert(public_key == NEW_KEY(), 'Should update key');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: unauthorized', ))]
fn test_public_key_setter_different_account() {
    testing::set_contract_address(ACCOUNT_ADDRESS());
    testing::set_caller_address(OTHER());
    Account::set_public_key(NEW_KEY());
}

// #[test]
// #[available_gas(2000000)]
// #[should_panic(expected: ('Account: invalid caller', ))]
// fn test_account_called_from_contract() {
//     let CALLS = setup();
//     testing::set_caller_address(OTHER());
//     Account::__execute__(CALLS);
// }

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
    testing::set_caller_address(OTHER());
    Account::_assert_only_self();
}

#[test]
#[available_gas(2000000)]
fn test__is_valid_signature_valid() { // todo: requires a signer
}

#[test]
#[available_gas(2000000)]
fn test__is_valid_signature_invalid() {
    let invalid_msg = 0xfffff;
    let mut invalid_signature = ArrayTrait::new();
    invalid_signature.append(0x987);
    invalid_signature.append(0x564);

    let is_valid = Account::_is_valid_signature(invalid_msg, invalid_signature.span());
    assert(!is_valid, 'Should reject invalid signature');
}

#[test]
#[available_gas(2000000)]
fn test__execute_calls() { // todo: requires call_contract_syscall
}

#[test]
#[available_gas(2000000)]
fn test__execute_single_call() { // todo: requires call_contract_syscall
}
