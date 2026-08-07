// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.1 (account/src/falcon_512/ntt/engine.cairo)

//! Iterative NTT engine with felt252 lazy reduction.
//!
//! # Algorithm
//!
//! This computes exactly the recursive split/merge NTT of tprest/falcon.py (the
//! convention s2morrow and the Falcon-512 verifier use), reformulated iteratively:
//!
//! - **Forward** ([`ntt`]): permute the input into recursion-leaf order (bit reversal),
//!   then run merge levels bottom-up. The level merging blocks into size `2h` reads two
//!   half-blocks `f0`, `f1` sequentially and appends `f0[i] ± w[i]·f1[i]` interleaved —
//!   every read and write is sequential, matching Cairo's append-only arrays. The
//!   permutation is fused into the first level (`h = 1`), which is also specialized:
//!   its blocks are single butterflies sharing one root.
//! - **Inverse** ([`intt`]): the exact mirror — split levels top-down (reading
//!   interleaved pairs, writing the two half-blocks), then one fused
//!   permute-and-reduce pass back to natural order. The per-level `1/2` factor is
//!   folded into the pre-scaled inverse root tables (`tinv[i] = 2^-1 · w[i]^-1 mod q`).
//!   The last level (`h = 1`) writes adjacent outputs and needs no half-block buffer.
//!
//! Generic levels with `h >= 8` run 8-way unrolled over `multi_pop_front` chunks.
//!
//! # Lazy reduction (the Starknet optimization)
//!
//! Coefficients are carried as raw `felt252` integers WITHOUT per-operation modular
//! reduction: a butterfly is one field multiplication and a few field additions
//! (~1 step each), instead of the mul + divmod + range-check chain of eager `% q`
//! arithmetic. Subtractions are made non-negative by adding `off = bound · q` — a
//! multiple of q, so residues are unchanged.
//!
//! Soundness of the delay: the engine tracks an exclusive upper `bound` on the
//! coefficient integers (exactly, as a felt) and its bit size (conservatively).
//! Per forward level `bound *= q+1`; per inverse level `bound *= 2q`. Before a level
//! that could push values to 2^126 or beyond, and once at the end, a reduction pass
//! maps every coefficient to `[0, q)` via u128 divmod. Since all intermediates stay
//! below 2^126 < P/2^125, felt252 arithmetic never wraps and every reduction input
//! fits u128. For q = 12289 this schedule costs exactly TWO passes per 512-point
//! transform. [`ntt_lazy`] additionally exposes the transform WITHOUT its final
//! reduction pass, returning the tracked `(bits, bound)` alongside the unreduced
//! values, so callers whose follow-up arithmetic tolerates the bound (a divisibility
//! check, a lazy-product INTT) can skip that pass entirely.
//! The generated tables and forward transform are tested against the recursive
//! reference on random and adversarial inputs.

use core::traits::DivRem;

/// Everything a parameter set provides to the engine. Spans make configs cheap to
/// build and copy; see `falcon512::config()` for the canonical instance.
#[derive(Copy, Drop)]
pub struct NttConfig {
    /// Transform size (a power of two).
    pub n: u32,
    /// log2(n): number of merge/split levels.
    pub levels: u32,
    /// The modulus, as a u128 divisor for reduction passes.
    pub q_nz: NonZero<u128>,
    /// The modulus as a felt (offset construction).
    pub q_felt: felt252,
    /// 2^-1 mod q (even branch of the inverse split).
    pub i2_felt: felt252,
    /// Bit size of a reduced value: values in [0, q) fit `qbits` bits.
    pub qbits: u32,
    /// Per-forward-level bound growth, exact and in bits: bound *= q+1.
    pub fwd_growth_felt: felt252,
    pub fwd_growth_bits: u32,
    /// Per-inverse-level bound growth, exact and in bits: bound *= 2q.
    pub inv_growth_felt: felt252,
    pub inv_growth_bits: u32,
    /// Leaf permutation (self-inverse bit reversal), entries < n.
    pub perm: Span<u16>,
    /// Merge root tables: index ℓ holds the size-2^(ℓ+1) table (length 2^ℓ).
    pub merge_roots: Span<Span<felt252>>,
    /// I2-prescaled inverse root tables, same indexing as `merge_roots`.
    pub split_roots_scaled: Span<Span<felt252>>,
}

/// Intermediates must stay below 2^126: felt252 arithmetic cannot wrap (2^126 ≪ P)
/// and reduction inputs fit u128.
const SAFE_BITS: u32 = 126;

