// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.1 (account/src/falcon_512/verifier_impls.cairo)

use super::hashing::hash_to_point::hash_to_point_shake_512;
use super::verifier::Falcon512SignatureVerifier;
use super::{falcon, packing};

/// Number of felts in a packed Falcon-512 public key.
pub(crate) const PUBLIC_KEY_FELTS: u32 = 29;

/// Number of felts in a Falcon-512 signature carrying a product hint.
pub(crate) const SIGNATURE_FELTS: u32 = 60;

/// Number of felts in a direct Falcon-512 signature.
pub(crate) const DIRECT_SIGNATURE_FELTS: u32 = 31;

/// Verifier for the 60-felt SHAKE-256 signature carrying a polynomial-product hint.
pub impl Falcon512ShakeVerifier of Falcon512SignatureVerifier {
    fn verify(message_hash: felt252, public_key: Span<felt252>, signature: Span<felt252>) -> bool {
        if public_key.len() != PUBLIC_KEY_FELTS || signature.len() != SIGNATURE_FELTS {
            return false;
        }
        let h_ntt = match packing::unpack_512_u16(public_key) {
            Some(value) => value,
            None => { return false; },
        };
        let s1 = match packing::unpack_512_u16(signature.slice(0, 29)) {
            Some(value) => value,
            None => { return false; },
        };
        let salt_a = *signature.at(29);
        let salt_b = *signature.at(30);
        let mul_hint = match packing::unpack_512_u16(signature.slice(31, 29)) {
            Some(value) => value,
            None => { return false; },
        };
        let message_point = match hash_to_point_shake_512(message_hash, salt_a, salt_b) {
            Some(value) => value,
            None => { return false; },
        };
        falcon::verify_512_with_hint_u16(
            s1.span(), h_ntt.span(), mul_hint.span(), message_point.span(),
        )
    }

    fn is_valid_public_key(public_key: Span<felt252>) -> bool {
        if public_key.len() != PUBLIC_KEY_FELTS {
            return false;
        }
        match packing::unpack_512_u16(public_key) {
            Some(_) => true,
            None => false,
        }
    }
}

/// Verifier for the 31-felt SHAKE-256 signature that recomputes the product on-chain.
pub impl Falcon512ShakeDirectVerifier of Falcon512SignatureVerifier {
    fn verify(message_hash: felt252, public_key: Span<felt252>, signature: Span<felt252>) -> bool {
        if public_key.len() != PUBLIC_KEY_FELTS || signature.len() != DIRECT_SIGNATURE_FELTS {
            return false;
        }
        let h_ntt = match packing::unpack_512_u16(public_key) {
            Some(value) => value,
            None => { return false; },
        };
        let s1 = match packing::unpack_512_u16(signature.slice(0, 29)) {
            Some(value) => value,
            None => { return false; },
        };
        let salt_a = *signature.at(29);
        let salt_b = *signature.at(30);
        let message_point = match hash_to_point_shake_512(message_hash, salt_a, salt_b) {
            Some(value) => value,
            None => { return false; },
        };
        falcon::verify_512_direct_u16(s1.span(), h_ntt.span(), message_point.span())
    }

    fn is_valid_public_key(public_key: Span<felt252>) -> bool {
        Falcon512ShakeVerifier::is_valid_public_key(public_key)
    }
}
