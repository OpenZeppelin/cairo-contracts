use array::ArrayTrait;
use core::result::ResultTrait;
use debug::PrintTrait;
use option::OptionTrait;
use starknet::class_hash::Felt252TryIntoClassHash;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::syscalls::deploy_syscall;
use starknet::testing::set_caller_address;
use starknet::testing::set_contract_address;
use starknet::testing::set_transaction_hash;
use starknet::testing;
use starknet::testing::set_signature;
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
struct ValidSignature {
    private_key: felt252,
    public_key: felt252,
    message: felt252,
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
fn VALID_SIGNATURE() -> ValidSignature {
    ValidSignature {
        private_key: 1234,
        public_key: 883045738439352841478194533192765345509759306772397516907181243450667673002,
        message: 2717105892474786771566982177444710571376803476229898722748888396642649184538,
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

fn setup() -> Array::<Call> {
    set_contract_address(ACCOUNT_ADDRESS());
    Account::constructor(PUBLIC_KEY());

    CALLS()
}

fn setup_dispatcher() -> IAccountDispatcher {
    let sig_data = VALID_SIGNATURE();

    // Deploy the account contract
    let mut calldata = ArrayTrait::<felt252>::new();
    calldata.append(sig_data.public_key);
    let (address, _) = deploy_syscall(
        Account::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();

    // Set the transaction version and hash
    testing::set_version(TRANSACTION_VERSION);
    set_transaction_hash(sig_data.message);

    // Set the signature
    let mut signature = ArrayTrait::new();
    signature.append(sig_data.r);
    signature.append(sig_data.s);
    set_signature(signature.span());

    IAccountDispatcher { contract_address: address }
}

#[test]
#[available_gas(2000000)]
fn test_counterfactual_deployment() {}

#[test]
#[available_gas(2000000)]
fn test_constructor() {
    setup();
    let public_key: felt252 = Account::get_public_key();
    assert(public_key == PUBLIC_KEY(), 'Should return pub key');
}

#[test]
#[available_gas(2000000)]
fn test_interface() {
    setup();
    let supports_default_interface: bool = Account::supports_interface(IERC165_ID);
    assert(supports_default_interface, 'Should support base interface');

    let supports_account_interface: bool = Account::supports_interface(ERC165_ACCOUNT_ID);
    assert(supports_account_interface, 'Should support account id');
}

#[test]
#[available_gas(2000000)]
fn test_is_valid_signature() {
    setup();
    let message = 0x1123;

    // todo: generate signatures
    let mut good_signature = ArrayTrait::new();
    good_signature.append(0x123);
    good_signature.append(0x456);

    let mut bad_signature = ArrayTrait::new();
    bad_signature.append(0x987);
    bad_signature.append(0x564);

    let is_valid = Account::is_valid_signature(message, good_signature.span());
    assert(is_valid == 0_u32, 'Should accept valid signature');

    let is_valid = Account::is_valid_signature(message, bad_signature.span());
    assert(is_valid == 0_u32, 'Should reject invalid signature');
}

#[test]
#[available_gas(2000000)]
fn test_validate() {
    let calls = CALLS();
    let account = setup_dispatcher();

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
fn test_execute() {
    let account = setup_dispatcher();
    let sig_data = VALID_SIGNATURE();

    assert(account.get_public_key() == sig_data.public_key, 'Should get initial public key');

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
fn test_test_retun_value() {
    setup();
// todo: requires call_contract_syscall
}

#[test]
#[available_gas(2000000)]
fn test_nonce() {
    setup();
// todo: requires call_contract_syscall
}

#[test]
#[available_gas(2000000)]
fn test_public_key_setter() {
    setup();
    set_caller_address(ACCOUNT_ADDRESS());
    Account::set_public_key(NEW_KEY());

    let public_key = Account::get_public_key();
    assert(public_key == NEW_KEY(), 'Should update key');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: unauthorized', ))]
fn test_public_key_setter_different_account() {
    setup();
    set_caller_address(OTHER());
    Account::set_public_key(NEW_KEY());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: invalid caller', ))]
fn test_account_called_from_contract() {
    let CALLS = setup();
    set_caller_address(OTHER());
    Account::__execute__(CALLS);
}

//
// test internals
//

#[test]
#[available_gas(2000000)]
fn test__assert_only_self_true() {
    setup();
    set_caller_address(ACCOUNT_ADDRESS());
    Account::_assert_only_self();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Account: unauthorized', ))]
fn test__assert_only_self_false() {
    setup();
    set_caller_address(OTHER());
    Account::_assert_only_self();
}

#[test]
#[available_gas(2000000)]
fn test_validate_transaction() {
    let account = setup_dispatcher();

    assert(account.__validate_declare__(4444) == starknet::VALIDATED, 'Should validate correctly');
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
