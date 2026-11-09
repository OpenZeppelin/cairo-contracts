// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.1
// (account/src/falcon_512/hashing/hash_to_point.cairo)

//! SHAKE-256 hash-to-point for the Falcon-512 submission algorithm.
//!
//! The function absorbs a 40-byte salt followed by the message hash's 32-byte
//! little-endian representation. It reads the SHAKE-256 output as big-endian `u16` words
//! and rejection-samples them until it has 512 accepted words.
//!
//! # Deferred reduction
//!
//! Accepted words are returned **unreduced** as [`MsgWord`] values in `[0, 61444]`
//! rather than residues in `[0, q)`: `REJECT_BOUND - 1 = 5q - 1` bounds every accepted
//! word. The verifier's norm pass reduces them as part of its centered-difference
//! computation, so reducing here would spend 512 divisions twice. Consumers that need
//! canonical residues reduce with `word mod q`.
//!
//! # Packed squeezing
//!
//! The sponge state stays in the packed two-lanes-per-`u128` representation of
//! [`keccak_f1600_packed`] across squeezed blocks. Each rate lane's eight bytes hold
//! four big-endian stream words byte-swapped (the lane bytes are little-endian), and a
//! packed pair is unswapped in one shot: adding `65535 * (w & EVEN_BYTES)` turns every
//! 16-bit chunk `b0 + 256*b1` into `256 * (256*b0 + b1)`, and one multiply by
//! `256^(-1) mod P` aligns all eight stream words to their 16-bit chunk positions.

use openzeppelin_corelib_imports::bounded_int::{
    BoundedInt, ConstrainHelper, DivRemHelper, UnitInt, bounded_int, constrain,
};
use crate::falcon_512::COEFFICIENT_COUNT;
use super::shake256::{keccak_f1600_packed, pack_lanes};

/// Rejection bound: the largest multiple of q = 12289 below 2^16.
const REJECT_BOUND: u32 = 61445;

/// Exclusive upper bound for each 20-byte salt limb.
const TWO_POW_160: u256 = 0x10000000000000000000000000000000000000000;

/// An accepted, unreduced hash-to-point word in `[0, REJECT_BOUND)`. Its canonical
/// coefficient is `word mod q`; the verifier folds that reduction into the norm pass.
pub(crate) type MsgWord = BoundedInt<0, 61444>;

/// A big-endian 16-bit stream word before rejection sampling.
type Word16 = BoundedInt<0, 65535>;
type Base16 = UnitInt<65536>;
const BASE16_NZ: NonZero<Base16> = 65536;

/// Low byte of every 16-bit chunk of a packed lane pair.
const EVEN_BYTES: u128 = 0xff00ff00ff00ff00ff00ff00ff00ff;

/// `256^(-1) mod P`: aligns the byte-swapped words (each scaled by 256) back onto
/// their 16-bit chunk positions in one field multiplication.
const INV_256: felt252 = 0x7f8000000000010ef0000000000000000000000000000000000000000000001;

/// Accepts a candidate word below [`REJECT_BOUND`], unreduced. The caller bounds the
/// output length.
#[inline(always)]
fn push_word(word: Word16, ref out: Array<MsgWord>) {
    if let Ok(accepted) = constrain::<Word16, 61445>(word) {
        out.append(accepted);
    }
}

/// Accepts a candidate word below [`REJECT_BOUND`] unless the output is complete.
#[inline(always)]
fn push_word_checked(word: Word16, ref out: Array<MsgWord>) {
    if out.len() != COEFFICIENT_COUNT {
        push_word(word, ref out);
    }
}

impl RejectSplit of ConstrainHelper<Word16, 61445> {
    type LowT = MsgWord;
    type HighT = BoundedInt<61445, 65535>;
}

// Quotient chain for extracting eight 16-bit words from a swapped lane pair.
type Chunks7 = BoundedInt<0, 0xffffffffffffffffffffffffffff>;
type Chunks6 = BoundedInt<0, 0xffffffffffffffffffffffff>;
type Chunks5 = BoundedInt<0, 0xffffffffffffffffffff>;
type Chunks4 = BoundedInt<0, 0xffffffffffffffff>;
type Chunks3 = BoundedInt<0, 0xffffffffffff>;
type Chunks2 = BoundedInt<0, 0xffffffff>;

