use openzeppelin::account::utils::signature::{is_valid_stark_signature, is_valid_eth_signature};
use openzeppelin::tests::account::test_account::SIGNED_TX_DATA as stark_signature_data;
use openzeppelin::tests::account::test_eth_account::SIGNED_TX_DATA as eth_signature_data;
use starknet::secp256k1::Secp256k1Impl;

//
// is_valid_stark_signature
//

#[test]
fn test_is_valid_stark_signature_good_sig() {
    let data = stark_signature_data();
    let hash = data.transaction_hash;

    let mut good_signature = array![data.r, data.s].span();

    let is_valid = is_valid_stark_signature(hash, data.public_key, good_signature);
    assert!(is_valid);
}

#[test]
fn test_is_valid_stark_signature_bad_sig() {
    let data = stark_signature_data();
    let hash = data.transaction_hash;

    let mut bad_signature = array![0x987, 0x564].span();

    let is_invalid = !is_valid_stark_signature(hash, data.public_key, bad_signature);
    assert!(is_invalid);
}

#[test]
fn test_is_valid_stark_signature_invalid_len_sig() {
    let data = stark_signature_data();
    let hash = data.transaction_hash;

    let mut bad_signature = array![0x987].span();

    let is_invalid = !is_valid_stark_signature(hash, data.public_key, bad_signature);
    assert!(is_invalid);
}

//
// is_valid_eth_signature
//

#[test]
fn test_is_valid_eth_signature_good_sig() {
    let data = eth_signature_data();
    let hash = data.transaction_hash;

    let mut serialized_good_signature = array![];

    data.signature.serialize(ref serialized_good_signature);

    let is_valid = is_valid_eth_signature(hash, data.public_key, serialized_good_signature.span());
    assert!(is_valid);
}

#[test]
fn test_is_valid_eth_signature_bad_sig() {
    let data = eth_signature_data();
    let hash = data.transaction_hash;
    let mut bad_signature = data.signature;

    bad_signature.r += 1;

    let mut serialized_bad_signature = array![];

    bad_signature.serialize(ref serialized_bad_signature);

    let is_invalid = !is_valid_eth_signature(
        hash, data.public_key, serialized_bad_signature.span()
    );
    assert!(is_invalid);
}

#[test]
#[should_panic(expected: ('Signature: Invalid format.',))]
fn test_is_valid_eth_signature_invalid_format_sig() {
    let data = eth_signature_data();
    let hash = data.transaction_hash;

    let mut serialized_bad_signature = array![0x1];

    is_valid_eth_signature(hash, data.public_key, serialized_bad_signature.span());
}

#[test]
fn test_signature_r_out_of_range() {
    let data = eth_signature_data();
    let hash = data.transaction_hash;
    let mut bad_signature = data.signature;

    let curve_size = Secp256k1Impl::get_curve_size();

    bad_signature.r = curve_size + 1;

    let mut serialized_bad_signature = array![];

    bad_signature.serialize(ref serialized_bad_signature);

    let is_invalid = !is_valid_eth_signature(
        hash, data.public_key, serialized_bad_signature.span()
    );
    assert!(is_invalid);
}

#[test]
fn test_signature_s_out_of_range() {
    let data = eth_signature_data();
    let hash = data.transaction_hash;
    let mut bad_signature = data.signature;

    let curve_size = Secp256k1Impl::get_curve_size();

    bad_signature.s = curve_size + 1;

    let mut serialized_bad_signature = array![];

    bad_signature.serialize(ref serialized_bad_signature);

    let is_invalid = !is_valid_eth_signature(
        hash, data.public_key, serialized_bad_signature.span()
    );
    assert!(is_invalid);
}
