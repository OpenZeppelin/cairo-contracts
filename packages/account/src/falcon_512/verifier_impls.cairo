// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.1 (account/src/falcon_512/verifier_impls.cairo)

use super::hashing::hash_to_point::hash_to_point_shake_512;
use super::verifier::Falcon512SignatureVerifier;
use super::{falcon, packing};

/// Number of felts containing the Falcon salt.
const SALT_FELTS: u32 = 2;

/// Number of felts in a packed Falcon-512 public key.
pub(crate) const PUBLIC_KEY_FELTS: u32 = packing::PACKED_SLOTS;

/// Number of felts in a direct Falcon-512 signature.
pub(crate) const DIRECT_SIGNATURE_FELTS: u32 = PUBLIC_KEY_FELTS + SALT_FELTS;

/// Number of felts in a Falcon-512 signature carrying a product hint.
pub(crate) const SIGNATURE_FELTS: u32 = DIRECT_SIGNATURE_FELTS + PUBLIC_KEY_FELTS;

/// Decodes the public key, signature polynomial, and salt shared by both layouts.
fn decode_common(
    public_key: Span<felt252>, signature: Span<felt252>,
) -> Option<(Array<u16>, Array<u16>, felt252, felt252)> {
    let h_ntt = match packing::unpack_512_u16(public_key) {
        Some(value) => value,
        None => { return None; },
    };
    let s1 = match packing::unpack_512_u16(signature.slice(0, PUBLIC_KEY_FELTS)) {
        Some(value) => value,
        None => { return None; },
    };
    let salt_a = *signature.at(PUBLIC_KEY_FELTS);
    let salt_b = *signature.at(PUBLIC_KEY_FELTS + 1);
    Some((h_ntt, s1, salt_a, salt_b))
}

/// Verifier for the 60-felt SHAKE-256 signature carrying a polynomial-product hint.
pub impl Falcon512ShakeVerifier of Falcon512SignatureVerifier {
    fn verify(message_hash: felt252, public_key: Span<felt252>, signature: Span<felt252>) -> bool {
        if public_key.len() != PUBLIC_KEY_FELTS || signature.len() != SIGNATURE_FELTS {
            return false;
        }
        let (h_ntt, s1, salt_a, salt_b) = match decode_common(public_key, signature) {
            Some(value) => value,
            None => { return false; },
        };
        let mul_hint =
            match packing::unpack_512_u16(
                signature.slice(DIRECT_SIGNATURE_FELTS, PUBLIC_KEY_FELTS),
            ) {
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
        let (h_ntt, s1, salt_a, salt_b) = match decode_common(public_key, signature) {
            Some(value) => value,
            None => { return false; },
        };
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