/// Reduce every coefficient to `[0, q)`. Inputs must be < 2^128 (guaranteed by the
/// engine's bound schedule). 8-way unrolled.
fn reduce_pass(mut vals: Span<felt252>, q_nz: NonZero<u128>) -> Array<felt252> {
    let mut out: Array<felt252> = array![];
    while let Some(chunk) = vals.multi_pop_front::<8>() {
        let [v0, v1, v2, v3, v4, v5, v6, v7] = (*chunk).unbox();
        let (_, r0) = DivRem::div_rem(TryInto::<felt252, u128>::try_into(v0).unwrap(), q_nz);
        let (_, r1) = DivRem::div_rem(TryInto::<felt252, u128>::try_into(v1).unwrap(), q_nz);
        let (_, r2) = DivRem::div_rem(TryInto::<felt252, u128>::try_into(v2).unwrap(), q_nz);
        let (_, r3) = DivRem::div_rem(TryInto::<felt252, u128>::try_into(v3).unwrap(), q_nz);
        let (_, r4) = DivRem::div_rem(TryInto::<felt252, u128>::try_into(v4).unwrap(), q_nz);
        let (_, r5) = DivRem::div_rem(TryInto::<felt252, u128>::try_into(v5).unwrap(), q_nz);
        let (_, r6) = DivRem::div_rem(TryInto::<felt252, u128>::try_into(v6).unwrap(), q_nz);
        let (_, r7) = DivRem::div_rem(TryInto::<felt252, u128>::try_into(v7).unwrap(), q_nz);
        out.append(r0.into());
        out.append(r1.into());
        out.append(r2.into());
        out.append(r3.into());
        out.append(r4.into());
        out.append(r5.into());
        out.append(r6.into());
        out.append(r7.into());
    }
    while let Some(v) = vals.pop_front() {
        let vu: u128 = (*v).try_into().unwrap();
        let (_, rem) = DivRem::div_rem(vu, q_nz);
        out.append(rem.into());
    }
    out
}

/// Reduce a single lazily-computed value (< 2^128) to `[0, q)`.
pub fn reduce_felt(v: felt252, q_nz: NonZero<u128>) -> felt252 {
    let vu: u128 = v.try_into().unwrap();
    let (_, rem) = DivRem::div_rem(vu, q_nz);
    rem.into()
}

/// One generic merge level: blocks of output size `2h`; `f0`/`f1` are each block's
/// half-spans, outputs interleave `f0[i] ± w[i]·f1[i]` (offset keeps them non-negative).
#[inline]
fn merge_level(
    src: Span<felt252>, roots: Span<felt252>, n: u32, h: u32, off: felt252,
) -> Array<felt252> {
    let mut out: Array<felt252> = array![];
    let mut b: u32 = 0;
    if h >= 8 {
        while b != n {
            let mut f0 = src.slice(b, h);
            let mut f1 = src.slice(b + h, h);
            let mut r = roots;
            while let Some(rc) = r.multi_pop_front::<8>() {
                let [w0, w1, w2, w3, w4, w5, w6, w7] = (*rc).unbox();
                let [a0, a1, a2, a3, a4, a5, a6, a7] = (*f0.multi_pop_front::<8>().unwrap())
                    .unbox();
                let [b0, b1, b2, b3, b4, b5, b6, b7] = (*f1.multi_pop_front::<8>().unwrap())
                    .unbox();
                let t0 = w0 * b0;
                out.append(a0 + t0);
                out.append(a0 + off - t0);
                let t1 = w1 * b1;
                out.append(a1 + t1);
                out.append(a1 + off - t1);
                let t2 = w2 * b2;
                out.append(a2 + t2);
                out.append(a2 + off - t2);
                let t3 = w3 * b3;
                out.append(a3 + t3);
                out.append(a3 + off - t3);
                let t4 = w4 * b4;
                out.append(a4 + t4);
                out.append(a4 + off - t4);
                let t5 = w5 * b5;
                out.append(a5 + t5);
                out.append(a5 + off - t5);
                let t6 = w6 * b6;
                out.append(a6 + t6);
                out.append(a6 + off - t6);
                let t7 = w7 * b7;
                out.append(a7 + t7);
                out.append(a7 + off - t7);
            }
            b += 2 * h;
        }
    } else {
        while b != n {
            let mut f0 = src.slice(b, h);
            let mut f1 = src.slice(b + h, h);
            let mut r = roots;
            while let Some(w) = r.pop_front() {
                let x0 = *f0.pop_front().unwrap();
                let x1 = *f1.pop_front().unwrap();
                let t = *w * x1;
                out.append(x0 + t);
                out.append(x0 + off - t);
            }
            b += 2 * h;
        }
    }
    out
}

