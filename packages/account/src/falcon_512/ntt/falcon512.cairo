// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.1 (account/src/falcon_512/ntt/falcon512.cairo)

//! Falcon parameter set for the NTT engine: `q = 12289` and negacyclic ring `(x^n + 1)`.
//! The generated root tables use the evaluation order expected by the accounts' packed
//! NTT-domain public keys.

use super::bitrev::bitrev_512;
use super::engine::NttConfig;
use super::roots_felt::get_even_roots_felt;
use super::roots_scaled::get_scaled_inv_roots;

/// The Falcon modulus q = 12289 = 12·1024 + 1.
pub const Q: u16 = 12289;
/// q as a felt.
pub const Q_FELT: felt252 = 12289;
/// 2^-1 mod q.
pub const I2_FELT: felt252 = 6145;
/// Reduced values are < q < 2^14.
pub const REDUCED_BITS: u32 = 14;
/// Unreduced pointwise products of two reduced values are < q^2 < 2^28.
pub const PRODUCT_BITS: u32 = 28;
/// Exclusive bound for unreduced products of two reduced values; each product fits
/// [`PRODUCT_BITS`] bits.
pub const PRODUCT_BOUND_FELT: felt252 = 151019521;

/// Engine configuration for the production size n = 512 (table-driven permutation).
pub fn config() -> NttConfig {
    config_with_perm(512, 9, bitrev_512())
}

/// Engine configuration for a supported power-of-two degree from 4 through 512, computing the
/// bit-reversal permutation programmatically. `levels` must equal `log2(n)`. Tests and auxiliary
/// tooling use this function; production callers use [`config`], which reads the pinned table.
pub fn config_for_degree(n: u32, levels: u32) -> NttConfig {
    let mut perm: Array<u16> = array![];
    let mut i: u32 = 0;
    while i != n {
        let mut x = i;
        let mut acc: u32 = 0;
        let mut j: u32 = 0;
        while j != levels {
            acc = 2 * acc + (x % 2);
            x = x / 2;
            j += 1;
        }
        perm.append(acc.try_into().unwrap());
        i += 1;
    }
    config_with_perm(n, levels, perm.span())
}

fn config_with_perm(n: u32, levels: u32, perm: Span<u16>) -> NttConfig {
    // Root-table spans, one per level: level ℓ merges into size 2^(ℓ+1). The tables
    // are stored as felt252 constants (generated), so no per-call conversion runs.
    let mut merge_roots: Array<Span<felt252>> = array![];
    let mut split_scaled: Array<Span<felt252>> = array![];
    let mut size: u32 = 2;
    loop {
        merge_roots.append(get_even_roots_felt(size));
        split_scaled.append(get_scaled_inv_roots(size));
        if size == n {
            break;
        }
        size = 2 * size;
    }
    NttConfig {
        n,
        levels,
        q_nz: 12289,
        q_felt: Q_FELT,
        i2_felt: I2_FELT,
        qbits: REDUCED_BITS,
        fwd_growth_felt: 12290, // q + 1
        fwd_growth_bits: 14,
        inv_growth_felt: 24578, // 2q
        inv_growth_bits: 15,
        perm,
        merge_roots: merge_roots.span(),
        split_roots_scaled: split_scaled.span(),
    }
}
