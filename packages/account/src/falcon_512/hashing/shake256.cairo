// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.1 (account/src/falcon_512/hashing/shake256.cairo)

//! SHAKE-256 extendable-output function (FIPS 202), implemented in pure Cairo.
//!
//! Written from the FIPS 202 specification (Keccak-f[1600] sponge, rate 1088 bits =
//! 136 bytes, capacity 512, domain-separation `0x1F`, pad10*1). Starknet exposes no
//! SHAKE primitive and its `keccak` syscall bakes in keccak256's `0x01` padding and a
//! fixed 256-bit output, so neither is reusable here; the permutation is implemented
//! directly. A future `keccak_f1600` syscall (SNIP-32) would replace [`keccak_f1600`]
//! and collapse the cost.
//!
//! State: 25 lanes of 64 bits, `lane[x + 5y]`, bytes mapped little-endian per lane.
//!
//! The permutation dominates on-chain cost, so it is written flat:
//! - each round is a straight-line expression over 25 lane locals — no round-local
//!   arrays, no index arithmetic, no table lookups; θ is fused into the ρ+π terms and
//!   ι into the first χ lane;
//! - lanes are carried as `u128` — the bitwise builtin's native operand width — so
//!   XOR/AND need no per-operation downcast. The `< 2^64` lane invariant is
//!   maintained structurally: XOR/AND of 64-bit values is 64-bit, complements are
//!   `MASK64 - b` (exact on 64-bit values, no builtin), and rotations reassemble
//!   disjoint bit ranges below bit 64;
//! - rotations are division-free: every rotation amount is baked in as its power of
//!   two, so a left-rotate is one felt252 multiply and one u128 `div_rem` by 2^64 —
//!   the wrapped high bits and the shifted low bits occupy disjoint positions, so
//!   their sum is the rotation.
//!
//! [`keccak_f1600`] is shared with the hash-to-point squeezer
//! (`hash_to_point::hash_to_point_shake_512`), which drives the sponge lazily and
//! reads candidates straight from the rate lanes; the byte-oriented [`shake256`] here
//! is the generic XOF, pinned to the FIPS 202 known-answer vectors below.

const MASK64: u128 = 0xffffffffffffffff;
const RATE_LANES: u32 = 17; // 136 bytes / 8
const RATE_BYTES: u32 = 136;

/// Keccak-f[1600] round constants (FIPS 202, Table 1).
const ROUND_CONSTANTS: [u128; 24] = [
    0x0000000000000001, 0x0000000000008082, 0x800000000000808a, 0x8000000080008000,
    0x000000000000808b, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
    0x000000000000008a, 0x0000000000000088, 0x0000000080008009, 0x000000008000000a,
    0x000000008000808b, 0x800000000000008b, 0x8000000000008089, 0x8000000000008003,
    0x8000000000008002, 0x8000000000000080, 0x000000000000800a, 0x800000008000000a,
    0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
];

/// Rotate a 64-bit lane left, given `pow = 2^r` with 0 < r < 64. The widened felt
/// product `x * 2^r < 2^127` splits at bit 64 into the bits that stay (`lo`) and the
/// bits that wrap to the bottom (`hi`); they occupy disjoint positions, so `lo + hi`
/// is the rotation.
#[inline(always)]
fn rotl(x: u128, pow: felt252, two64: NonZero<u128>) -> u128 {
    let wide: u128 = (x.into() * pow).try_into().unwrap();
    let (hi, lo) = DivRem::div_rem(wide, two64);
    lo + hi
}

