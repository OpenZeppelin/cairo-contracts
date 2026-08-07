// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.1
// (account/src/falcon_512/hashing/hash_to_point.cairo)

//! SHAKE-256 hash-to-point for the legacy Falcon-512 submission algorithm.
//!
//! The function absorbs a 40-byte salt followed by the message hash's 32-byte
//! little-endian representation. It reads the SHAKE-256 output as big-endian u16 words
//! and rejection-samples each word into Z_q until it has 512 coefficients.

use super::shake256::keccak_f1600;

/// Rejection bound: the largest multiple of q = 12289 below 2^16.
const REJECT_BOUND: u32 = 61445;

/// Each salt felt must fit in 20 bytes.
const TWO_POW_160: u256 = 0x10000000000000000000000000000000000000000;

/// Hashes `(message_hash, salt)` to 512 coefficients in `[0, 12289)`.
///
/// Returns `None` if either salt felt exceeds 20 bytes.
pub(crate) fn hash_to_point_shake_512(
    message_hash: felt252, salt_a: felt252, salt_b: felt252,
) -> Option<Array<u16>> {
    let sa: u256 = salt_a.into();
    let sb: u256 = salt_b.into();
    if sa >= TWO_POW_160 || sb >= TWO_POW_160 {
        return None;
    }
    let mh: u256 = message_hash.into();

    // The 72-byte input fits one SHAKE-256 rate block. Bytes 0..40 hold the salt,
    // bytes 40..72 hold the message hash, byte 72 is the SHAKE domain byte, and byte
    // 135 is the pad10*1 terminator.
    let two64: NonZero<u128> = 0x10000000000000000_u128.try_into().unwrap();
    let two32: NonZero<u128> = 0x100000000_u128.try_into().unwrap();
    let (a1, a0) = DivRem::div_rem(sa.low, two64);
    let (sbq, sb0) = DivRem::div_rem(sb.low, two32);
    let (sb12, l3) = DivRem::div_rem(sbq, two64);
    let (m1, m0) = DivRem::div_rem(mh.low, two64);
    let (m3, m2) = DivRem::div_rem(mh.high, two64);
    let l2: u128 = (sa.high.into() + sb0.into() * 0x100000000).try_into().unwrap();
    let l4: u128 = (sb12.into() + sb.high.into() * 0x100000000).try_into().unwrap();

    let mut state = keccak_f1600(
        [
            a0, a1, l2, l3, l4, m0, m1, m2, m3, 0x1f, 0, 0, 0, 0, 0, 0, 0x8000000000000000, 0, 0, 0,
            0, 0, 0, 0, 0,
        ],
    );

    let q32: NonZero<u32> = 12289_u32.try_into().unwrap();
    let two16: NonZero<u64> = 0x10000_u64.try_into().unwrap();
    let b256: NonZero<u64> = 0x100_u64.try_into().unwrap();
    let mut coeffs: Array<u16> = array![];
    loop {
        let mut lanes = state.span().slice(0, 17);
        while let Some(lane) = lanes.pop_front() {
            push_lane_words(*lane, two16, b256, q32, ref coeffs);
        }
        if coeffs.len() == 512 {
            break;
        }
        state = keccak_f1600(state);
    }
    Some(coeffs)
}

/// Reads one squeezed lane as four big-endian u16 candidate words.
#[inline(always)]
fn push_lane_words(
    lane: u128, two16: NonZero<u64>, b256: NonZero<u64>, q32: NonZero<u32>, ref coeffs: Array<u16>,
) {
    let lane64: u64 = lane.try_into().unwrap();
    let (rest, c0) = DivRem::div_rem(lane64, two16);
    let (rest, c1) = DivRem::div_rem(rest, two16);
    let (c3, c2) = DivRem::div_rem(rest, two16);

    let (b1, b0) = DivRem::div_rem(c0, b256);
    push_candidate((b0 * 256 + b1).try_into().unwrap(), q32, ref coeffs);
    let (b1, b0) = DivRem::div_rem(c1, b256);
    push_candidate((b0 * 256 + b1).try_into().unwrap(), q32, ref coeffs);
    let (b1, b0) = DivRem::div_rem(c2, b256);
    push_candidate((b0 * 256 + b1).try_into().unwrap(), q32, ref coeffs);
    let (b1, b0) = DivRem::div_rem(c3, b256);
    push_candidate((b0 * 256 + b1).try_into().unwrap(), q32, ref coeffs);
}

/// Appends `candidate mod q` when the word lies below the rejection bound and the
/// output is not complete.
#[inline(always)]
fn push_candidate(candidate: u32, q32: NonZero<u32>, ref coeffs: Array<u16>) {
    if coeffs.len() != 512 && candidate < REJECT_BOUND {
        let (_, remainder) = DivRem::div_rem(candidate, q32);
        coeffs.append(remainder.try_into().unwrap());
    }
}

#[cfg(test)]
mod tests {
    use super::{REJECT_BOUND, TWO_POW_160, hash_to_point_shake_512, push_candidate};

    #[test]
    fn test_hash_to_point_reference_vector() {
        // Independently generated with Python hashlib.shake_256 over
        // salt_a[20 LE] || salt_b[20 LE] || message_hash[32 LE].
        let coefficients = hash_to_point_shake_512(3, 1, 2).unwrap();
        assert_eq!(coefficients.len(), 512);
        assert_eq!(
            coefficients.span().slice(0, 8),
            [2750, 10132, 11472, 1877, 11061, 11208, 12103, 6446].span(),
        );
        assert_eq!(coefficients.span().slice(254, 6), [937, 8133, 7551, 334, 4678, 4603].span());
        assert_eq!(
            coefficients.span().slice(504, 8),
            [5448, 3366, 6941, 8171, 6950, 4708, 3646, 5435].span(),
        );
    }

    #[test]
    fn test_hash_to_point_domain_separation() {
        let base = hash_to_point_shake_512(3, 1, 2).unwrap();
        assert_ne!(base.span(), hash_to_point_shake_512(4, 1, 2).unwrap().span());
        assert_ne!(base.span(), hash_to_point_shake_512(3, 2, 1).unwrap().span());
        assert_ne!(base.span(), hash_to_point_shake_512(3, 1, 3).unwrap().span());
    }

    #[test]
    fn test_hash_to_point_salt_bounds() {
        let too_big: felt252 = TWO_POW_160.try_into().unwrap();
        assert!(hash_to_point_shake_512(3, too_big, 0).is_none());
        assert!(hash_to_point_shake_512(3, 0, too_big).is_none());
        assert!(hash_to_point_shake_512(3, too_big - 1, too_big - 1).is_some());
    }

    #[test]
    fn test_push_candidate_accept_reject_and_complete_branches() {
        let q32: NonZero<u32> = 12289_u32.try_into().unwrap();
        let mut coefficients: Array<u16> = array![];

        push_candidate(12290, q32, ref coefficients);
        assert_eq!(coefficients.span(), [1].span());

        push_candidate(REJECT_BOUND, q32, ref coefficients);
        assert_eq!(coefficients.len(), 1);

        while coefficients.len() != 512 {
            coefficients.append(0);
        }
        push_candidate(1, q32, ref coefficients);
        assert_eq!(coefficients.len(), 512);
    }
}