impl Words8Step of DivRemHelper<u128, Base16> {
    type DivT = Chunks7;
    type RemT = Word16;
}
impl Words7Step of DivRemHelper<Chunks7, Base16> {
    type DivT = Chunks6;
    type RemT = Word16;
}
impl Words6Step of DivRemHelper<Chunks6, Base16> {
    type DivT = Chunks5;
    type RemT = Word16;
}
impl Words5Step of DivRemHelper<Chunks5, Base16> {
    type DivT = Chunks4;
    type RemT = Word16;
}
impl Words4Step of DivRemHelper<Chunks4, Base16> {
    type DivT = Chunks3;
    type RemT = Word16;
}
impl Words3Step of DivRemHelper<Chunks3, Base16> {
    type DivT = Chunks2;
    type RemT = Word16;
}
impl Words2Step of DivRemHelper<Chunks2, Base16> {
    type DivT = Word16;
    type RemT = Word16;
}

/// Byte-swaps all eight big-endian stream words of a packed lane pair at once.
///
/// Each 16-bit chunk of `w` holds a stream word with its bytes reversed
/// (`chunk = b0 + 256*b1` for the word `256*b0 + b1`). Adding `65535 * b0` per chunk
/// (selected by [`EVEN_BYTES`]) gives `65536*b0 + 256*b1 = 256 * word`; the chunks
/// then occupy disjoint bit ranges `[16i + 8, 16i + 24)`, so one multiplication by
/// `256^(-1) mod P` lands every word exactly on its chunk: the result is
/// `sum(word_i * 2^(16i)) < 2^128`.
#[inline(always)]
fn swap_words(w: u128) -> u128 {
    let even: u128 = w & EVEN_BYTES;
    let even: felt252 = even.into();
    let swapped: felt252 = (w.into() + even * 65535) * INV_256;
    swapped.try_into().unwrap()
}

/// Extracts the eight stream words of a swapped lane pair, in stream order.
#[inline(always)]
fn words8(swapped: u128) -> (Word16, Word16, Word16, Word16, Word16, Word16, Word16, Word16) {
    let (rest, w0) = bounded_int::div_rem(swapped, BASE16_NZ);
    let (rest, w1) = bounded_int::div_rem(rest, BASE16_NZ);
    let (rest, w2) = bounded_int::div_rem(rest, BASE16_NZ);
    let (rest, w3) = bounded_int::div_rem(rest, BASE16_NZ);
    let (rest, w4) = bounded_int::div_rem(rest, BASE16_NZ);
    let (rest, w5) = bounded_int::div_rem(rest, BASE16_NZ);
    let (w7, w6) = bounded_int::div_rem(rest, BASE16_NZ);
    (w0, w1, w2, w3, w4, w5, w6, w7)
}

/// Extracts the four stream words of a swapped pair's low lane, in stream order.
#[inline(always)]
fn words4(swapped: u128) -> (Word16, Word16, Word16, Word16) {
    let (rest, w0) = bounded_int::div_rem(swapped, BASE16_NZ);
    let (rest, w1) = bounded_int::div_rem(rest, BASE16_NZ);
    let (rest, w2) = bounded_int::div_rem(rest, BASE16_NZ);
    let (_, w3) = bounded_int::div_rem(rest, BASE16_NZ);
    (w0, w1, w2, w3)
}

/// Pushes a packed lane pair's eight candidate words without length checks.
#[inline(always)]
fn read_pair(w: u128, ref out: Array<MsgWord>) {
    let (w0, w1, w2, w3, w4, w5, w6, w7) = words8(swap_words(w));
    push_word(w0, ref out);
    push_word(w1, ref out);
    push_word(w2, ref out);
    push_word(w3, ref out);
    push_word(w4, ref out);
    push_word(w5, ref out);
    push_word(w6, ref out);
    push_word(w7, ref out);
}

/// Pushes a packed lane pair's eight candidate words, stopping at 512 outputs.
#[inline(always)]
fn read_pair_checked(w: u128, ref out: Array<MsgWord>) {
    let (w0, w1, w2, w3, w4, w5, w6, w7) = words8(swap_words(w));
    push_word_checked(w0, ref out);
    push_word_checked(w1, ref out);
    push_word_checked(w2, ref out);
    push_word_checked(w3, ref out);
    push_word_checked(w4, ref out);
    push_word_checked(w5, ref out);
    push_word_checked(w6, ref out);
    push_word_checked(w7, ref out);
}