/// Keccak-f[1600]: 24 rounds of θ, ρ, π, χ, ι on the 25-lane state, fully unrolled
/// over lane locals. The ρ+π terms read `b[dst] = rotl(a[src] ^ d[src mod 5], ρ[dst])`
/// with the π source indices and ρ offsets from FIPS 202, precomposed per destination.
pub(crate) fn keccak_f1600(state: [u128; 25]) -> [u128; 25] {
    let two64: NonZero<u128> = 0x10000000000000000_u128.try_into().unwrap();
    let mut s = state;
    for rc in ROUND_CONSTANTS.span() {
        let rc = *rc;
        let [
            s00,
            s01,
            s02,
            s03,
            s04,
            s05,
            s06,
            s07,
            s08,
            s09,
            s10,
            s11,
            s12,
            s13,
            s14,
            s15,
            s16,
            s17,
            s18,
            s19,
            s20,
            s21,
            s22,
            s23,
            s24,
        ] =
            s;

        // theta: column parities and the per-column mixing term d[x] = c[x-1] ^ rotl(c[x+1], 1).
        let c0 = s00 ^ s05 ^ s10 ^ s15 ^ s20;
        let c1 = s01 ^ s06 ^ s11 ^ s16 ^ s21;
        let c2 = s02 ^ s07 ^ s12 ^ s17 ^ s22;
        let c3 = s03 ^ s08 ^ s13 ^ s18 ^ s23;
        let c4 = s04 ^ s09 ^ s14 ^ s19 ^ s24;
        let d0 = c4 ^ rotl(c1, 0x2, two64);
        let d1 = c0 ^ rotl(c2, 0x2, two64);
        let d2 = c1 ^ rotl(c3, 0x2, two64);
        let d3 = c2 ^ rotl(c4, 0x2, two64);
        let d4 = c3 ^ rotl(c0, 0x2, two64);

        // theta (fused) + rho + pi, straight into destination order.
        let b00 = s00 ^ d0;
        let b01 = rotl(s06 ^ d1, 0x100000000000, two64);
        let b02 = rotl(s12 ^ d2, 0x80000000000, two64);
        let b03 = rotl(s18 ^ d3, 0x200000, two64);
        let b04 = rotl(s24 ^ d4, 0x4000, two64);
        let b05 = rotl(s03 ^ d3, 0x10000000, two64);
        let b06 = rotl(s09 ^ d4, 0x100000, two64);
        let b07 = rotl(s10 ^ d0, 0x8, two64);
        let b08 = rotl(s16 ^ d1, 0x200000000000, two64);
        let b09 = rotl(s22 ^ d2, 0x2000000000000000, two64);
        let b10 = rotl(s01 ^ d1, 0x2, two64);
        let b11 = rotl(s07 ^ d2, 0x40, two64);
        let b12 = rotl(s13 ^ d3, 0x2000000, two64);
        let b13 = rotl(s19 ^ d4, 0x100, two64);
        let b14 = rotl(s20 ^ d0, 0x40000, two64);
        let b15 = rotl(s04 ^ d4, 0x8000000, two64);
        let b16 = rotl(s05 ^ d0, 0x1000000000, two64);
        let b17 = rotl(s11 ^ d1, 0x400, two64);
        let b18 = rotl(s17 ^ d2, 0x8000, two64);
        let b19 = rotl(s23 ^ d3, 0x100000000000000, two64);
        let b20 = rotl(s02 ^ d2, 0x4000000000000000, two64);
        let b21 = rotl(s08 ^ d3, 0x80000000000000, two64);
        let b22 = rotl(s14 ^ d4, 0x8000000000, two64);
        let b23 = rotl(s15 ^ d0, 0x20000000000, two64);
        let b24 = rotl(s21 ^ d1, 0x4, two64);

        // chi (complement as MASK64 - b), with iota folded into lane 0.
        s =
            [
                b00 ^ ((MASK64 - b01) & b02) ^ rc, b01 ^ ((MASK64 - b02) & b03),
                b02 ^ ((MASK64 - b03) & b04), b03 ^ ((MASK64 - b04) & b00),
                b04 ^ ((MASK64 - b00) & b01), b05 ^ ((MASK64 - b06) & b07),
                b06 ^ ((MASK64 - b07) & b08), b07 ^ ((MASK64 - b08) & b09),
                b08 ^ ((MASK64 - b09) & b05), b09 ^ ((MASK64 - b05) & b06),
                b10 ^ ((MASK64 - b11) & b12), b11 ^ ((MASK64 - b12) & b13),
                b12 ^ ((MASK64 - b13) & b14), b13 ^ ((MASK64 - b14) & b10),
                b14 ^ ((MASK64 - b10) & b11), b15 ^ ((MASK64 - b16) & b17),
                b16 ^ ((MASK64 - b17) & b18), b17 ^ ((MASK64 - b18) & b19),
                b18 ^ ((MASK64 - b19) & b15), b19 ^ ((MASK64 - b15) & b16),
                b20 ^ ((MASK64 - b21) & b22), b21 ^ ((MASK64 - b22) & b23),
                b22 ^ ((MASK64 - b23) & b24), b23 ^ ((MASK64 - b24) & b20),
                b24 ^ ((MASK64 - b20) & b21),
            ];
    }
    s
}

