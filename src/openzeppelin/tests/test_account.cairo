use array::ArrayTrait;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing::set_caller_address;
use starknet::testing::set_contract_address;
use openzeppelin::account::Account;
use openzeppelin::account::ERC165_ACCOUNT_ID;
use openzeppelin::account::ERC1271_VALIDATED;
use openzeppelin::account::Call;
use openzeppelin::introspection::erc165::IERC165_ID;

fn NEW_KEY() -> felt252 { 0x444444 }
fn PUBLIC_KEY() -> felt252 { 0x333333 }
fn OTHER() -> ContractAddress { contract_address_const::<0x222222>() }
fn ACCOUNT_ADDRESS() -> ContractAddress { contract_address_const::<0x111111>() }

fn setup() -> Array::<Call> {
    let mut CALLS = ArrayTrait::new();

    CALLS.append(Call{
        to: contract_address_const::<123456>(),
        selector: 0x123,
        calldata: ArrayTrait::new()
    });

    set_contract_address(ACCOUNT_ADDRESS());
    Account::constructor(PUBLIC_KEY());

    return CALLS;
}

#[test]
#[available_gas(2000000)]
fn test_counterfactual_deployment() {
}

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
    // todo: requires mocking TxInfo

    // let CALLS = setup();
    // Account::__validate__(CALLS);
}

#[test]
#[available_gas(2000000)]
fn test_declare() {
    // todo: requires mocking TxInfo

    // setup();
    // let class_hash: felt252 = 0x123;
    // Account::__validate_declare__(class_hash);
}

#[test]
#[available_gas(2000000)]
fn test_execute() {
    // todo: requires call_contract_syscall

    // let CALLS = setup();
    // Account::__execute__(CALLS);
}

#[test]
#[available_gas(2000000)]
fn test_multicall() {
    // todo: requires call_contract_syscall

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
#[should_panic(expected = ('Account: unauthorized', ))]
fn test_public_key_setter_different_account() {
    setup();
    set_caller_address(OTHER());
    Account::set_public_key(NEW_KEY());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('Account: invalid caller', ))]
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
#[should_panic(expected = ('Account: unauthorized', ))]
fn test__assert_only_self_false() {
    setup();
    set_caller_address(OTHER());
    Account::_assert_only_self();
}

#[test]
#[available_gas(2000000)]
fn test_validate_transaction() {
    // todo: requires mocking TxInfo
}

#[test]
#[available_gas(2000000)]
fn test__is_valid_signature_valid() {
    // todo: requires a signer
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
fn test__execute_calls() {
    // todo: requires call_contract_syscall
}

#[test]
#[available_gas(2000000)]
fn test__execute_single_call() {
    // todo: requires call_contract_syscall
}