/// Reads one squeezed block's 68 candidate words from the packed state in stream
/// order (lanes 0..16, four words per lane).
///
/// Packed layout (see `shake256`): positions 0..3 are the row pairs
/// `(lane[5y], lane[5y + 1])`, positions 5..7 the row pairs
/// `(lane[5y + 2], lane[5y + 3])`, position 10 is `(lane4, lane9)`, and position 11
/// holds rate lane 14 in its low half. When at least 68 outputs of room remain the
/// per-word completion checks are skipped: a block accepts at most 68 words.
fn read_block(state: @[u128; 13], ref out: Array<MsgWord>) {
    let [u0, u1, u2, u3, _, v0, v1, v2, _, _, col4, col14, _] = *state;
    let (g0, g1, g2, g3, g4, g5, g6, g7) = words8(swap_words(col4));
    if out.len() + 68 <= COEFFICIENT_COUNT {
        read_pair(u0, ref out);
        read_pair(v0, ref out);
        push_word(g0, ref out);
        push_word(g1, ref out);
        push_word(g2, ref out);
        push_word(g3, ref out);
        read_pair(u1, ref out);
        read_pair(v1, ref out);
        push_word(g4, ref out);
        push_word(g5, ref out);
        push_word(g6, ref out);
        push_word(g7, ref out);
        read_pair(u2, ref out);
        read_pair(v2, ref out);
        let (h0, h1, h2, h3) = words4(swap_words(col14));
        push_word(h0, ref out);
        push_word(h1, ref out);
        push_word(h2, ref out);
        push_word(h3, ref out);
        read_pair(u3, ref out);
    } else {
        read_pair_checked(u0, ref out);
        read_pair_checked(v0, ref out);
        push_word_checked(g0, ref out);
        push_word_checked(g1, ref out);
        push_word_checked(g2, ref out);
        push_word_checked(g3, ref out);
        read_pair_checked(u1, ref out);
        read_pair_checked(v1, ref out);
        push_word_checked(g4, ref out);
        push_word_checked(g5, ref out);
        push_word_checked(g6, ref out);
        push_word_checked(g7, ref out);
        read_pair_checked(u2, ref out);
        read_pair_checked(v2, ref out);
        let (h0, h1, h2, h3) = words4(swap_words(col14));
        push_word_checked(h0, ref out);
        push_word_checked(h1, ref out);
        push_word_checked(h2, ref out);
        push_word_checked(h3, ref out);
        read_pair_checked(u3, ref out);
    }
}

/// Hashes the 40-byte salt encoded by `(salt_a, salt_b)` and `message_hash` to
/// 512 accepted words in `[0, REJECT_BOUND)` (see [`MsgWord`] for the deferred
/// reduction contract).
///
/// Returns `None` if either salt felt exceeds 20 bytes.
pub(crate) fn hash_to_point_shake_512(
    message_hash: felt252, salt_a: felt252, salt_b: felt252,
) -> Option<Array<MsgWord>> {
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

    // The packed initial state (lane pairs as documented on `read_block`): lanes
    // 0..8 hold the input, lane 9 the domain byte 0x1f, lane 16 the pad terminator.
    let mut state = keccak_f1600_packed(
        [
            pack_lanes(a0, a1), pack_lanes(m0, m1), 0, pack_lanes(0, 0x8000000000000000), 0,
            pack_lanes(l2, l3), pack_lanes(m2, m3), 0, 0, 0, pack_lanes(l4, 0x1f), 0, 0,
        ],
    );

    let mut coeffs: Array<MsgWord> = array![];
    loop {
        read_block(@state, ref coeffs);
        if coeffs.len() == COEFFICIENT_COUNT {
            break;
        }
        state = keccak_f1600_packed(state);
    }
    Some(coeffs)
}

#[cfg(test)]
mod tests {
    use openzeppelin_corelib_imports::bounded_int::upcast;
    use crate::falcon_512::COEFFICIENT_COUNT;
    use crate::falcon_512::zq::Q32;
    use super::{MsgWord, REJECT_BOUND, TWO_POW_160, hash_to_point_shake_512, push_word_checked};

    /// Reduces the raw words to canonical residues for comparison with the
    /// independently generated reference vectors.
    fn reduced(mut words: Span<MsgWord>) -> Array<u16> {
        let mut out: Array<u16> = array![];
        while let Some(word) = words.pop_front() {
            let w: u32 = upcast(*word);
            assert!(w < REJECT_BOUND);
            out.append((w % Q32).try_into().unwrap());
        }
        out
    }