/// SHAKE-256: absorb `input`, squeeze `out_bytes` bytes.
pub(crate) fn shake256(input: Array<u8>, out_bytes: u32) -> Array<u8> {
    // Pad (pad10*1 with SHAKE domain 0x1F) to a multiple of the rate.
    let mut padded = input;
    let l = padded.len();
    let pad_len = RATE_BYTES - (l % RATE_BYTES); // in [1, RATE_BYTES]
    padded.append(0x1f);
    let mut z = 1;
    while z != pad_len {
        padded.append(0);
        z += 1;
    }
    let last_idx = l + pad_len - 1;
    let bytes = pad_ored_msb(padded, last_idx);

    // Absorb rate-sized blocks: XOR each block's 17 lanes into the state, permute.
    let mut state = [0; 25];
    let n_blocks = (l + pad_len) / RATE_BYTES;
    let mut blk = 0;
    while blk != n_blocks {
        let base = blk * RATE_BYTES;
        let [
            s00,
            s01,
            s02,
            s03,
            s04,
            s05,
            s06,
            s07,
            s08,
            s09,
            s10,
            s11,
            s12,
            s13,
            s14,
            s15,
            s16,
            s17,
            s18,
            s19,
            s20,
            s21,
            s22,
            s23,
            s24,
        ] =
            state;
        state =
            keccak_f1600(
                [
                    s00 ^ load_lane_le(@bytes, base), s01 ^ load_lane_le(@bytes, base + 8),
                    s02 ^ load_lane_le(@bytes, base + 16), s03 ^ load_lane_le(@bytes, base + 24),
                    s04 ^ load_lane_le(@bytes, base + 32), s05 ^ load_lane_le(@bytes, base + 40),
                    s06 ^ load_lane_le(@bytes, base + 48), s07 ^ load_lane_le(@bytes, base + 56),
                    s08 ^ load_lane_le(@bytes, base + 64), s09 ^ load_lane_le(@bytes, base + 72),
                    s10 ^ load_lane_le(@bytes, base + 80), s11 ^ load_lane_le(@bytes, base + 88),
                    s12 ^ load_lane_le(@bytes, base + 96), s13 ^ load_lane_le(@bytes, base + 104),
                    s14 ^ load_lane_le(@bytes, base + 112), s15 ^ load_lane_le(@bytes, base + 120),
                    s16 ^ load_lane_le(@bytes, base + 128), s17, s18, s19, s20, s21, s22, s23, s24,
                ],
            );
        blk += 1;
    }

    // Squeeze rate-sized blocks, permuting only when more output is needed.
    let mut out: Array<u8> = array![];
    loop {
        let mut lanes = state.span().slice(0, RATE_LANES);
        while let Some(lane) = lanes.pop_front() {
            emit_lane_le(*lane, ref out, out_bytes);
        }
        if out.len() == out_bytes {
            break;
        }
        state = keccak_f1600(state);
    }
    out
}

