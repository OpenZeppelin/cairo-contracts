// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo vX.Y.Z (account/utils/signature.cairo)

use ecdsa::check_ecdsa_signature;
use openzeppelin::account::eth_account::interface::EthPublicKey;
use openzeppelin::account::utils::secp256k1::Secp256k1PointPartialEq;
use starknet::eth_signature::Signature;
use starknet::secp256_trait::{is_signature_entry_valid, recover_public_key};
use starknet::secp256k1::Secp256k1Point;


fn is_valid_signature(msg_hash: felt252, public_key: felt252, signature: Span<felt252>) -> bool {
    let valid_length = signature.len() == 2;

    if valid_length {
        check_ecdsa_signature(msg_hash, public_key, *signature.at(0_u32), *signature.at(1_u32))
    } else {
        false
    }
}

fn is_valid_eth_signature(
    msg_hash: felt252, public_key: EthPublicKey, signature: Span<felt252>
) -> bool {
    let mut signature = signature;
    let signature: Signature = Serde::deserialize(ref signature).unwrap();

    // Signature out of range
    if !is_signature_entry_valid::<Secp256k1Point>(signature.r) {
        return false;
    }
    if !is_signature_entry_valid::<Secp256k1Point>(signature.s) {
        return false;
    }

    let public_key_point: Secp256k1Point = recover_public_key(msg_hash.into(), signature).unwrap();
    if public_key_point != public_key {
        // Invalid signature
        return false;
    }
    true
}