    #[test]
    fn test_hash_to_point_reference_vector() {
        // Independently generated with Python hashlib.shake_256 over
        // salt_a[20 LE] || salt_b[20 LE] || message_hash[32 LE].
        let coefficients = hash_to_point_shake_512(3, 1, 2).unwrap();
        assert_eq!(coefficients.len(), COEFFICIENT_COUNT);
        let r = reduced(coefficients.span());
        assert_eq!(
            r.span().slice(0, 8), [2750, 10132, 11472, 1877, 11061, 11208, 12103, 6446].span(),
        );
        assert_eq!(r.span().slice(254, 6), [937, 8133, 7551, 334, 4678, 4603].span());
        assert_eq!(r.span().slice(504, 8), [5448, 3366, 6941, 8171, 6950, 4708, 3646, 5435].span());
    }

    #[test]
    fn test_hash_to_point_domain_separation() {
        let base = reduced(hash_to_point_shake_512(3, 1, 2).unwrap().span());
        let m = reduced(hash_to_point_shake_512(4, 1, 2).unwrap().span());
        let a = reduced(hash_to_point_shake_512(3, 2, 1).unwrap().span());
        let b = reduced(hash_to_point_shake_512(3, 1, 3).unwrap().span());
        assert_ne!(base.span(), m.span());
        assert_ne!(base.span(), a.span());
        assert_ne!(base.span(), b.span());
    }

    #[test]
    fn test_hash_to_point_salt_bounds() {
        let too_big: felt252 = TWO_POW_160.try_into().unwrap();
        assert!(hash_to_point_shake_512(3, too_big, 0).is_none());
        assert!(hash_to_point_shake_512(3, 0, too_big).is_none());
        assert!(hash_to_point_shake_512(3, too_big - 1, too_big - 1).is_some());
    }

    #[test]
    fn test_push_word_accept_reject_and_complete_branches() {
        let mut coefficients: Array<MsgWord> = array![];

        // Accepted words are appended raw (12290 stays 12290, not 1).
        push_word_checked(12290, ref coefficients);
        assert_eq!(coefficients.len(), 1);
        let first: u32 = upcast(*coefficients.at(0));
        assert_eq!(first, 12290);

        // The smallest rejected word.
        push_word_checked(61445, ref coefficients);
        assert_eq!(coefficients.len(), 1);

        // The largest accepted word.
        push_word_checked(61444, ref coefficients);
        assert_eq!(coefficients.len(), 2);

        while coefficients.len() != COEFFICIENT_COUNT {
            coefficients.append(0);
        }
        push_word_checked(1, ref coefficients);
        assert_eq!(coefficients.len(), COEFFICIENT_COUNT);
    }

