// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.18.0 (account/utils/signature.cairo)

use core::ecdsa::check_ecdsa_signature;
use crate::interface::EthPublicKey;
use starknet::secp256_trait;

#[derive(Copy, Drop, Serde)]
pub struct EthSignature {
    pub r: u256,
    pub s: u256,
}

/// This function assumes the `s` component of the signature to be positive
/// for efficiency reasons. It is not recommended to use it other than for
/// validating account signatures over transaction hashes since otherwise
/// it's not protected against signature malleability.
/// See https://github.com/OpenZeppelin/cairo-contracts/issues/889.
pub fn is_valid_stark_signature(
    msg_hash: felt252, public_key: felt252, signature: Span<felt252>
) -> bool {
    let valid_length = signature.len() == 2;

    if valid_length {
        check_ecdsa_signature(msg_hash, public_key, *signature.at(0_u32), *signature.at(1_u32))
    } else {
        false
    }
}

/// This function assumes the `s` component of the signature to be positive
/// for efficiency reasons. It is not recommended to use it other than for
/// validating account signatures over transaction hashes since otherwise
/// it's not protected against signature malleability.
/// See https://github.com/OpenZeppelin/cairo-contracts/issues/889.
pub fn is_valid_eth_signature(
    msg_hash: felt252, public_key: EthPublicKey, signature: Span<felt252>
) -> bool {
    let mut signature = signature;
    let signature: EthSignature = Serde::deserialize(ref signature)
        .expect('Signature: Invalid format.');

    secp256_trait::is_valid_signature(msg_hash.into(), signature.r, signature.s, public_key)
}
