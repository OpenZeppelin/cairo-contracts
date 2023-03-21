use starknet::ContractAddress;
use openzeppelin::account::Account;
use openzeppelin::account::ACCOUNT_ID;
use openzeppelin::account::Call;
use openzeppelin::introspection::erc165::IERC165_ID;

const PUB_KEY: felt252 = 0x123;

const TO: ContractAddress = 0x123;
const SELECTOR: felt252 = 0x312;
const CALLDATA: Array<felt252> = array<felt252>();
const CALL: Call = Call{TO, SELECTOR, CALLDATA};
const CALLS: Array<Call> = array<Call>(CALL);

fn setup() {
    Account::constructor(PUB_KEY);
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
    assert(public_key == PUB_KEY, 'Should return pub key');
}

#[test]
#[available_gas(2000000)]
fn test_interface() {
    setup();
    let supports_default_interface: bool = Account::supports_interface(IERC165_ID);
    assert(supports_default_interface, 'Should support base interface');

    let supports_account_interface: bool = Account::supports_interface(ACCOUNT_ID);
    assert(supports_account_interface, 'Should support account id');
}

#[test]
#[available_gas(2000000)]
fn test_is_valid_signature() {
    setup();

    let message = 0x1123;
    let good_sig_r = 0x123;
    let good_sig_s = 0x123;
    let bad_sig_r = 0x123;
    let bad_sig_s = 0x123;

    let is_valid: bool = Account::is_valid_signature(message, good_sig_r, good_sig_s);
    assert(! is_valid, 'Should accept valid signature');

    let is_valid: bool = Account::is_valid_signature(message, bad_sig_r, bad_sig_s);
    assert(! is_valid, 'Should reject invalid signature');
}

#[test]
#[available_gas(2000000)]
fn test_validate() {
    setup();
    Account::__validate__(CALLS);
}

#[test]
#[available_gas(2000000)]
fn test_declare() {
    setup();
    let class_hash: felt252 = 0x123;
    Account::__validate_declare__(class_hash);
}

#[test]
#[available_gas(2000000)]
fn test_execute() {
    setup();
    Account::__execute__(CALLS);
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