/// Forward NTT. `f` must hold `cfg.n` coefficients in `[0, q)`. Returns the transform
/// in the parameter set's evaluation order, reduced to `[0, q)`.
pub fn ntt(f: Span<felt252>, cfg: @NttConfig) -> Array<felt252> {
    let (out, _, _) = ntt_core(f, cfg);
    reduce_pass(out.span(), *cfg.q_nz)
}

/// Forward NTT without the final reduction pass: the same transform as [`ntt`], with
/// outputs returned as unreduced integers congruent to the reduced transform mod q.
/// Returns `(values, bits, bound)` where `bound` is the exact exclusive upper bound on
/// the output integers under the engine's reduction schedule and `bits` its
/// conservative bit size. Callers fold the bound into their own arithmetic (e.g. a
/// divisibility check or a lazy-product INTT) instead of paying a full reduction pass.
pub fn ntt_lazy(f: Span<felt252>, cfg: @NttConfig) -> (Array<felt252>, u32, felt252) {
    ntt_core(f, cfg)
}

/// The merge levels shared by [`ntt`] and [`ntt_lazy`], inlined into both so neither
/// entry point pays an extra call boundary.
#[inline(always)]
fn ntt_core(f: Span<felt252>, cfg: @NttConfig) -> (Array<felt252>, u32, felt252) {
    let n = *cfg.n;
    assert(f.len() == n, 'ntt: bad input length');
    let q_felt = *cfg.q_felt;
    let q_nz = *cfg.q_nz;
    let qbits = *cfg.qbits;
    let growth_felt = *cfg.fwd_growth_felt;
    let growth_bits = *cfg.fwd_growth_bits;
    let merge_roots = *cfg.merge_roots;

    // Level h = 1, fused with the leaf permutation: block b is the single butterfly
    // (f[perm[2b]], f[perm[2b+1]]), and every block shares the size-2 table's one root.
    let r0 = *(*merge_roots.at(0)).at(0);
    let off0 = q_felt * q_felt; // bound = q
    let mut cur: Array<felt252> = array![];
    let mut perm = *cfg.perm;
    while let Some(pc) = perm.multi_pop_front::<2>() {
        let [p0, p1] = (*pc).unbox();
        let x0 = *f.at(p0.into());
        let x1 = *f.at(p1.into());
        let t = r0 * x1;
        cur.append(x0 + t);
        cur.append(x0 + off0 - t);
    }
    let mut bits: u32 = qbits + growth_bits;
    let mut bound: felt252 = q_felt * growth_felt;

    // Remaining merge levels.
    let mut h: u32 = 2;
    let mut level: u32 = 1;
    while h != n {
        if bits + growth_bits > SAFE_BITS {
            cur = reduce_pass(cur.span(), q_nz);
            bits = qbits;
            bound = q_felt;
        }
        // off = bound·q: a multiple of q dominating any w·x1 (w < q, x1 < bound), so
        // odd outputs stay non-negative with residues unchanged.
        cur = merge_level(cur.span(), *merge_roots.at(level), n, h, bound * q_felt);
        // Outputs < bound + q·bound = bound·(q+1).
        bound = bound * growth_felt;
        bits += growth_bits;
        h = 2 * h;
        level += 1;
    }
    (cur, bits, bound)
}

