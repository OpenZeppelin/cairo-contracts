use openzeppelin_testing::constants::{TRANSACTION_HASH, stark};
use openzeppelin_testing::declare_and_deploy;
use openzeppelin_testing::signing::SerializedSigning;
use starknet::ContractAddress;
use crate::utils::assert_valid_signature;

//
// Setup
//

fn setup() -> ContractAddress {
    let key_pair = stark::KEY_PAIR();
    let mut calldata = array![];
    key_pair.public_key.serialize(ref calldata);
    declare_and_deploy("DualCaseAccountMock", calldata)
}

//
// assert_valid_signature
//

#[test]
fn test_assert_valid_signature_valid() {
    let account_address = setup();
    let key_pair = stark::KEY_PAIR();

    // Create a valid signature
    let hash = TRANSACTION_HASH;
    let signature = key_pair.serialized_sign(hash);
    let signature_span = signature.span();

    // Should not panic
    assert_valid_signature(account_address, hash, signature_span, 'Invalid signature');
}

#[test]
#[should_panic(expected: 'Invalid signature')]
fn test_assert_valid_signature_invalid_signature() {
    let account_address = setup();

    let hash = TRANSACTION_HASH;
    // Create an invalid signature
    let invalid_signature = array![0x123, 0x456].span();

    // Should panic with custom error message
    assert_valid_signature(account_address, hash, invalid_signature, 'Invalid signature');
}

#[test]
#[should_panic(expected: 'Custom error msg')]
fn test_assert_valid_signature_custom_error() {
    let account_address = setup();

    let hash = TRANSACTION_HASH;
    let invalid_signature = array![0x123, 0x456].span();

    // Should panic with the custom error message we provide
    assert_valid_signature(account_address, hash, invalid_signature, 'Custom error msg');
}