    /// Full raw-word differential vector generated with Python hashlib.shake_256: the
    /// stream needs more than eight squeezed blocks, contains the largest accepted word
    /// (61444), and rejects words at the boundary, pinning the unreduced output exactly.
    #[test]
    fn test_hash_to_point_raw_multiblock_boundary_vector() {
        let message_hash: felt252 =
            380110690622612157434603191659586944957169240878956695861017012378556359164;
        let salt_a: felt252 = 771544759463419516057861535142000034519634572842;
        let salt_b: felt252 = 517456117770424985249342813140939311781777731550;
        let expected: [u32; 512] = [
            48380, 21056, 11834, 57122, 45676, 24942, 22720, 17128, 15348, 4698, 38098, 57745,
            16812, 6190, 10737, 54044, 6326, 32170, 17860, 911, 19254, 50270, 3321, 28615, 2606,
            11825, 31107, 18126, 2227, 9315, 3655, 48309, 38287, 7081, 43675, 48224, 46100, 28993,
            58589, 14764, 993, 43599, 49170, 39270, 20495, 29099, 34453, 37505, 5590, 2454, 49200,
            25676, 59978, 17792, 33951, 26566, 23759, 21560, 662, 16356, 49887, 9833, 38651, 55055,
            30069, 58082, 53303, 16217, 42347, 5621, 12488, 41494, 91, 15882, 45371, 6598, 37499,
            32411, 52709, 36020, 1937, 61065, 13632, 4628, 12057, 25743, 57065, 49618, 18235, 18407,
            23491, 25229, 2088, 49370, 8674, 3224, 34144, 33905, 57160, 39247, 40479, 11017, 52994,
            8523, 13361, 44343, 49478, 19400, 19691, 19373, 49012, 30684, 31734, 19802, 61115,
            25170, 597, 41352, 21236, 17238, 26732, 6053, 12210, 39163, 56467, 55469, 30776, 55722,
            45053, 48401, 45507, 57801, 9091, 22042, 37840, 1650, 17499, 54782, 35447, 41277, 16254,
            32183, 55326, 31676, 48864, 748, 18037, 52653, 5672, 40611, 4620, 37432, 45053, 38835,
            17640, 15081, 58314, 30021, 15324, 1114, 30460, 43538, 28537, 50065, 23557, 10344,
            11762, 18550, 2249, 5483, 27211, 46370, 40693, 625, 19733, 53230, 61444, 29991, 33892,
            19272, 10811, 40801, 13956, 58494, 14415, 1479, 56546, 60491, 52977, 38910, 14735, 5165,
            13011, 6398, 35455, 12903, 26893, 32051, 18031, 48038, 6343, 28693, 35382, 12436, 41813,
            39477, 29064, 60099, 12553, 74, 33554, 52816, 32131, 186, 53906, 60761, 41820, 25625,
            41006, 28632, 5987, 24061, 28177, 52454, 23782, 48461, 49191, 4608, 35991, 50727, 18190,
            11071, 3052, 398, 41062, 51616, 44408, 16982, 17628, 41786, 31601, 3067, 17739, 16576,
            19835, 29639, 3533, 37779, 23302, 46999, 51412, 32079, 17759, 22367, 58541, 14401,
            44426, 47592, 21303, 50448, 58002, 9236, 39141, 21325, 39877, 28434, 51386, 28094,
            38293, 30135, 25258, 33291, 60880, 32760, 26542, 10194, 46151, 47520, 28104, 44511,
            48274, 35271, 18973, 47180, 1995, 23623, 55716, 815, 9515, 13649, 56017, 52595, 24447,
            45851, 6328, 40451, 45620, 40461, 14681, 2223, 38450, 23514, 3374, 2201, 27041, 34689,
            41413, 55111, 53454, 23786, 30989, 34705, 20241, 18694, 10599, 23502, 40517, 18606,
            52005, 5861, 28118, 37117, 28845, 6054, 13333, 42150, 45315, 32204, 14475, 21081, 46300,
            45005, 35040, 21751, 4847, 10314, 54785, 58021, 27688, 39407, 54182, 35940, 6676, 24455,
            18848, 30492, 18065, 3842, 21153, 32356, 38985, 60400, 9604, 27057, 42561, 43940, 45447,
            30994, 46508, 22838, 21742, 11869, 6143, 58468, 45433, 17059, 16525, 29099, 34371,
            52098, 17758, 17296, 5100, 38768, 26687, 46666, 8728, 14790, 60317, 6564, 42406, 52751,
            54813, 61155, 31772, 49216, 15476, 37643, 15922, 13475, 18323, 32311, 41741, 31225,
            9156, 7579, 54345, 47229, 4062, 6716, 36677, 3052, 12862, 41785, 34220, 35161, 35181,
            8087, 55182, 56879, 50209, 41596, 36556, 11563, 54007, 42942, 52518, 3275, 49313, 34689,
            34032, 11992, 8571, 690, 5122, 36449, 61008, 53976, 33260, 21818, 16916, 59375, 19861,
            10986, 11082, 60062, 36602, 27182, 8099, 53736, 44561, 39976, 5958, 2443, 42728, 48566,
            9832, 51977, 5, 41038, 21016, 16546, 6798, 6119, 22726, 6340, 50446, 6786, 38546, 21670,
            28036, 21050, 22847, 37642, 14441, 22069, 41605, 16673, 28434, 58436, 42255, 9555,
            50274, 11882, 27766, 3666, 1943, 32716, 42070, 9766, 19954, 44732, 21773, 39097, 6384,
            39715, 53938, 1769, 52376, 13786, 54956, 40442, 58147, 44725, 23211, 2027, 19665, 13339,
            55744, 60822, 21668, 964, 23496, 56119, 12903, 30543, 1050, 45896, 38685, 26941, 11926,
            10441,
        ];
        let words = hash_to_point_shake_512(message_hash, salt_a, salt_b).unwrap();
        assert_eq!(words.len(), COEFFICIENT_COUNT);
        let mut words = words.span();
        let mut index: u32 = 0;
        let expected = expected.span();
        while let Some(word) = words.pop_front() {
            let w: u32 = upcast(*word);
            assert_eq!(w, *expected.at(index));
            index += 1;
        }
    }
}