/// Append up to 8 little-endian bytes of the lane `v` (< 2^64), stopping at `out_bytes`.
fn emit_lane_le(v: u128, ref out: Array<u8>, out_bytes: u32) {
    let mut rem: u64 = v.try_into().unwrap();
    let mut k = 0;
    while k != 8 && out.len() < out_bytes {
        out.append((rem % 256).try_into().unwrap());
        rem = rem / 256;
        k += 1;
    }
}

/// Rebuild `bytes` with `bytes[idx] |= 0x80` (that byte is < 0x80 here, so `+ 0x80`).
fn pad_ored_msb(bytes: Array<u8>, idx: u32) -> Array<u8> {
    let mut out: Array<u8> = array![];
    let span = bytes.span();
    let mut i = 0;
    while i != span.len() {
        if i == idx {
            out.append(*span[i] + 0x80);
        } else {
            out.append(*span[i]);
        }
        i += 1;
    }
    out
}

/// Little-endian 64-bit lane from 8 bytes at `off`.
fn load_lane_le(bytes: @Array<u8>, off: u32) -> u128 {
    let span = bytes.span();
    let mut acc: u128 = 0;
    let mut k = 8;
    while k != 0 {
        k -= 1;
        acc = acc * 256 + (*span[off + k]).into();
    }
    acc
}

#[cfg(test)]
mod tests {
    use super::shake256;

    fn to_hex(bytes: Array<u8>) -> ByteArray {
        let hexchars: ByteArray = "0123456789abcdef";
        let mut s: ByteArray = "";
        let mut span = bytes.span();
        while let Some(b) = span.pop_front() {
            s.append_byte(hexchars.at((*b / 16).into()).unwrap());
            s.append_byte(hexchars.at((*b % 16).into()).unwrap());
        }
        s
    }

    // KAT vectors from Python `hashlib.shake_256` (FIPS 202).
    #[test]
    fn test_shake256_empty() {
        let got = to_hex(shake256(array![], 32));
        assert!(got == "46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762f");
    }

    #[test]
    fn test_shake256_abc() {
        let got = to_hex(shake256(array![0x61, 0x62, 0x63], 32));
        assert!(got == "483366601360a8771c6863080cc4114d8db44530f8f1e1ee4f94ea37e78b5739");
    }

    // 200 bytes of 0xA3: a 2-block absorb (input > 136-byte rate). NIST SHAKE-256 vector.
    #[test]
    fn test_shake256_multiblock() {
        let mut input: Array<u8> = array![];
        let mut i = 0;
        while i != 200 {
            input.append(0xa3);
            i += 1;
        }
        let got = to_hex(shake256(input, 32));
        assert!(got == "cd8a920ed141aa0407a22d59288652e9d9f1a7ee0c1e7c1ca699424da84a904d");
    }

    // Squeeze past one rate block (137 bytes > 136): exercises the squeeze-side
    // permutation. Tail bytes from Python `hashlib.shake_256(b"abc").hexdigest(137)`.
    #[test]
    fn test_shake256_multiblock_squeeze() {
        let out = shake256(array![0x61, 0x62, 0x63], 137);
        assert_eq!(out.len(), 137);
        // First bytes match the 32-byte KAT above.
        assert_eq!(*out.at(0), 0x48);
        assert_eq!(*out.at(1), 0x33);
        // Bytes 128.. of the stream: e8 a2 d7 ec 71 a7 cc 29 cf (last is out[136]).
        let tail: [u8; 9] = [0xe8, 0xa2, 0xd7, 0xec, 0x71, 0xa7, 0xcc, 0x29, 0xcf];
        let mut i: u32 = 128;
        for expected in tail.span() {
            assert_eq!(*out.at(i), *expected);
            i += 1;
        }
    }
}