/// One generic split level: read interleaved pairs per block of size `2h`, write the
/// even results followed by the buffered odd half-block.
#[inline]
fn split_level(
    src: Span<felt252>, tinv: Span<felt252>, i2: felt252, n: u32, h: u32, off: felt252,
) -> Array<felt252> {
    let mut out: Array<felt252> = array![];
    let mut b: u32 = 0;
    if h >= 8 {
        while b != n {
            let mut pairs = src.slice(b, 2 * h);
            let mut r = tinv;
            let mut tmp: Array<felt252> = array![];
            while let Some(rc) = r.multi_pop_front::<4>() {
                let [w0, w1, w2, w3] = (*rc).unbox();
                let [x00, x01, x10, x11, x20, x21, x30, x31] = (*pairs
                    .multi_pop_front::<8>()
                    .unwrap())
                    .unbox();
                out.append(i2 * (x00 + x01));
                tmp.append(w0 * x00 + off - w0 * x01);
                out.append(i2 * (x10 + x11));
                tmp.append(w1 * x10 + off - w1 * x11);
                out.append(i2 * (x20 + x21));
                tmp.append(w2 * x20 + off - w2 * x21);
                out.append(i2 * (x30 + x31));
                tmp.append(w3 * x30 + off - w3 * x31);
            }
            let mut ts = tmp.span();
            while let Some(tc) = ts.multi_pop_front::<4>() {
                let [t0, t1, t2, t3] = (*tc).unbox();
                out.append(t0);
                out.append(t1);
                out.append(t2);
                out.append(t3);
            }
            b += 2 * h;
        }
    } else {
        while b != n {
            let mut pairs = src.slice(b, 2 * h);
            let mut r = tinv;
            let mut tmp: Array<felt252> = array![];
            while let Some(w) = r.pop_front() {
                let x0 = *pairs.pop_front().unwrap();
                let x1 = *pairs.pop_front().unwrap();
                out.append(i2 * (x0 + x1));
                tmp.append(*w * x0 + off - *w * x1);
            }
            let mut ts = tmp.span();
            while let Some(v) = ts.pop_front() {
                out.append(*v);
            }
            b += 2 * h;
        }
    }
    out
}

/// Inverse NTT. `f` must hold `cfg.n` values below `2^input_bits` (as integers), with
/// `input_bound` their exact exclusive bound: pass `(cfg.qbits, cfg.q_felt)` for
/// reduced inputs, or the product bound for unreduced pointwise products (the
/// lazy-product path: `intt(a_ntt ∘ b_ntt)` without reducing the products first).
/// Returns coefficients in natural order, reduced to `[0, q)`.
pub fn intt(
    f: Span<felt252>, input_bits: u32, input_bound: felt252, cfg: @NttConfig,
) -> Array<felt252> {
    let n = *cfg.n;
    assert(f.len() == n, 'intt: bad input length');
    let q_felt = *cfg.q_felt;
    let q_nz = *cfg.q_nz;
    let qbits = *cfg.qbits;
    let i2 = *cfg.i2_felt;
    let growth_felt = *cfg.inv_growth_felt;
    let growth_bits = *cfg.inv_growth_bits;
    let split_roots = *cfg.split_roots_scaled;
    assert(input_bits + growth_bits <= SAFE_BITS, 'intt: input too large');

    // Split levels top-down (h = n/2 .. 2 generic; h = 1 specialized below).
    let mut bits: u32 = input_bits;
    let mut bound: felt252 = input_bound;
    let mut cur: Array<felt252> = array![];
    let mut src0 = f;
    while let Some(v) = src0.pop_front() {
        cur.append(*v);
    }
    let mut h: u32 = n / 2;
    let mut level: u32 = *cfg.levels - 1;
    while h != 1 {
        if bits + growth_bits > SAFE_BITS {
            cur = reduce_pass(cur.span(), q_nz);
            bits = qbits;
            bound = q_felt;
        }
        cur = split_level(cur.span(), *split_roots.at(level), i2, n, h, bound * q_felt);
        // Both branches < 2q·bound.
        bound = bound * growth_felt;
        bits += growth_bits;
        h = h / 2;
        level -= 1;
    }

    // Last level (h = 1): every block is one adjacent pair sharing the size-2 scaled
    // root — outputs are adjacent too, so no half-block buffering.
    if bits + growth_bits > SAFE_BITS {
        cur = reduce_pass(cur.span(), q_nz);
        bound = q_felt;
    }
    let t0 = *(*split_roots.at(0)).at(0);
    let off = bound * q_felt;
    let src = cur.span();
    let mut last: Array<felt252> = array![];
    let mut pairs = src;
    while let Some(pc) = pairs.multi_pop_front::<2>() {
        let [x0, x1] = (*pc).unbox();
        last.append(i2 * (x0 + x1));
        last.append(t0 * x0 + off - t0 * x1);
    }

    // Fused final pass: bit-reversal back to natural order + reduction.
    let out_src = last.span();
    let mut out: Array<felt252> = array![];
    let mut perm = *cfg.perm;
    while let Some(p) = perm.pop_front() {
        let vu: u128 = (*out_src.at((*p).into())).try_into().unwrap();
        let (_, rem) = DivRem::div_rem(vu, q_nz);
        out.append(rem.into());
    }
    out
}
