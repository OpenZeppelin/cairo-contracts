use starknet::ContractAddress;
use starknet::contract_address_const;
use array::ArrayTrait;
use openzeppelin::account::Account;
use openzeppelin::account::ERC165_ACCOUNT_ID;
use openzeppelin::account::ERC1271_VALIDATED;
use openzeppelin::account::Call;
use openzeppelin::introspection::erc165::IERC165_ID;

fn setup() -> (felt252, Array::<Call>) {
    let PUB_KEY: felt252 = 0x123;
    let mut CALLS = ArrayTrait::new();

    CALLS.append(Call{
        to: contract_address_const::<123456>(),
        selector: 0x123,
        calldata: ArrayTrait::new()
    });

    Account::constructor(PUB_KEY);

    return (PUB_KEY, CALLS);
}

#[test]
#[available_gas(2000000)]
fn test_counterfactual_deployment() {
}

#[test]
#[available_gas(2000000)]
fn test_constructor() {
    let (PUB_KEY, _) = setup();
    let public_key: felt252 = Account::get_public_key();
    assert(public_key == PUB_KEY, 'Should return pub key');
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

    let mut good_signature = ArrayTrait::new();
    good_signature.append(0x123);
    good_signature.append(0x456);

    let mut bad_signature = ArrayTrait::new();
    bad_signature.append(0x987);
    bad_signature.append(0x564);

    let is_valid = Account::is_valid_signature(message, good_signature.span());
    assert(is_valid == 0, 'Should accept valid signature');

    let is_valid = Account::is_valid_signature(message, bad_signature.span());
    assert(is_valid == 0, 'Should reject invalid signature');
}

#[test]
#[available_gas(2000000)]
fn test_validate() {
    let (_, CALLS) = setup();
    // Account::__validate__(CALLS);
}

#[test]
#[available_gas(2000000)]
fn test_declare() {
    setup();
    let class_hash: felt252 = 0x123;
    // Account::__validate_declare__(class_hash);
}

#[test]
#[available_gas(2000000)]
fn test_execute() {
    let (_, CALLS) = setup();
    // Account::__execute__(CALLS);
}

#[test]
#[available_gas(2000000)]
fn test_multicall() {
    setup();
}

#[test]
#[available_gas(2000000)]
fn test_test_retun_value() {
    setup();
}

#[test]
#[available_gas(2000000)]
fn test_nonce() {
    setup();
}

#[test]
#[available_gas(2000000)]
fn test_public_key_setter() {
    setup();
}

#[test]
#[available_gas(2000000)]
fn test_public_key_setter_different_account() {
    setup();
}

#[test]
#[available_gas(2000000)]
fn test_account_takeover_with_reentrant_call() {
    setup();
}
