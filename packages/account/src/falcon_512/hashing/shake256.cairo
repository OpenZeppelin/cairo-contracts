// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.1 (account/src/falcon_512/hashing/shake256.cairo)

//! Pure-Cairo SHAKE-256 extendable-output function from FIPS 202, with a packed
//! Keccak-f[1600] permutation.
//!
//! This module implements the Keccak-f[1600] sponge with a 1088-bit rate, 512-bit capacity,
//! `0x1F` domain separation, and pad10*1 padding. Starknet's `keccak` syscall implements
//! Keccak-256 with `0x01` padding and a fixed 256-bit output, so this module supplies the
//! permutation required by SHAKE-256 directly.
//!
//! # Packed state representation
//!
//! The permutation dominates on-chain cost, and that cost is dominated by the bitwise
//! builtin, whose native operand width is 128 bits. The state's 25 64-bit lanes
//! (`lane[x + 5y]`, bytes little-endian per lane) are therefore carried **two lanes per
//! `u128`** wherever the round functions operate on both halves uniformly, halving the
//! number of builtin invocations for theta's column parities and chi's selections:
//!
//! - [`keccak_f1600_packed`] takes and returns `[u128; 13]`: five row pairs
//!   `pair(lane[5y], lane[5y + 1])`, five row pairs `pair(lane[5y + 2], lane[5y + 3])`,
//!   the column-4 pairs `pair(lane4, lane9)` and `pair(lane14, lane19)`, and `lane24`.
//! - Rho rotates each lane by its own offset, so lanes are split to 64 bits for the
//!   rotation step and repacked for chi. Rotations are division-free: a left-rotation
//!   by `n` is one widening multiply by `2^n` and one bounded split at bit 64.
//! - Between rounds the pipeline keeps lanes in a rotated orientation and with some
//!   lanes complemented (chi in or-form), the standard Keccak lane-complementing
//!   transform; the round constants below absorb both adjustments.
//! - Rotate-by-one for theta's `D` terms runs on packed pairs directly, splitting each
//!   lane's top bit with `constrain` and wrapping it around arithmetically.
//!
//! The packing is an internal optimization only: the test-only [`keccak_f1600`] preserves
//! the plain 25-lane interface, and the permutation known-answer vectors plus the FIPS 202
//! XOF known-answer tests below pin both entry points to the standard.
//!
//! `hash_to_point::hash_to_point_shake_512` drives [`keccak_f1600_packed`] directly to
//! keep the state packed across squeezed blocks.

use openzeppelin_corelib_imports::bounded_int::{
    AddHelper, BoundedInt, ConstrainHelper, DivRemHelper, MulHelper, SubHelper, UnitInt, add,
    constrain, div_rem, mul, sub, upcast,
};

#[cfg(test)]
const RATE_LANES: u32 = 17; // 136 bytes / 8
#[cfg(test)]
const RATE_BYTES: u32 = 136;

/// Keccak-f[1600] round constants (FIPS 202, Table 1), each pre-rotated and
/// pre-positioned into the lane orientation the packed pipeline carries entering
/// that round's chi step. The final round's constant equals the FIPS value itself
/// because the state returns to the standard orientation there. Validated by the
/// permutation known-answer tests below.
const ROUND_CONSTANTS: [u128; 24] = [
    0x40000000000000000000000000000000, 0x20000000000008080000000000000000,
    0x2a000000000002020000000000000000, 0x800000008000800000000000000000,
    0x22c00000000000200000000000000000, 0x100000000800000000000000000000,
    0x2060000000200020000000000000000, 0x80098000000000000000000000000000,
    0x228000000000000000000000000000, 0x88000000000000000000000000000,
    0x2002400000002000000000000000000, 0xa00000000800000000000000000,
    0x2022c0000000200000000000000000, 0x8b8000000000000000000000000,
    0x20226000000000000000000000000, 0x800380000000, 0x28000000000008, 0x8080, 0x800a0000000,
    0xa800000008000, 0x800080818, 0x8080800000, 0x100000000800, 0x8000000080008008,
];
#[feature("bounded-int-utils")]
type TwoPow64 = UnitInt<0x10000000000000000>;
pub(crate) type Lane = BoundedInt<0, 0xffffffffffffffff>;
const TWO_POW_64_NZ: NonZero<TwoPow64> = 0x10000000000000000;
type Mask128 = UnitInt<0xffffffffffffffffffffffffffffffff>;
const MASK_128: Mask128 = 0xffffffffffffffffffffffffffffffff;
impl Not128 of SubHelper<Mask128, u128> {
    type Result = BoundedInt<0, 0xffffffffffffffffffffffffffffffff>;
}
#[inline(always)]
fn split_lanes(w: u128) -> (u128, u128) {
    let (high, low) = div_rem(w, TWO_POW_64_NZ);
    (upcast(high), upcast(low))
}

#[inline(always)]
pub(crate) fn pack_lanes(lo: u128, hi: u128) -> u128 {
    let packed: felt252 = lo.into() + hi.into() * 0x10000000000000000;
    packed.try_into().unwrap()
}
impl SplitPair of DivRemHelper<u128, TwoPow64> {
    type DivT = Lane;
    type RemT = Lane;
}
type TwoPow64Mul = UnitInt<0x10000000000000000>;
type HighHalf = BoundedInt<0, 0xffffffffffffffff0000000000000000>;
impl ShiftToHigh of MulHelper<Lane, TwoPow64Mul> {
    type Result = HighHalf;
}
impl MergePair of AddHelper<Lane, HighHalf> {
    type Result = BoundedInt<0, 0xffffffffffffffffffffffffffffffff>;
}
/// Packs two lanes into one `u128` pair: `lo + hi * 2^64`.
#[inline(always)]
pub(crate) fn pair(lo: Lane, hi: Lane) -> u128 {
    let two64: TwoPow64Mul = 0x10000000000000000;
    upcast(add(lo, mul(hi, two64)))
}
/// Places a lane in a pair's high half (`lane * 2^64`).
#[inline(always)]
fn high_lane(hi: Lane) -> HighHalf {
    let two64: TwoPow64Mul = 0x10000000000000000;
    mul(hi, two64)
}
type DuplicateMul = UnitInt<0x10000000000000001>;
impl DuplicateLane of MulHelper<Lane, DuplicateMul> {
    type Result = BoundedInt<0, 0xffffffffffffffffffffffffffffffff>;
}
/// Duplicates a lane into both halves (`lane * (2^64 + 1)`), so one XOR
/// against the result updates two lanes at once.
#[inline(always)]
fn duplicate_lane(x: Lane) -> u128 {
    let m: DuplicateMul = 0x10000000000000001;
    upcast(mul(x, m))
}
/// Packs a lane with an already-shifted high half.
#[inline(always)]
fn pair_high(lo: Lane, hi: HighHalf) -> u128 {
    upcast(add(lo, hi))
}
type LaneLow = BoundedInt<0, 0x7fffffffffffffff>;
type LaneEven = BoundedInt<0, 0xfffffffffffffffe>;
type Rot6Top = BoundedInt<0, 63>;
type Rot6Rest = BoundedInt<0, 0x3ffffffffffffff>;
type Rot6Shifted = BoundedInt<0, 0xffffffffffffffc0>;
impl SplitRot6 of DivRemHelper<Lane, UnitInt<0x400000000000000>> {
    type DivT = Rot6Top;
    type RemT = Rot6Rest;
}
impl ShiftRot6 of MulHelper<Rot6Rest, UnitInt<64>> {
    type Result = Rot6Shifted;
}
impl MergeRot6 of AddHelper<Rot6Shifted, Rot6Top> {
    type Result = Lane;
}
type Rot8Top = BoundedInt<0, 255>;
type Rot8Rest = BoundedInt<0, 0xffffffffffffff>;
type Rot8Shifted = BoundedInt<0, 0xffffffffffffff00>;
impl SplitRot8 of DivRemHelper<Lane, UnitInt<72057594037927936>> {
    type DivT = Rot8Top;
    type RemT = Rot8Rest;
}
impl ShiftRot8 of MulHelper<Rot8Rest, UnitInt<256>> {
    type Result = Rot8Shifted;
}
impl MergeRot8 of AddHelper<Rot8Shifted, Rot8Top> {
    type Result = Lane;
}
type Rot20Top = BoundedInt<0, 1048575>;
type Rot20Rest = BoundedInt<0, 0xfffffffffff>;
type Rot20Shifted = BoundedInt<0, 0xfffffffffff00000>;
impl SplitRot20 of DivRemHelper<Lane, UnitInt<17592186044416>> {
    type DivT = Rot20Top;
    type RemT = Rot20Rest;
}
impl ShiftRot20 of MulHelper<Rot20Rest, UnitInt<1048576>> {
    type Result = Rot20Shifted;
}
impl MergeRot20 of AddHelper<Rot20Shifted, Rot20Top> {
    type Result = Lane;
}
type Rot21Top = BoundedInt<0, 2097151>;
type Rot21Rest = BoundedInt<0, 8796093022207>;
type Rot21Shifted = BoundedInt<0, 0xffffffffffe00000>;
impl SplitRot21 of DivRemHelper<Lane, UnitInt<8796093022208>> {
    type DivT = Rot21Top;
    type RemT = Rot21Rest;
}
impl ShiftRot21 of MulHelper<Rot21Rest, UnitInt<2097152>> {
    type Result = Rot21Shifted;
}
impl MergeRot21 of AddHelper<Rot21Shifted, Rot21Top> {
    type Result = Lane;
}
type Rot25Top = BoundedInt<0, 33554431>;
type Rot25Rest = BoundedInt<0, 549755813887>;
type Rot25Shifted = BoundedInt<0, 0xfffffffffe000000>;
impl SplitRot25 of DivRemHelper<Lane, UnitInt<549755813888>> {
    type DivT = Rot25Top;
    type RemT = Rot25Rest;
}
impl ShiftRot25 of MulHelper<Rot25Rest, UnitInt<33554432>> {
    type Result = Rot25Shifted;
}
impl MergeRot25 of AddHelper<Rot25Shifted, Rot25Top> {
    type Result = Lane;
}
type Rot28Top = BoundedInt<0, 268435455>;
type Rot28Rest = BoundedInt<0, 68719476735>;
type Rot28Shifted = BoundedInt<0, 0xfffffffff0000000>;
impl SplitRot28 of DivRemHelper<Lane, UnitInt<68719476736>> {
    type DivT = Rot28Top;
    type RemT = Rot28Rest;
}
impl ShiftRot28 of MulHelper<Rot28Rest, UnitInt<268435456>> {
    type Result = Rot28Shifted;
}
impl MergeRot28 of AddHelper<Rot28Shifted, Rot28Top> {
    type Result = Lane;
}
type Rot39Top = BoundedInt<0, 549755813887>;
type Rot39Rest = BoundedInt<0, 33554431>;
type Rot39Shifted = BoundedInt<0, 0xffffff8000000000>;
impl SplitRot39 of DivRemHelper<Lane, UnitInt<33554432>> {
    type DivT = Rot39Top;
    type RemT = Rot39Rest;
}
impl ShiftRot39 of MulHelper<Rot39Rest, UnitInt<549755813888>> {
    type Result = Rot39Shifted;
}
impl MergeRot39 of AddHelper<Rot39Shifted, Rot39Top> {
    type Result = Lane;
}
type Rot41Top = BoundedInt<0, 2199023255551>;
type Rot41Rest = BoundedInt<0, 8388607>;
type Rot41Shifted = BoundedInt<0, 0xfffffe0000000000>;
impl SplitRot41 of DivRemHelper<Lane, UnitInt<8388608>> {
    type DivT = Rot41Top;
    type RemT = Rot41Rest;
}
impl ShiftRot41 of MulHelper<Rot41Rest, UnitInt<2199023255552>> {
    type Result = Rot41Shifted;
}
impl MergeRot41 of AddHelper<Rot41Shifted, Rot41Top> {
    type Result = Lane;
}
type Rot43Top = BoundedInt<0, 8796093022207>;
type Rot43Rest = BoundedInt<0, 2097151>;
type Rot43Shifted = BoundedInt<0, 0xfffff80000000000>;
impl SplitRot43 of DivRemHelper<Lane, UnitInt<2097152>> {
    type DivT = Rot43Top;
    type RemT = Rot43Rest;
}
impl ShiftRot43 of MulHelper<Rot43Rest, UnitInt<8796093022208>> {
    type Result = Rot43Shifted;
}
impl MergeRot43 of AddHelper<Rot43Shifted, Rot43Top> {
    type Result = Lane;
}
type Rot45Top = BoundedInt<0, 35184372088831>;
type Rot45Rest = BoundedInt<0, 524287>;
type Rot45Shifted = BoundedInt<0, 0xffffe00000000000>;
impl SplitRot45 of DivRemHelper<Lane, UnitInt<524288>> {
    type DivT = Rot45Top;
    type RemT = Rot45Rest;
}
impl ShiftRot45 of MulHelper<Rot45Rest, UnitInt<35184372088832>> {
    type Result = Rot45Shifted;
}
impl MergeRot45 of AddHelper<Rot45Shifted, Rot45Top> {
    type Result = Lane;
}
type Rot62Top = BoundedInt<0, 0x3fffffffffffffff>;
type Rot62Rest = BoundedInt<0, 3>;
type Rot62Shifted = BoundedInt<0, 0xc000000000000000>;
impl SplitRot62 of DivRemHelper<Lane, UnitInt<4>> {
    type DivT = Rot62Top;
    type RemT = Rot62Rest;
}
impl ShiftRot62 of MulHelper<Rot62Rest, UnitInt<0x4000000000000000>> {
    type Result = Rot62Shifted;
}
impl MergeRot62 of AddHelper<Rot62Shifted, Rot62Top> {
    type Result = Lane;
}
type Rot18Top = BoundedInt<0, 262143>;
type Rot18Rest = BoundedInt<0, 70368744177663>;
type Rot18Shifted = BoundedInt<0, 0xfffffffffffc0000>;
impl SplitRot18 of DivRemHelper<Lane, UnitInt<70368744177664>> {
    type DivT = Rot18Top;
    type RemT = Rot18Rest;
}
impl ShiftRot18 of MulHelper<Rot18Rest, UnitInt<262144>> {
    type Result = Rot18Shifted;
}
impl MergeRot18 of AddHelper<Rot18Shifted, Rot18Top> {
    type Result = Lane;
}
#[inline(always)]
fn rot18(x: Lane, d: NonZero<UnitInt<70368744177664>>) -> Lane {
    let m: UnitInt<262144> = 262144;
    let (aH, rest) = div_rem(x, d);
    add(mul(rest, m), aH)
}
type Rot56Top = BoundedInt<0, 0xffffffffffffff>;
type Rot56Rest = BoundedInt<0, 255>;
type Rot56Shifted = BoundedInt<0, 0xff00000000000000>;
impl SplitRot56 of DivRemHelper<Lane, UnitInt<256>> {
    type DivT = Rot56Top;
    type RemT = Rot56Rest;
}
impl ShiftRot56 of MulHelper<Rot56Rest, UnitInt<72057594037927936>> {
    type Result = Rot56Shifted;
}
impl MergeRot56 of AddHelper<Rot56Shifted, Rot56Top> {
    type Result = Lane;
}
#[inline(always)]
fn rot56(x: Lane, d: NonZero<UnitInt<256>>) -> Lane {
    let m: UnitInt<72057594037927936> = 72057594037927936;
    let (aH, rest) = div_rem(x, d);
    add(mul(rest, m), aH)
}
type Rot61Top = BoundedInt<0, 0x1fffffffffffffff>;
type Rot61Rest = BoundedInt<0, 7>;
type Rot61Shifted = BoundedInt<0, 0xe000000000000000>;
impl SplitRot61 of DivRemHelper<Lane, UnitInt<8>> {
    type DivT = Rot61Top;
    type RemT = Rot61Rest;
}
impl ShiftRot61 of MulHelper<Rot61Rest, UnitInt<0x2000000000000000>> {
    type Result = Rot61Shifted;
}
impl MergeRot61 of AddHelper<Rot61Shifted, Rot61Top> {
    type Result = Lane;
}
#[inline(always)]
fn rot61(x: Lane, d: NonZero<UnitInt<8>>) -> Lane {
    let m: UnitInt<0x2000000000000000> = 0x2000000000000000;
    let (aH, rest) = div_rem(x, d);
    add(mul(rest, m), aH)
}
/// Division-free left-rotation by `n` over one lane, generic over the
/// `(2^(64 - n) divisor, 2^n multiplier)` pair: the wrapped high bits and the
/// shifted low bits occupy disjoint ranges, so their sum is the rotation.
fn rot_generic<
    D,
    M,
    impl H: DivRemHelper<Lane, D>,
    impl X: MulHelper<H::RemT, M>,
    impl A: AddHelper<X::Result, H::DivT>,
>(
    x: Lane, d: NonZero<D>, m: M,
) -> A::Result {
    let (t, r) = div_rem(x, d);
    add(mul(r, m), t)
}
impl SplitRot11 of DivRemHelper<Lane, UnitInt<9007199254740992>> {
    type DivT = BoundedInt<0, 2047>;
    type RemT = BoundedInt<0, 9007199254740991>;
}
impl ShiftRot11 of MulHelper<BoundedInt<0, 9007199254740991>, UnitInt<2048>> {
    type Result = BoundedInt<0, 0xfffffffffffff800>;
}
impl MergeRot11 of AddHelper<BoundedInt<0, 0xfffffffffffff800>, BoundedInt<0, 2047>> {
    type Result = Lane;
}
const M11: UnitInt<2048> = 2048;
impl SplitRot12 of DivRemHelper<Lane, UnitInt<4503599627370496>> {
    type DivT = BoundedInt<0, 4095>;
    type RemT = BoundedInt<0, 0xfffffffffffff>;
}
impl ShiftRot12 of MulHelper<BoundedInt<0, 0xfffffffffffff>, UnitInt<4096>> {
    type Result = BoundedInt<0, 0xfffffffffffff000>;
}
impl MergeRot12 of AddHelper<BoundedInt<0, 0xfffffffffffff000>, BoundedInt<0, 4095>> {
    type Result = Lane;
}
const M12: UnitInt<4096> = 4096;
impl SplitRot17 of DivRemHelper<Lane, UnitInt<0x800000000000>> {
    type DivT = BoundedInt<0, 131071>;
    type RemT = BoundedInt<0, 0x7fffffffffff>;
}
impl ShiftRot17 of MulHelper<BoundedInt<0, 0x7fffffffffff>, UnitInt<131072>> {
    type Result = BoundedInt<0, 0xfffffffffffe0000>;
}
impl MergeRot17 of AddHelper<BoundedInt<0, 0xfffffffffffe0000>, BoundedInt<0, 131071>> {
    type Result = Lane;
}
const M17: UnitInt<131072> = 131072;
impl SplitRot22 of DivRemHelper<Lane, UnitInt<4398046511104>> {
    type DivT = BoundedInt<0, 4194303>;
    type RemT = BoundedInt<0, 4398046511103>;
}
impl ShiftRot22 of MulHelper<BoundedInt<0, 4398046511103>, UnitInt<4194304>> {
    type Result = BoundedInt<0, 0xffffffffffc00000>;
}
impl MergeRot22 of AddHelper<BoundedInt<0, 0xffffffffffc00000>, BoundedInt<0, 4194303>> {
    type Result = Lane;
}
const M22: UnitInt<4194304> = 4194304;
impl SplitRot23 of DivRemHelper<Lane, UnitInt<2199023255552>> {
    type DivT = BoundedInt<0, 8388607>;
    type RemT = BoundedInt<0, 2199023255551>;
}
impl ShiftRot23 of MulHelper<BoundedInt<0, 2199023255551>, UnitInt<8388608>> {
    type Result = BoundedInt<0, 0xffffffffff800000>;
}
impl MergeRot23 of AddHelper<BoundedInt<0, 0xffffffffff800000>, BoundedInt<0, 8388607>> {
    type Result = Lane;
}
const M23: UnitInt<8388608> = 8388608;
impl SplitRot26 of DivRemHelper<Lane, UnitInt<274877906944>> {
    type DivT = BoundedInt<0, 67108863>;
    type RemT = BoundedInt<0, 274877906943>;
}
impl ShiftRot26 of MulHelper<BoundedInt<0, 274877906943>, UnitInt<67108864>> {
    type Result = BoundedInt<0, 0xfffffffffc000000>;
}
impl MergeRot26 of AddHelper<BoundedInt<0, 0xfffffffffc000000>, BoundedInt<0, 67108863>> {
    type Result = Lane;
}
const M26: UnitInt<67108864> = 67108864;
impl SplitRot30 of DivRemHelper<Lane, UnitInt<17179869184>> {
    type DivT = BoundedInt<0, 1073741823>;
    type RemT = BoundedInt<0, 17179869183>;
}
impl ShiftRot30 of MulHelper<BoundedInt<0, 17179869183>, UnitInt<1073741824>> {
    type Result = BoundedInt<0, 0xffffffffc0000000>;
}
impl MergeRot30 of AddHelper<BoundedInt<0, 0xffffffffc0000000>, BoundedInt<0, 1073741823>> {
    type Result = Lane;
}
const M30: UnitInt<1073741824> = 1073741824;
impl SplitRot34 of DivRemHelper<Lane, UnitInt<1073741824>> {
    type DivT = BoundedInt<0, 17179869183>;
    type RemT = BoundedInt<0, 1073741823>;
}
impl ShiftRot34 of MulHelper<BoundedInt<0, 1073741823>, UnitInt<17179869184>> {
    type Result = BoundedInt<0, 0xfffffffc00000000>;
}
impl MergeRot34 of AddHelper<BoundedInt<0, 0xfffffffc00000000>, BoundedInt<0, 17179869183>> {
    type Result = Lane;
}
const M34: UnitInt<17179869184> = 17179869184;
impl SplitRot35 of DivRemHelper<Lane, UnitInt<536870912>> {
    type DivT = BoundedInt<0, 34359738367>;
    type RemT = BoundedInt<0, 536870911>;
}
impl ShiftRot35 of MulHelper<BoundedInt<0, 536870911>, UnitInt<34359738368>> {
    type Result = BoundedInt<0, 0xfffffff800000000>;
}
impl MergeRot35 of AddHelper<BoundedInt<0, 0xfffffff800000000>, BoundedInt<0, 34359738367>> {
    type Result = Lane;
}
const M35: UnitInt<34359738368> = 34359738368;
impl SplitRot38 of DivRemHelper<Lane, UnitInt<67108864>> {
    type DivT = BoundedInt<0, 274877906943>;
    type RemT = BoundedInt<0, 67108863>;
}
impl ShiftRot38 of MulHelper<BoundedInt<0, 67108863>, UnitInt<274877906944>> {
    type Result = BoundedInt<0, 0xffffffc000000000>;
}
impl MergeRot38 of AddHelper<BoundedInt<0, 0xffffffc000000000>, BoundedInt<0, 274877906943>> {
    type Result = Lane;
}
const M38: UnitInt<274877906944> = 274877906944;
impl SplitRot40 of DivRemHelper<Lane, UnitInt<16777216>> {
    type DivT = BoundedInt<0, 0xffffffffff>;
    type RemT = BoundedInt<0, 16777215>;
}
impl ShiftRot40 of MulHelper<BoundedInt<0, 16777215>, UnitInt<1099511627776>> {
    type Result = BoundedInt<0, 0xffffff0000000000>;
}
impl MergeRot40 of AddHelper<BoundedInt<0, 0xffffff0000000000>, BoundedInt<0, 0xffffffffff>> {
    type Result = Lane;
}
const M40: UnitInt<1099511627776> = 1099511627776;
impl SplitRot47 of DivRemHelper<Lane, UnitInt<131072>> {
    type DivT = BoundedInt<0, 0x7fffffffffff>;
    type RemT = BoundedInt<0, 131071>;
}
impl ShiftRot47 of MulHelper<BoundedInt<0, 131071>, UnitInt<0x800000000000>> {
    type Result = BoundedInt<0, 0xffff800000000000>;
}
impl MergeRot47 of AddHelper<BoundedInt<0, 0xffff800000000000>, BoundedInt<0, 0x7fffffffffff>> {
    type Result = Lane;
}
const M47: UnitInt<0x800000000000> = 0x800000000000;
impl SplitRot48 of DivRemHelper<Lane, UnitInt<65536>> {
    type DivT = BoundedInt<0, 0xffffffffffff>;
    type RemT = BoundedInt<0, 65535>;
}
impl ShiftRot48 of MulHelper<BoundedInt<0, 65535>, UnitInt<281474976710656>> {
    type Result = BoundedInt<0, 0xffff000000000000>;
}
impl MergeRot48 of AddHelper<BoundedInt<0, 0xffff000000000000>, BoundedInt<0, 0xffffffffffff>> {
    type Result = Lane;
}
const M48: UnitInt<281474976710656> = 281474976710656;
impl SplitRot59 of DivRemHelper<Lane, UnitInt<32>> {
    type DivT = BoundedInt<0, 0x7ffffffffffffff>;
    type RemT = BoundedInt<0, 31>;
}
impl ShiftRot59 of MulHelper<BoundedInt<0, 31>, UnitInt<0x800000000000000>> {
    type Result = BoundedInt<0, 0xf800000000000000>;
}
impl MergeRot59 of AddHelper<BoundedInt<0, 0xf800000000000000>, BoundedInt<0, 0x7ffffffffffffff>> {
    type Result = Lane;
}
const M59: UnitInt<0x800000000000000> = 0x800000000000000;
impl SplitRot16 of DivRemHelper<Lane, UnitInt<281474976710656>> {
    type DivT = BoundedInt<0, 65535>;
    type RemT = BoundedInt<0, 0xffffffffffff>;
}
impl ShiftRot16 of MulHelper<BoundedInt<0, 0xffffffffffff>, UnitInt<65536>> {
    type Result = BoundedInt<0, 0xffffffffffff0000>;
}
impl MergeRot16 of AddHelper<BoundedInt<0, 0xffffffffffff0000>, BoundedInt<0, 65535>> {
    type Result = Lane;
}
const M16: UnitInt<65536> = 65536;
impl SplitRot53 of DivRemHelper<Lane, UnitInt<2048>> {
    type DivT = BoundedInt<0, 9007199254740991>;
    type RemT = BoundedInt<0, 2047>;
}
impl ShiftRot53 of MulHelper<BoundedInt<0, 2047>, UnitInt<9007199254740992>> {
    type Result = BoundedInt<0, 0xffe0000000000000>;
}
impl MergeRot53 of AddHelper<BoundedInt<0, 0xffe0000000000000>, BoundedInt<0, 9007199254740991>> {
    type Result = Lane;
}
const M53: UnitInt<9007199254740992> = 9007199254740992;
type TwoPow65 = UnitInt<0x20000000000000000>;
type LaneCarry = BoundedInt<0, 0x1ffffffffffffffff>;
impl SplitPair65 of DivRemHelper<u128, TwoPow65> {
    type DivT = BoundedInt<0, 0x7fffffffffffffff>;
    type RemT = LaneCarry;
}
impl LaneCarrySplit of ConstrainHelper<LaneCarry, 0x10000000000000000> {
    type LowT = Lane;
    type HighT = BoundedInt<0x10000000000000000, 0x1ffffffffffffffff>;
}
impl DropPairCarry of SubHelper<
    BoundedInt<0x10000000000000000, 0x1ffffffffffffffff>, UnitInt<0x10000000000000000>,
> {
    type Result = Lane;
}
impl FoldCarryTop of AddHelper<BoundedInt<0, 0x7fffffffffffffff>, UnitInt<0x8000000000000000>> {
    type Result = BoundedInt<0x8000000000000000, 0xffffffffffffffff>;
}
/// Splits a value one bit wider than a pair (below `2^65`), folding the low
/// half's carry bit into the high lane.
#[inline(always)]
fn split_pair_carry(w: u128, two65: NonZero<TwoPow65>) -> (Lane, Lane) {
    let (q, rem) = div_rem(w, two65);
    match constrain::<LaneCarry, 0x10000000000000000>(rem) {
        Ok(lo) => (lo, upcast(q)),
        Err(hi) => {
            let t: UnitInt<0x10000000000000000> = 0x10000000000000000;
            let p: UnitInt<0x8000000000000000> = 0x8000000000000000;
            (sub(hi, t), upcast(add(q, p)))
        },
    }
}
type Mask64 = UnitInt<0xffffffffffffffff>;
impl Not64 of SubHelper<Mask64, Lane> {
    type Result = Lane;
}
/// XOR of two 64-bit lanes.
#[inline(always)]
fn xor64(a: Lane, b: Lane) -> Lane {
    let a: u64 = upcast(a);
    let b: u64 = upcast(b);
    upcast(a ^ b)
}
/// `(NOT b) AND c` over single lanes: the chi selection.
#[inline(always)]
fn andn64(b: Lane, c: Lane, mask128: Mask64) -> Lane {
    let nb: u64 = upcast(sub(mask128, b));
    let c: u64 = upcast(c);
    upcast(nb & c)
}
/// `NonZero` divisors and masks threaded through the round functions: `rd<n>`
/// is the `2^(64 - n)` divisor of the division-free left-rotation by `n`.
#[derive(Copy, Drop)]
struct RotConstants {
    two64: NonZero<TwoPow64>,
    rd4: NonZero<UnitInt<0x1000000000000000>>,
    rd13: NonZero<UnitInt<0x8000000000000>>,
    rd19: NonZero<UnitInt<0x200000000000>>,
    rd37: NonZero<UnitInt<0x8000000>>,
    rd42: NonZero<UnitInt<0x400000>>,
    rd54: NonZero<UnitInt<0x400>>,
    rd60: NonZero<UnitInt<0x10>>,
    mask128: Mask128,
    rd18: NonZero<UnitInt<70368744177664>>,
    rd56: NonZero<UnitInt<256>>,
    rd61: NonZero<UnitInt<8>>,
    rd6: NonZero<UnitInt<0x400000000000000>>,
    rd8: NonZero<UnitInt<72057594037927936>>,
    rd20: NonZero<UnitInt<17592186044416>>,
    rd21: NonZero<UnitInt<8796093022208>>,
    rd25: NonZero<UnitInt<549755813888>>,
    rd28: NonZero<UnitInt<68719476736>>,
    rd39: NonZero<UnitInt<33554432>>,
    rd41: NonZero<UnitInt<8388608>>,
    rd43: NonZero<UnitInt<2097152>>,
    rd45: NonZero<UnitInt<524288>>,
    rd62: NonZero<UnitInt<4>>,
    two65: NonZero<TwoPow65>,
    rd11: NonZero<UnitInt<9007199254740992>>,
    rd12: NonZero<UnitInt<4503599627370496>>,
    rd17: NonZero<UnitInt<0x800000000000>>,
    rd22: NonZero<UnitInt<4398046511104>>,
    rd23: NonZero<UnitInt<2199023255552>>,
    rd26: NonZero<UnitInt<274877906944>>,
    rd30: NonZero<UnitInt<17179869184>>,
    rd34: NonZero<UnitInt<1073741824>>,
    rd35: NonZero<UnitInt<536870912>>,
    rd38: NonZero<UnitInt<67108864>>,
    rd40: NonZero<UnitInt<16777216>>,
    rd47: NonZero<UnitInt<131072>>,
    rd48: NonZero<UnitInt<65536>>,
    rd59: NonZero<UnitInt<32>>,
    rd16: NonZero<UnitInt<281474976710656>>,
    rd53: NonZero<UnitInt<2048>>,
    mask64: Mask64,
}
/// Builds the shared constant set once per permutation.
#[inline(never)]
fn rot_constants() -> RotConstants {
    RotConstants {
        rd4: 0x1000000000000000,
        rd13: 0x8000000000000,
        rd19: 0x200000000000,
        rd37: 0x8000000,
        rd42: 0x400000,
        rd54: 0x400,
        rd60: 0x10,
        two64: TWO_POW_64_NZ,
        mask128: MASK_128,
        rd18: 70368744177664,
        rd56: 256,
        rd61: 8,
        rd6: 0x400000000000000,
        rd8: 72057594037927936,
        rd20: 17592186044416,
        rd21: 8796093022208,
        rd25: 549755813888,
        rd28: 68719476736,
        rd39: 33554432,
        rd41: 8388608,
        rd43: 2097152,
        rd45: 524288,
        rd62: 4,
        two65: 0x20000000000000000,
        rd11: 9007199254740992,
        rd12: 4503599627370496,
        rd17: 0x800000000000,
        rd22: 4398046511104,
        rd23: 2199023255552,
        rd26: 274877906944,
        rd30: 17179869184,
        rd34: 1073741824,
        rd35: 536870912,
        rd38: 67108864,
        rd40: 16777216,
        rd47: 131072,
        rd48: 65536,
        rd59: 32,
        rd16: 281474976710656,
        rd53: 2048,
        mask64: 0xffffffffffffffff,
    }
}

/// Bitwise NOT of a packed pair: `(2^128 - 1) - x` (both halves stay 64-bit).
#[inline(always)]
fn not128(x: u128, mask128: Mask128) -> u128 {
    upcast(sub(mask128, x))
}
/// Splits a pair into `(high, low)` lanes.
#[inline(always)]
fn split_pair(w: u128, two64: NonZero<TwoPow64>) -> (Lane, Lane) {
    div_rem(w, two64)
}
impl SplitTopBit of ConstrainHelper<Lane, 0x8000000000000000> {
    type LowT = BoundedInt<0, 0x7fffffffffffffff>;
    type HighT = BoundedInt<0x8000000000000000, 0xffffffffffffffff>;
}
impl Rotl1WrapLaneHigh of SubHelper<
    BoundedInt<0x10000000000000000, 0x1fffffffffffffffe>, UnitInt<0xffffffffffffffff>,
> {
    type Result = BoundedInt<1, 0xffffffffffffffff>;
}
#[inline(always)]
fn rot6(x: Lane, d: NonZero<UnitInt<0x400000000000000>>) -> Lane {
    let m: UnitInt<64> = 64;
    let (aH, rest) = div_rem(x, d);
    add(mul(rest, m), aH)
}
#[inline(always)]
fn rot8(x: Lane, d: NonZero<UnitInt<72057594037927936>>) -> Lane {
    let m: UnitInt<256> = 256;
    let (aH, rest) = div_rem(x, d);
    add(mul(rest, m), aH)
}
#[inline(always)]
fn rot20(x: Lane, d: NonZero<UnitInt<17592186044416>>) -> Lane {
    let m: UnitInt<1048576> = 1048576;
    let (aH, rest) = div_rem(x, d);
    add(mul(rest, m), aH)
}
#[inline(always)]
fn rot21(x: Lane, d: NonZero<UnitInt<8796093022208>>) -> Lane {
    let m: UnitInt<2097152> = 2097152;
    let (aH, rest) = div_rem(x, d);
    add(mul(rest, m), aH)
}
#[inline(always)]
fn rot25(x: Lane, d: NonZero<UnitInt<549755813888>>) -> Lane {
    let m: UnitInt<33554432> = 33554432;
    let (aH, rest) = div_rem(x, d);
    add(mul(rest, m), aH)
}
#[inline(always)]
fn rot28(x: Lane, d: NonZero<UnitInt<68719476736>>) -> Lane {
    let m: UnitInt<268435456> = 268435456;
    let (aH, rest) = div_rem(x, d);
    add(mul(rest, m), aH)
}
#[inline(always)]
fn rot39(x: Lane, d: NonZero<UnitInt<33554432>>) -> Lane {
    let m: UnitInt<549755813888> = 549755813888;
    let (aH, rest) = div_rem(x, d);
    add(mul(rest, m), aH)
}
#[inline(always)]
fn rot41(x: Lane, d: NonZero<UnitInt<8388608>>) -> Lane {
    let m: UnitInt<2199023255552> = 2199023255552;
    let (aH, rest) = div_rem(x, d);
    add(mul(rest, m), aH)
}
#[inline(always)]
fn rot43(x: Lane, d: NonZero<UnitInt<2097152>>) -> Lane {
    let m: UnitInt<8796093022208> = 8796093022208;
    let (aH, rest) = div_rem(x, d);
    add(mul(rest, m), aH)
}
#[inline(always)]
fn rot45(x: Lane, d: NonZero<UnitInt<524288>>) -> Lane {
    let m: UnitInt<35184372088832> = 35184372088832;
    let (aH, rest) = div_rem(x, d);
    add(mul(rest, m), aH)
}
#[inline(always)]
fn rot62(x: Lane, d: NonZero<UnitInt<4>>) -> Lane {
    let m: UnitInt<0x4000000000000000> = 0x4000000000000000;
    let (aH, rest) = div_rem(x, d);
    add(mul(rest, m), aH)
}
/// Bitwise NOT of a single lane: `(2^64 - 1) - x`.
#[inline(always)]
fn not64(x: Lane, mask128: Mask64) -> Lane {
    sub(mask128, x)
}
impl Rotl1ShiftLow of MulHelper<BoundedInt<0, 0x7fffffffffffffff>, UnitInt<0x20000000000000000>> {
    type Result = BoundedInt<0, 0xfffffffffffffffe0000000000000000>;
}
impl Rotl1AddLl of AddHelper<
    BoundedInt<0, 0xfffffffffffffffe0000000000000000>, BoundedInt<0, 0x7fffffffffffffff>,
> {
    type Result = BoundedInt<0, 0xfffffffffffffffe7fffffffffffffff>;
}
impl Rotl1AddHh of AddHelper<
    BoundedInt<0x100000000000000000000000000000000, 0x1fffffffffffffffe0000000000000000>,
    BoundedInt<0x8000000000000000, 0xffffffffffffffff>,
> {
    type Result =
        BoundedInt<0x100000000000000008000000000000000, 0x1fffffffffffffffeffffffffffffffff>;
}
impl Rotl1WrapHh of SubHelper<
    BoundedInt<0x100000000000000008000000000000000, 0x1fffffffffffffffeffffffffffffffff>,
    UnitInt<0xffffffffffffffffffffffffffffffff>,
> {
    type Result = BoundedInt<0x8000000000000001, 0xffffffffffffffff0000000000000000>;
}
impl Rotl1CloseHh of AddHelper<
    BoundedInt<0x8000000000000001, 0xffffffffffffffff0000000000000000>,
    BoundedInt<0x8000000000000000, 0xffffffffffffffff>,
> {
    type Result = BoundedInt<0x10000000000000001, 0xffffffffffffffffffffffffffffffff>;
}
impl Rotl1CloseLl of AddHelper<
    BoundedInt<0, 0xfffffffffffffffe7fffffffffffffff>, BoundedInt<0, 0x7fffffffffffffff>,
> {
    type Result = BoundedInt<0, 0xfffffffffffffffefffffffffffffffe>;
}
impl Rotl1ShiftHigh of MulHelper<
    BoundedInt<0x8000000000000000, 0xffffffffffffffff>, UnitInt<0x20000000000000000>,
> {
    type Result =
        BoundedInt<0x100000000000000000000000000000000, 0x1fffffffffffffffe0000000000000000>;
}
impl Rotl1AddLh of AddHelper<
    BoundedInt<0x100000000000000000000000000000000, 0x1fffffffffffffffe0000000000000000>,
    BoundedInt<0, 0x7fffffffffffffff>,
> {
    type Result =
        BoundedInt<0x100000000000000000000000000000000, 0x1fffffffffffffffe7fffffffffffffff>;
}
impl Rotl1WrapLh of SubHelper<
    BoundedInt<0x100000000000000000000000000000000, 0x1fffffffffffffffe7fffffffffffffff>,
    UnitInt<0xffffffffffffffff0000000000000000>,
> {
    type Result = BoundedInt<0x10000000000000000, 0xffffffffffffffff7fffffffffffffff>;
}
impl Rotl1CloseLh of AddHelper<
    BoundedInt<0x10000000000000000, 0xffffffffffffffff7fffffffffffffff>,
    BoundedInt<0, 0x7fffffffffffffff>,
> {
    type Result = BoundedInt<0x10000000000000000, 0xfffffffffffffffffffffffffffffffe>;
}
impl Rotl1AddHl of AddHelper<
    BoundedInt<0, 0xfffffffffffffffe0000000000000000>,
    BoundedInt<0x8000000000000000, 0xffffffffffffffff>,
> {
    type Result = BoundedInt<0x8000000000000000, 0xfffffffffffffffeffffffffffffffff>;
}
impl Rotl1WrapHl of SubHelper<
    BoundedInt<0x8000000000000000, 0xfffffffffffffffeffffffffffffffff>, UnitInt<0xffffffffffffffff>,
> {
    type Result = BoundedInt<-0x7fffffffffffffff, 0xfffffffffffffffe0000000000000000>;
}
impl Rotl1CloseHl of AddHelper<
    BoundedInt<-0x7fffffffffffffff, 0xfffffffffffffffe0000000000000000>,
    BoundedInt<0x8000000000000000, 0xffffffffffffffff>,
> {
    type Result = BoundedInt<1, 0xfffffffffffffffeffffffffffffffff>;
}
/// Rotates one lane and one pair left by one in a single top-bit dispatch.
#[inline(always)]
fn rotl1_lane_and_pair(
    c0: Lane, ca: Lane, cb: Lane, bo: TwoPow65, m64: Mask64, mask128_full: Mask128,
) -> (Lane, u128) {
    match split_top_bit(ca) {
        Ok(xa) => match split_top_bit(cb) {
            Ok(xb) => match split_top_bit(c0) {
                Ok(x0) => (rotl1_low(x0), rotl1_pair_ll(xa, xb, bo)),
                Err(x0) => (rotl1_high(x0, m64), rotl1_pair_ll(xa, xb, bo)),
            },
            Err(xb) => match split_top_bit(c0) {
                Ok(x0) => (rotl1_low(x0), rotl1_pair_lh(xa, xb, bo)),
                Err(x0) => (rotl1_high(x0, m64), rotl1_pair_lh(xa, xb, bo)),
            },
        },
        Err(xa) => match split_top_bit(cb) {
            Ok(xb) => match split_top_bit(c0) {
                Ok(x0) => (rotl1_low(x0), rotl1_pair_hl(xa, xb, bo, m64)),
                Err(x0) => (rotl1_high(x0, m64), rotl1_pair_hl(xa, xb, bo, m64)),
            },
            Err(xb) => match split_top_bit(c0) {
                Ok(x0) => (rotl1_low(x0), rotl1_pair_hh(xa, xb, bo, mask128_full)),
                Err(x0) => (rotl1_high(x0, m64), rotl1_pair_hh(xa, xb, bo, mask128_full)),
            },
        },
    }
}
pub(crate) type FirstRound = ([u128; 10], u128, Lane, Lane, Lane);

/// First-round theta terms from the precomputed column parities.
#[inline(always)]
fn first_round_theta(parities: ColumnParities) -> (u128, Lane, Lane, Lane, u128) {
    first_round_theta_with(parities, TWO_POW_64_NZ, MASK_64, MASK_128)
}

/// First-round theta core, explicit over the threaded constants.
#[inline(always)]
fn first_round_theta_with(
    parities: ColumnParities, two64: NonZero<TwoPow64>, m64: Mask64, mask128_full: Mask128,
) -> (u128, Lane, Lane, Lane, u128) {
    let (nP, nQ, c4) = parities;
    let (c1, c0) = split_pair(nP, two64);
    let (c3, c2) = split_pair(nQ, two64);
    let (r0, tG) = rotl1_lane_and_pair(c0, c1, c2, TWO_POW_65_NZ, m64, mask128_full);
    let p12 = pair(c1, c2);
    let di = pair(c4, c0) ^ tG;
    (di, c3, c4, r0, p12)
}
/// Applies the first round's theta to a full packed state, producing the
/// partially expanded [`FirstRound`] intermediate.
#[inline(always)]
pub(crate) fn absorb_round(st: [u128; 12], g4: Lane, parities: ColumnParities) -> FirstRound {
    let [u0, u1, u2, u3, u4, v0, v1, v2, v3, v4, bk, bL] = st;
    let (di, c3, c4, r0, p12) = first_round_theta(parities);
    let dM = not128(di, MASK_128);
    let (cK, cJ) = split_pair(u2 ^ dM, TWO_POW_64_NZ);
    let (cJ, tH) = rotl1_lane_and_pair(cJ, c3, c4, TWO_POW_65_NZ, MASK_64, MASK_128);
    let rd23 = p12 ^ tH;
    let d4 = xor64(c3, r0);
    let dN = not128(rd23, MASK_128);
    let dj = duplicate_lane(d4);
    (
        [
            v0 ^ rd23, u1 ^ di, v1 ^ rd23, v2 ^ dN, u3 ^ di, v3 ^ rd23, u4 ^ dM, v4 ^ dN, bk ^ dj,
            bL ^ dj,
        ],
        u0 ^ di,
        cJ,
        cK,
        not64(xor64(g4, d4), 0xffffffffffffffff),
    )
}
/// Expands the first-round intermediate into the 25 single-lane values that
/// enter the first rho step.
#[inline(always)]
fn expand_first_round(
    p: FirstRound, k: RotConstants,
) -> (
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
) {
    let ([w0, w1, w2, w4, w5, w6, w7, w8, w9, uC], wu, cJ, cK, cT) = p;
    let (bK, bx) = split_pair_carry(wu, k.two65);
    let (dq, cH) = split_pair(w0, k.two64);
    let (dt, ds) = split_pair(w1, k.two64);
    let (cI, du) = split_pair(w2, k.two64);
    let (cM, cL) = split_pair(w4, k.two64);
    let (cq, cp) = split_pair(w5, k.two64);
    let (cO, cN) = split_pair(w6, k.two64);
    let (cr, cQ) = split_pair(w7, k.two64);
    let (cS, cR) = split_pair(w8, k.two64);
    let (dv, dr) = split_pair(w9, k.two64);
    let (cP, cc) = split_pair(uC, k.two64);
    let cc = not64(cc, k.mask64);
    (
        bK,
        bx,
        cH,
        dq,
        dr,
        ds,
        dt,
        du,
        cI,
        dv,
        cJ,
        cK,
        cL,
        cM,
        cc,
        cp,
        cq,
        cN,
        cO,
        cP,
        cQ,
        cr,
        cR,
        cS,
        cT,
    )
}
/// Theta and lane expansion for the stage-2 orientation (rounds 16..=22).
#[inline(always)]
fn theta_stage2(
    st: ([u128; 12], Lane), k: RotConstants,
) -> (
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
) {
    let (st, g3) = st;
    let [e0, e1, e2, e3, e4, o0, o1, o2, o3, o4, bk, hI] = st;
    let eD = e0 ^ e1 ^ e2 ^ e3 ^ e4;
    let hG = o0 ^ o1 ^ o2 ^ o3 ^ o4;
    let (gh, gl) = split_pair(bk ^ hI, k.two64);
    let c4 = xor64(xor64(gh, gl), g3);
    let (c2, c0) = split_pair(eD, k.two64);
    let (c3, c1) = split_pair(hG, k.two64);
    let (kL, kM) = rotl1_two_pairs(c1, c3, c2, c4, k.two65.into(), k.mask64, k.mask128);
    let kp = eD ^ kM;
    let dk = not128(kp, k.mask128);
    let (cO, cq) = split_pair(o3 ^ dk, k.two64);
    let ee = pair(c4, c1) ^ kL;
    let jH = not128(ee, k.mask128);
    let (top63, zm) = div_rem(e2 ^ jH, k.two65);
    let (r0, cq, cJ, cL) = rotl1_pair_split(c0, cq, top63, zm, k.mask64);
    let (dq, bx) = split_pair(o0 ^ dk, k.two64);
    let d4 = xor64(c3, r0);
    let dj = duplicate_lane(d4);
    let (cH, bK) = split_pair(e0 ^ ee, k.two64);
    let (du, ds) = split_pair(e1 ^ ee, k.two64);
    let (cI, dt) = split_pair(o1 ^ dk, k.two64);
    let (cM, cK) = split_pair(o2 ^ kp, k.two64);
    let (cN, cp) = split_pair(e3 ^ ee, k.two64);
    let (cR, cQ) = split_pair(e4 ^ jH, k.two64);
    let (cS, cr) = split_pair(o4 ^ kp, k.two64);
    let (dv, dr) = split_pair(bk ^ dj, k.two64);
    let (cT, cc) = split_pair(hI ^ dj, k.two64);
    let cP = xor64(g3, d4);
    (
        bK,
        bx,
        cH,
        dq,
        dr,
        ds,
        dt,
        du,
        cI,
        dv,
        cJ,
        cK,
        cL,
        cM,
        cc,
        cp,
        cq,
        cN,
        cO,
        cP,
        cQ,
        cr,
        cR,
        cS,
        cT,
    )
}
/// Rho rotations with pi precomposed for the stage-2 orientation.
#[inline(always)]
fn rho_pi(
    a: (
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
    ),
    k: RotConstants,
) -> (
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
) {
    let (
        bK,
        bx,
        cH,
        dq,
        dr,
        ds,
        dt,
        du,
        cI,
        dv,
        cJ,
        cK,
        cL,
        cM,
        cc,
        cp,
        cq,
        cN,
        cO,
        cP,
        cQ,
        cr,
        cR,
        cS,
        cT,
    ) =
        a;
    (
        rot20(bK, k.rd20),
        dt,
        cL,
        rot41(cO, k.rd41),
        rot_generic(cT, k.rd34, M34),
        rot_generic(dq, k.rd48, M48),
        rot_generic(dv, k.rd40, M40),
        rot_generic(cJ, k.rd23, M23),
        cq,
        rot_generic(cR, k.rd17, M17),
        rot21(bx, k.rd21),
        rot_generic(du, k.rd26, M26),
        rot45(cM, k.rd45),
        rot28(cP, k.rd28),
        rot_generic(cQ, k.rd38, M38),
        rot_generic(dr, k.rd47, M47),
        rot56(ds, k.rd56),
        rot_generic(cK, k.rd30, M30),
        rot_generic(cN, k.rd35, M35),
        rot_generic(cS, k.rd12, M12),
        rot18(cH, k.rd18),
        rot_generic(cI, k.rd11, M11),
        rot_generic(cc, k.rd59, M59),
        rot61(cp, k.rd61),
        rot_generic(cr, k.rd22, M22),
    )
}
pub(crate) type Row4 = (Lane, Lane, Lane, Lane, Lane);
/// Chi over the row-4 lanes, which the pipeline carries unpacked.
#[inline(always)]
pub(crate) fn chi_row4(r: Row4) -> (u128, u128, Lane) {
    let (b20, b21, b22, b23, b24) = r;
    let eG = pair(b22, b23);
    (
        pair(b20, b21) ^ (not128(pair(b21, b22), MASK_128) & eG),
        eG ^ (not128(pair(b23, b24), MASK_128) & pair(b24, b20)),
        xor64(b24, andn64(b20, b21, 0xffffffffffffffff)),
    )
}
/// Completes chi on row 4 and repacks the full 13-word state.
#[inline(always)]
pub(crate) fn append_row4(s: ([u128; 10], Row4)) -> ([u128; 12], Lane) {
    let ([u0, u1, u2, u3, v0, v1, v2, v3, bk, bL], r) = s;
    let (u4, v4, g4) = chi_row4(r);
    ([u0, u1, u2, u3, u4, v0, v1, v2, v3, v4, bk, bL], g4)
}
pub(crate) type ColumnParities = (u128, u128, Lane);
/// Theta column parities over the packed representation: two parities per XOR
/// on the row pairs, with the x = 4 column folded from its pairs and `lane24`.
#[inline(always)]
pub(crate) fn column_parities(st: @[u128; 12], g4: Lane) -> ColumnParities {
    let [u0, u1, u2, u3, u4, v0, v1, v2, v3, v4, bk, bL] = *st;
    let (gh, gl) = split_pair(bk ^ bL, TWO_POW_64_NZ);
    (u0 ^ u1 ^ u2 ^ u3 ^ u4, v0 ^ v1 ^ v2 ^ v3 ^ v4, xor64(xor64(gh, gl), g4))
}
/// Runs theta for the first round and all remaining rounds.
#[inline(never)]
fn run_from(st: [u128; 12], g4: Lane, parities: ColumnParities) -> ([u128; 10], Row4) {
    theta_then_rounds(st, g4, parities)
}

/// The final round's chi and iota, returning the rate rows repacked in the
/// standard orientation.
#[inline(always)]
fn chi_final(
    b: (
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
    ),
    rc: u128,
    k: RotConstants,
) -> [u128; 10] {
    let (
        b00,
        b01,
        b02,
        b03,
        b04,
        b05,
        b06,
        b07,
        b08,
        b09,
        b10,
        b11,
        b12,
        b13,
        b14,
        b15,
        b16,
        b17,
        b18,
        b19,
    ) =
        b;
    let s05 = high_lane(b05);
    let s06 = high_lane(b06);
    let s15 = high_lane(b15);
    let s16 = high_lane(b16);
    let s19 = high_lane(b19);
    let s09 = high_lane(b09);
    let oU = pair(b00, b01);
    let oV = pair(b01, b02);
    let jI = pair(b02, b03);
    let oW = pair(b03, b04);
    let oX = pair(b04, b00);
    let oY = pair_high(b05, s06);
    let oZ = pair(b06, b07);
    let jJ = pair(b07, b08);
    let o5 = pair_high(b08, s09);
    let o6 = pair_high(b09, s05);
    let o7 = pair(b10, b11);
    let o8 = pair(b11, b12);
    let jK = pair(b12, b13);
    let o9 = pair(b13, b14);
    let pa = pair(b14, b10);
    let pb = pair_high(b15, s16);
    let pd = pair(b16, b17);
    let jL = pair(b17, b18);
    let pe = pair_high(b18, s19);
    let pf = pair_high(b19, s15);
    let kF = pair_high(b04, s09);
    let kJ = pair_high(b00, s05);
    let kG = pair_high(b01, s06);
    let qU = pair_high(b14, s19);
    let sL = pair_high(b10, s15);
    let kH = pair_high(b11, s16);
    [
        oU ^ (not128(oV, k.mask128) & jI) ^ rc, oY ^ (not128(oZ, k.mask128) & jJ),
        o7 ^ (not128(o8, k.mask128) & jK), pb ^ (not128(pd, k.mask128) & jL),
        jI ^ (not128(oW, k.mask128) & oX), jJ ^ (not128(o5, k.mask128) & o6),
        jK ^ (not128(o9, k.mask128) & pa), jL ^ (not128(pe, k.mask128) & pf),
        kF ^ (not128(kJ, k.mask128) & kG), qU ^ (not128(sL, k.mask128) & kH),
    ]
}
/// Chi and iota over repacked pairs for the stage-2 orientation (or-form on
/// the complemented lane groups).
#[inline(always)]
fn chi_stage2(
    b: (
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
    ),
    rc: u128,
    k: RotConstants,
) -> ([u128; 12], Lane) {
    let (
        b00,
        b01,
        b02,
        b03,
        b04,
        b05,
        b06,
        b07,
        b08,
        b09,
        b10,
        b11,
        b12,
        b13,
        b14,
        b15,
        b16,
        b17,
        b18,
        b19,
        b20,
        b21,
        b22,
        b23,
        b24,
    ) =
        b;
    let s05 = high_lane(b05);
    let s09 = high_lane(b09);
    let s20 = high_lane(b20);
    let s24 = high_lane(b24);
    let pg = pair(b00, b02);
    let jM = pair(b01, b03);
    let jN = pair(b02, b04);
    let ph = pair(b03, b00);
    let pi = pair(b05, b07);
    let jO = pair(b06, b08);
    let jP = pair_high(b07, s09);
    let pj = pair_high(b08, s05);
    let pl = pair(b10, b12);
    let jQ = pair(b11, b13);
    let jR = pair(b12, b14);
    let pm = pair(b13, b10);
    let pz = pair(b15, b17);
    let jS = pair(b16, b18);
    let jT = pair(b17, b19);
    let po = pair(b18, b15);
    let pp = pair(b20, b22);
    let jU = pair(b21, b23);
    let jV = pair_high(b22, s24);
    let pq = pair_high(b23, s20);
    let kF = pair_high(b04, s09);
    let kJ = pair_high(b00, s05);
    let kG = pair(b01, b06);
    let qV = pair_high(b14, s24);
    let sM = pair_high(b10, s20);
    let kI = pair(b11, b21);
    (
        [
            pg ^ (jM | jN) ^ rc, pi ^ (jO | jP), pl ^ (jQ | jR), pz ^ (jS | jT), pp ^ (jU | jV),
            jM ^ (jN & ph), jO ^ (jP & pj), jQ ^ (jR & pm), jS ^ (jT & po), jU ^ (jV & pq),
            kF ^ (not128(kJ, k.mask128) & kG), qV ^ (sM | not128(kI, k.mask128)),
        ],
        xor64(b19, andn64(b15, b16, k.mask64)),
    )
}
/// Keccak-f[1600] over the packed 13-word state (layout in the module doc).
/// Pinned to FIPS 202 by the known-answer tests below.
#[inline(always)]
pub(crate) fn keccak_f1600_packed(st: [u128; 13]) -> [u128; 13] {
    let [u0, u1, u2, u3, u4, v0, v1, v2, v3, v4, bk, bL, g4] = st;
    let g4: u64 = g4.try_into().unwrap();
    let ([u0, u1, u2, u3, u4, v0, v1, v2, v3, v4, bk, bL], g4) = permute_packed(
        [u0, u1, u2, u3, u4, v0, v1, v2, v3, v4, bk, bL], upcast(g4),
    );
    [u0, u1, u2, u3, u4, v0, v1, v2, v3, v4, bk, bL, upcast(g4)]
}
/// One Keccak-f[1600] permutation over the packed 12-word state plus `lane24`.
#[inline(always)]
pub(crate) fn permute_packed(st: [u128; 12], g4: Lane) -> ([u128; 12], Lane) {
    let parities = column_parities(@st, g4);
    append_row4(run_from(st, g4, parities))
}
/// First-round theta followed by [`run_rounds`].
#[inline(always)]
pub(crate) fn theta_then_rounds(
    st: [u128; 12], g4: Lane, parities: ColumnParities,
) -> ([u128; 10], Row4) {
    run_rounds(absorb_round(st, g4, parities))
}
pub(crate) fn run_rounds(p: FirstRound) -> ([u128; 10], Row4) {
    let k = rot_constants();
    let mut rcs = ROUND_CONSTANTS.span();
    // Round 0 consumes the absorb-fused first round. Rounds 1..=14 share the stage-1
    // pipeline and rounds 16..=22 the stage-2 pipeline after the transition at round
    // 15; round 23 ends with the chi that restores the standard lane orientation.
    // Looping the two uniform stretches keeps the permutation's code size small at a
    // negligible per-round bookkeeping cost.
    let rc = *rcs.pop_front().unwrap();
    let mut st = chi_stage1(rho_pi_stage1(expand_first_round(p, k), k), rc, k);
    let mut round: u32 = 1;
    while round != 15 {
        let rc = *rcs.pop_front().unwrap();
        st = chi_stage1(rho_pi_stage1(theta_stage1(st, k), k), rc, k);
        round += 1;
    }
    let rc = *rcs.pop_front().unwrap();
    st = chi_stage2(rho_pi_stage1(theta_stage1(st, k), k), rc, k);
    round = 16;
    while round != 23 {
        let rc = *rcs.pop_front().unwrap();
        st = chi_stage2(rho_pi(theta_stage2(st, k), k), rc, k);
        round += 1;
    }
    let last_rc = *rcs.pop_front().unwrap();
    let (
        b00,
        b01,
        b02,
        b03,
        b04,
        b05,
        b06,
        b07,
        b08,
        b09,
        b10,
        b11,
        b12,
        b13,
        b14,
        b15,
        b16,
        b17,
        b18,
        b19,
        b20,
        b21,
        b22,
        b23,
        b24,
    ) =
        rho_pi(
        theta_last(st, k), k,
    );
    (
        chi_final(
            (
                b00,
                b01,
                b02,
                b03,
                b04,
                b05,
                b06,
                b07,
                b08,
                b09,
                b10,
                b11,
                b12,
                b13,
                b14,
                b15,
                b16,
                b17,
                b18,
                b19,
            ),
            last_rc,
            k,
        ),
        (b20, b21, b22, b23, b24),
    )
}
#[cfg(test)]
pub(crate) fn keccak_f1600(state: [u128; 25]) -> [u128; 25] {
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
    let st: [u128; 13] = [
        pack_lanes(s00, s01), pack_lanes(s05, s06), pack_lanes(s10, s11), pack_lanes(s15, s16),
        pack_lanes(s20, s21), pack_lanes(s02, s03), pack_lanes(s07, s08), pack_lanes(s12, s13),
        pack_lanes(s17, s18), pack_lanes(s22, s23), pack_lanes(s04, s09), pack_lanes(s14, s19), s24,
    ];
    let st = keccak_f1600_packed(st);
    let [u0, u1, u2, u3, u4, v0, v1, v2, v3, v4, bk, bL, g4] = st;
    let (sO, sN) = split_lanes(u0);
    let (sT, sS) = split_lanes(u1);
    let (sY, sX) = split_lanes(u2);
    let (tg, tf) = split_lanes(u3);
    let (tl, tk) = split_lanes(u4);
    let (sQ, sP) = split_lanes(v0);
    let (sV, sU) = split_lanes(v1);
    let (td, sZ) = split_lanes(v2);
    let (ti, th) = split_lanes(v3);
    let (tn, tm) = split_lanes(v4);
    let (sW, sR) = split_lanes(bk);
    let (tj, te) = split_lanes(bL);
    [
        sN, sO, sP, sQ, sR, sS, sT, sU, sV, sW, sX, sY, sZ, td, te, tf, tg, th, ti, tj, tk, tl, tm,
        tn, g4,
    ]
}
/// SHAKE-256: absorb `input`, squeeze `out_bytes` bytes. Test-only generic XOF used
/// to pin the sponge construction to the FIPS 202 known-answer vectors.
#[cfg(test)]
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
    let mut state = [0_u128; 25];
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

#[cfg(test)]
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

#[cfg(test)]
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

#[cfg(test)]
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


type Rot4Rest = BoundedInt<0, 0xfffffffffffffff>;
type Rot4Top = BoundedInt<0, 0xf>;
type Rot4Shifted = BoundedInt<0, 0xfffffffffffffff0>;
impl SplitRot4 of DivRemHelper<Lane, UnitInt<0x1000000000000000>> {
    type DivT = Rot4Top;
    type RemT = Rot4Rest;
}
impl ShiftRot4 of MulHelper<Rot4Rest, UnitInt<16>> {
    type Result = Rot4Shifted;
}
impl MergeRot4 of AddHelper<Rot4Shifted, Rot4Top> {
    type Result = Lane;
}
const M4: UnitInt<16> = 16;
type Rot13Rest = BoundedInt<0, 0x7ffffffffffff>;
type Rot13Top = BoundedInt<0, 0x1fff>;
type Rot13Shifted = BoundedInt<0, 0xffffffffffffe000>;
impl SplitRot13 of DivRemHelper<Lane, UnitInt<0x8000000000000>> {
    type DivT = Rot13Top;
    type RemT = Rot13Rest;
}
impl ShiftRot13 of MulHelper<Rot13Rest, UnitInt<8192>> {
    type Result = Rot13Shifted;
}
impl MergeRot13 of AddHelper<Rot13Shifted, Rot13Top> {
    type Result = Lane;
}
const M13: UnitInt<8192> = 8192;
type Rot19Rest = BoundedInt<0, 0x1fffffffffff>;
type Rot19Top = BoundedInt<0, 0x7ffff>;
type Rot19Shifted = BoundedInt<0, 0xfffffffffff80000>;
impl SplitRot19 of DivRemHelper<Lane, UnitInt<0x200000000000>> {
    type DivT = Rot19Top;
    type RemT = Rot19Rest;
}
impl ShiftRot19 of MulHelper<Rot19Rest, UnitInt<524288>> {
    type Result = Rot19Shifted;
}
impl MergeRot19 of AddHelper<Rot19Shifted, Rot19Top> {
    type Result = Lane;
}
const M19: UnitInt<524288> = 524288;
type Rot37Rest = BoundedInt<0, 0x7ffffff>;
type Rot37Top = BoundedInt<0, 0x1fffffffff>;
type Rot37Shifted = BoundedInt<0, 0xffffffe000000000>;
impl SplitRot37 of DivRemHelper<Lane, UnitInt<0x8000000>> {
    type DivT = Rot37Top;
    type RemT = Rot37Rest;
}
impl ShiftRot37 of MulHelper<Rot37Rest, UnitInt<137438953472>> {
    type Result = Rot37Shifted;
}
impl MergeRot37 of AddHelper<Rot37Shifted, Rot37Top> {
    type Result = Lane;
}
const M37: UnitInt<137438953472> = 137438953472;
type Rot42Rest = BoundedInt<0, 0x3fffff>;
type Rot42Top = BoundedInt<0, 0x3ffffffffff>;
type Rot42Shifted = BoundedInt<0, 0xfffffc0000000000>;
impl SplitRot42 of DivRemHelper<Lane, UnitInt<0x400000>> {
    type DivT = Rot42Top;
    type RemT = Rot42Rest;
}
impl ShiftRot42 of MulHelper<Rot42Rest, UnitInt<4398046511104>> {
    type Result = Rot42Shifted;
}
impl MergeRot42 of AddHelper<Rot42Shifted, Rot42Top> {
    type Result = Lane;
}
const M42: UnitInt<4398046511104> = 4398046511104;
type Rot54Rest = BoundedInt<0, 0x3ff>;
type Rot54Top = BoundedInt<0, 0x3fffffffffffff>;
type Rot54Shifted = BoundedInt<0, 0xffc0000000000000>;
impl SplitRot54 of DivRemHelper<Lane, UnitInt<0x400>> {
    type DivT = Rot54Top;
    type RemT = Rot54Rest;
}
impl ShiftRot54 of MulHelper<Rot54Rest, UnitInt<18014398509481984>> {
    type Result = Rot54Shifted;
}
impl MergeRot54 of AddHelper<Rot54Shifted, Rot54Top> {
    type Result = Lane;
}
const M54: UnitInt<18014398509481984> = 18014398509481984;
type Rot60Rest = BoundedInt<0, 0xf>;
type Rot60Top = BoundedInt<0, 0xfffffffffffffff>;
type Rot60Shifted = BoundedInt<0, 0xf000000000000000>;
impl SplitRot60 of DivRemHelper<Lane, UnitInt<0x10>> {
    type DivT = Rot60Top;
    type RemT = Rot60Rest;
}
impl ShiftRot60 of MulHelper<Rot60Rest, UnitInt<1152921504606846976>> {
    type Result = Rot60Shifted;
}
impl MergeRot60 of AddHelper<Rot60Shifted, Rot60Top> {
    type Result = Lane;
}
const M60: UnitInt<1152921504606846976> = 1152921504606846976;
/// Rho rotations with pi precomposed for the stage-1 orientation, emitting
/// lanes in destination order. Amounts differ from the FIPS offsets by the
/// virtual rotations the pipeline carries, so a few lanes pass through
/// unrotated; the known-answer tests pin the composition.
#[inline(always)]
fn rho_pi_stage1(
    a: (
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
    ),
    k: RotConstants,
) -> (
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
) {
    let (
        a00,
        a01,
        a02,
        a03,
        a04,
        a05,
        a06,
        a07,
        a08,
        a09,
        a10,
        a11,
        a12,
        a13,
        a14,
        a15,
        a16,
        a17,
        a18,
        a19,
        a20,
        a21,
        a22,
        a23,
        a24,
    ) =
        a;
    (
        rot62(a00, k.rd62),
        rot_generic(a06, k.rd42, M42),
        rot41(a12, k.rd41),
        rot_generic(a18, k.rd19, M19),
        rot_generic(a24, k.rd12, M12),
        rot_generic(a03, k.rd26, M26),
        rot18(a09, k.rd18),
        a10,
        rot43(a16, k.rd43),
        rot_generic(a22, k.rd59, M59),
        a01,
        rot_generic(a07, k.rd4, M4),
        rot_generic(a13, k.rd23, M23),
        rot6(a19, k.rd6),
        rot_generic(a20, k.rd16, M16),
        rot25(a04, k.rd25),
        rot_generic(a05, k.rd34, M34),
        rot8(a11, k.rd8),
        rot_generic(a17, k.rd13, M13),
        rot_generic(a23, k.rd54, M54),
        rot_generic(a02, k.rd60, M60),
        rot_generic(a08, k.rd53, M53),
        rot_generic(a14, k.rd37, M37),
        rot39(a15, k.rd39),
        a21,
    )
}
/// Theta and lane expansion for the stage-1 orientation (rounds 1..=15):
/// parities on packed pairs, arithmetic rotate-by-one, then per-lane splits
/// feeding rho.
#[inline(always)]
fn theta_stage1(
    st: ([u128; 12], Lane), k: RotConstants,
) -> (
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
) {
    let (st, g3) = st;
    let [e0, e1, e2, e3, e4, o0, o1, o2, o3, o4, g01, g24] = st;
    let x20 = e0 ^ e1 ^ e2 ^ e3 ^ e4;
    let x31 = o0 ^ o1 ^ o2 ^ o3 ^ o4;
    let (gh, gl) = split_pair(g01 ^ g24, k.two64);
    let c4 = xor64(xor64(gh, gl), g3);
    let (c0, c2) = split_pair(x20, k.two64);
    let (c1, c3) = split_pair(x31, k.two64);
    let (q31, rd42) = rotl1_two_pairs(c3, c1, c4, c2, k.two65.into(), k.mask64, k.mask128);
    let d20 = pair(c1, c4) ^ q31;
    let n20 = not128(d20, k.mask128);
    let d31 = x20 ^ rd42;
    let n31 = not128(d31, k.mask128);
    let (a10, a12) = split_pair(e2 ^ n20, k.two64);
    let (cq, crem) = div_rem(o0 ^ n31, k.two65);
    let (r0, a10, a03, a01) = rotl1_pair_split(c0, a10, cq, crem, k.mask64);
    let d4 = xor64(c3, r0);
    let dd4 = duplicate_lane(d4);
    let (a00, a02) = split_pair(e0 ^ d20, k.two64);
    let (a05, a07) = split_pair(e1 ^ d20, k.two64);
    let (a15, a17) = split_pair(e3 ^ d20, k.two64);
    let (a20, a22) = split_pair(e4 ^ n20, k.two64);
    let (a06, a08) = split_pair(o1 ^ n31, k.two64);
    let (a11, a13) = split_pair(o2 ^ d31, k.two64);
    let (a16, a18) = split_pair(o3 ^ n31, k.two64);
    let (a21, a23) = split_pair(o4 ^ d31, k.two64);
    let (a09, a04) = split_pair(g01 ^ dd4, k.two64);
    let (a24, a14) = split_pair(g24 ^ dd4, k.two64);
    let a19 = xor64(g3, d4);
    (
        a00,
        a01,
        a02,
        a03,
        a04,
        a05,
        a06,
        a07,
        a08,
        a09,
        a10,
        a11,
        a12,
        a13,
        a14,
        a15,
        a16,
        a17,
        a18,
        a19,
        a20,
        a21,
        a22,
        a23,
        a24,
    )
}
/// Chi and iota over repacked pairs for the stage-1 orientation. Lane groups
/// in or-form follow the standard lane-complementing transform, avoiding
/// materialized complements; the pre-adjusted round constants absorb the
/// bookkeeping.
#[inline(always)]
fn chi_stage1(
    b: (
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
        Lane,
    ),
    rc: u128,
    k: RotConstants,
) -> ([u128; 12], Lane) {
    let (
        b00,
        b01,
        b02,
        b03,
        b04,
        b05,
        b06,
        b07,
        b08,
        b09,
        b10,
        b11,
        b12,
        b13,
        b14,
        b15,
        b16,
        b17,
        b18,
        b19,
        b20,
        b21,
        b22,
        b23,
        b24,
    ) =
        b;
    let s05 = high_lane(b05);
    let s06 = high_lane(b06);
    let s20 = high_lane(b20);
    let s21 = high_lane(b21);
    let q020 = pair(b02, b00);
    let q031 = pair(b03, b01);
    let q042 = pair(b04, b02);
    let q003 = pair(b00, b03);
    let q120 = pair_high(b07, s05);
    let q131 = pair_high(b08, s06);
    let q142 = pair(b09, b07);
    let q103 = pair(b05, b08);
    let q220 = pair(b12, b10);
    let q231 = pair(b13, b11);
    let q242 = pair(b14, b12);
    let q203 = pair(b10, b13);
    let q320 = pair(b17, b15);
    let q331 = pair(b18, b16);
    let q342 = pair(b19, b17);
    let q303 = pair(b15, b18);
    let q420 = pair_high(b22, s20);
    let q431 = pair_high(b23, s21);
    let q442 = pair(b24, b22);
    let q403 = pair(b20, b23);
    (
        [
            q020 ^ (q031 | q042) ^ rc, q120 ^ (q131 | q142), q220 ^ (q231 | q242),
            q320 ^ (q331 | q342), q420 ^ (q431 | q442), q031 ^ (q042 & q003), q131 ^ (q142 & q103),
            q231 ^ (q242 & q203), q331 ^ (q342 & q303), q431 ^ (q442 & q403),
            pair(b04, b09) ^ (not128(pair_high(b00, s05), k.mask128) & pair_high(b01, s06)),
            pair(b14, b24) ^ (pair_high(b10, s20) | not128(pair_high(b11, s21), k.mask128)),
        ],
        xor64(b19, andn64(b15, b16, k.mask64)),
    )
}
/// Theta variant entering the final round, aligned so the closing chi can
/// restore the standard lane orientation.
#[inline(always)]
fn theta_last(
    st: ([u128; 12], Lane), k: RotConstants,
) -> (
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
    Lane,
) {
    let (st, g3) = st;
    let [e0, e1, e2, e3, e4, o0, o1, o2, o3, o4, bk, hI] = st;
    let eD = e0 ^ e1 ^ e2 ^ e3 ^ e4;
    let hG = o0 ^ o1 ^ o2 ^ o3 ^ o4;
    let (gh, gl) = split_pair(bk ^ hI, k.two64);
    let c4 = xor64(xor64(gh, gl), g3);
    let (c2, c0) = split_pair(eD, k.two64);
    let (c3, c1) = split_pair(hG, k.two64);
    let (kL, kM) = rotl1_two_pairs(c1, c3, c2, c4, k.two65.into(), k.mask64, k.mask128);
    let dk = not128(eD ^ kM, k.mask128);
    let (cO, cq) = split_pair(o3 ^ dk, k.two64);
    let ee = pair(c4, c1) ^ kL;
    let (top63, zm) = div_rem(e2 ^ ee, k.two65);
    let (r0, cq, cJ, cL) = rotl1_pair_split(c0, cq, top63, zm, k.mask64);
    let d4 = xor64(c3, r0);
    let dj = duplicate_lane(d4);
    let oO = not128(dj, k.mask128);
    let (cH, bK) = split_pair(e0 ^ ee, k.two64);
    let (du, ds) = split_pair(e1 ^ ee, k.two64);
    let (cI, dt) = split_pair(o1 ^ dk, k.two64);
    let (cM, cK) = split_pair(o2 ^ dk, k.two64);
    let (cN, cp) = split_pair(e3 ^ ee, k.two64);
    let (dq, bx) = split_pair(o0 ^ dk, k.two64);
    let (cR, cQ) = split_pair(e4 ^ ee, k.two64);
    let (cS, cr) = split_pair(o4 ^ dk, k.two64);
    let (dv, dr) = split_pair(bk ^ dj, k.two64);
    let (cT, cc) = split_pair(hI ^ oO, k.two64);
    let cP = xor64(g3, d4);
    (
        bK,
        bx,
        cH,
        dq,
        dr,
        ds,
        dt,
        du,
        cI,
        dv,
        cJ,
        cK,
        cL,
        cM,
        cc,
        cp,
        cq,
        cN,
        cO,
        cP,
        cQ,
        cr,
        cR,
        cS,
        cT,
    )
}
type LaneHigh = BoundedInt<0x8000000000000000, 0xffffffffffffffff>;
const TWO_POW_65_NZ: UnitInt<0x20000000000000000> = 0x20000000000000000;
impl DoubleLaneLow of AddHelper<LaneLow, LaneLow> {
    type Result = LaneEven;
}
impl DoubleLaneHigh of AddHelper<LaneHigh, LaneHigh> {
    type Result = BoundedInt<0x10000000000000000, 0x1fffffffffffffffe>;
}
const MASK_64: UnitInt<0xffffffffffffffff> = 0xffffffffffffffff;
const TWO_POW_64_UNIT: UnitInt<0x10000000000000000> = 0x10000000000000000;
const TWO_POW_63_UNIT: UnitInt<0x8000000000000000> = 0x8000000000000000;
/// Splits a lane on its top bit (`Ok` clear / `Err` set): the wrap source for
/// the arithmetic rotate-by-one below.
#[inline(always)]
fn split_top_bit(x: Lane) -> Result<LaneLow, LaneHigh> {
    constrain::<Lane, 0x8000000000000000>(x)
}
#[inline(always)]
fn rotl1_pair_plain(a: LaneLow, b: LaneLow, bo: TwoPow65) -> u128 {
    upcast(add(add(mul(b, bo), a), a))
}
#[inline(always)]
fn rotl1_pair_ll(a: LaneLow, b: LaneLow, bo: TwoPow65) -> u128 {
    let k: UnitInt<0> = 0;
    upcast(add(sub(add(mul(b, bo), a), k), a))
}
impl Rotl1WrapLl of SubHelper<BoundedInt<0, 0xfffffffffffffffe7fffffffffffffff>, UnitInt<0>> {
    type Result = BoundedInt<0, 0xfffffffffffffffe7fffffffffffffff>;
}
#[inline(always)]
fn rotl1_pair_lh(a: LaneLow, b: LaneHigh, bo: TwoPow65) -> u128 {
    let k: UnitInt<0xffffffffffffffff0000000000000000> = 0xffffffffffffffff0000000000000000;
    upcast(add(sub(add(mul(b, bo), a), k), a))
}
#[inline(always)]
fn rotl1_pair_hl(a: LaneHigh, b: LaneLow, bo: TwoPow65, m64: Mask64) -> u128 {
    upcast(add(sub(add(mul(b, bo), a), m64), a))
}
#[inline(always)]
fn rotl1_pair_hh(a: LaneHigh, b: LaneHigh, bo: TwoPow65, mask128_full: Mask128) -> u128 {
    upcast(add(sub(add(mul(b, bo), a), mask128_full), a))
}
#[inline(always)]
fn rotl1_plain(x: LaneLow) -> Lane {
    upcast(add(x, x))
}
#[inline(always)]
fn rotl1_low(x: LaneLow) -> Lane {
    let k: UnitInt<0> = 0;
    upcast(sub(add(x, x), k))
}
impl Rotl1WrapLaneLow of SubHelper<LaneEven, UnitInt<0>> {
    type Result = LaneEven;
}
#[inline(always)]
fn rotl1_high(x: LaneHigh, m64: Mask64) -> Lane {
    upcast(sub(add(x, x), m64))
}
/// Rotates four lanes (two pairs) left by one arithmetically: doubling shifts
/// every bit up and each constrained top bit wraps to bit zero; the match arms
/// apply the per-lane wrap correction.
#[inline(always)]
fn rotl1_two_pairs(
    ca: Lane, cb: Lane, cc: Lane, cd: Lane, bo: TwoPow65, m64: Mask64, mask128_full: Mask128,
) -> (u128, u128) {
    match split_top_bit(ca) {
        Ok(ya) => match split_top_bit(cb) {
            Ok(yb) => match split_top_bit(cc) {
                Ok(yc) => match split_top_bit(cd) {
                    Ok(yd) => (rotl1_pair_ll(ya, yb, bo), rotl1_pair_ll(yc, yd, bo)),
                    Err(yd) => (rotl1_pair_ll(ya, yb, bo), rotl1_pair_lh(yc, yd, bo)),
                },
                Err(yc) => match split_top_bit(cd) {
                    Ok(yd) => (rotl1_pair_ll(ya, yb, bo), rotl1_pair_hl(yc, yd, bo, m64)),
                    Err(yd) => (rotl1_pair_ll(ya, yb, bo), rotl1_pair_hh(yc, yd, bo, mask128_full)),
                },
            },
            Err(yb) => match split_top_bit(cc) {
                Ok(yc) => match split_top_bit(cd) {
                    Ok(yd) => (rotl1_pair_lh(ya, yb, bo), rotl1_pair_ll(yc, yd, bo)),
                    Err(yd) => (rotl1_pair_lh(ya, yb, bo), rotl1_pair_lh(yc, yd, bo)),
                },
                Err(yc) => match split_top_bit(cd) {
                    Ok(yd) => (rotl1_pair_lh(ya, yb, bo), rotl1_pair_hl(yc, yd, bo, m64)),
                    Err(yd) => (rotl1_pair_lh(ya, yb, bo), rotl1_pair_hh(yc, yd, bo, mask128_full)),
                },
            },
        },
        Err(ya) => match split_top_bit(cb) {
            Ok(yb) => match split_top_bit(cc) {
                Ok(yc) => match split_top_bit(cd) {
                    Ok(yd) => (rotl1_pair_hl(ya, yb, bo, m64), rotl1_pair_ll(yc, yd, bo)),
                    Err(yd) => (rotl1_pair_hl(ya, yb, bo, m64), rotl1_pair_lh(yc, yd, bo)),
                },
                Err(yc) => match split_top_bit(cd) {
                    Ok(yd) => (rotl1_pair_hl(ya, yb, bo, m64), rotl1_pair_hl(yc, yd, bo, m64)),
                    Err(yd) => (
                        rotl1_pair_hl(ya, yb, bo, m64), rotl1_pair_hh(yc, yd, bo, mask128_full),
                    ),
                },
            },
            Err(yb) => match split_top_bit(cc) {
                Ok(yc) => match split_top_bit(cd) {
                    Ok(yd) => (rotl1_pair_hh(ya, yb, bo, mask128_full), rotl1_pair_ll(yc, yd, bo)),
                    Err(yd) => (rotl1_pair_hh(ya, yb, bo, mask128_full), rotl1_pair_lh(yc, yd, bo)),
                },
                Err(yc) => match split_top_bit(cd) {
                    Ok(yd) => (
                        rotl1_pair_hh(ya, yb, bo, mask128_full), rotl1_pair_hl(yc, yd, bo, m64),
                    ),
                    Err(yd) => (
                        rotl1_pair_hh(ya, yb, bo, mask128_full),
                        rotl1_pair_hh(yc, yd, bo, mask128_full),
                    ),
                },
            },
        },
    }
}
/// Rotate-by-one across a mixed single-lane/pair boundary, combining the
/// top-bit wraps with a pair split.
#[inline(always)]
fn rotl1_pair_split(
    c0: Lane, cl: Lane, cq: BoundedInt<0, 0x7fffffffffffffff>, crem: LaneCarry, m64: Mask64,
) -> (Lane, Lane, Lane, Lane) {
    match split_top_bit(c0) {
        Ok(ya) => match split_top_bit(cl) {
            Ok(yb) => match constrain::<LaneCarry, 0x10000000000000000>(crem) {
                Ok(lo) => {
                    let (o3, o1) = (lo, upcast(cq));
                    (rotl1_low(ya), rotl1_low(yb), o3, o1)
                },
                Err(lo) => {
                    let (o3, o1) = (sub(lo, TWO_POW_64_UNIT), upcast(add(cq, TWO_POW_63_UNIT)));
                    (rotl1_low(ya), rotl1_low(yb), o3, o1)
                },
            },
            Err(yb) => match constrain::<LaneCarry, 0x10000000000000000>(crem) {
                Ok(lo) => {
                    let (o3, o1) = (lo, upcast(cq));
                    (rotl1_low(ya), rotl1_high(yb, m64), o3, o1)
                },
                Err(lo) => {
                    let (o3, o1) = (sub(lo, TWO_POW_64_UNIT), upcast(add(cq, TWO_POW_63_UNIT)));
                    (rotl1_low(ya), rotl1_high(yb, m64), o3, o1)
                },
            },
        },
        Err(ya) => match split_top_bit(cl) {
            Ok(yb) => match constrain::<LaneCarry, 0x10000000000000000>(crem) {
                Ok(lo) => {
                    let (o3, o1) = (lo, upcast(cq));
                    (rotl1_high(ya, m64), rotl1_low(yb), o3, o1)
                },
                Err(lo) => {
                    let (o3, o1) = (sub(lo, TWO_POW_64_UNIT), upcast(add(cq, TWO_POW_63_UNIT)));
                    (rotl1_high(ya, m64), rotl1_low(yb), o3, o1)
                },
            },
            Err(yb) => match constrain::<LaneCarry, 0x10000000000000000>(crem) {
                Ok(lo) => {
                    let (o3, o1) = (lo, upcast(cq));
                    (rotl1_high(ya, m64), rotl1_high(yb, m64), o3, o1)
                },
                Err(lo) => {
                    let (o3, o1) = (sub(lo, TWO_POW_64_UNIT), upcast(add(cq, TWO_POW_63_UNIT)));
                    (rotl1_high(ya, m64), rotl1_high(yb, m64), o3, o1)
                },
            },
        },
    }
}


/// Instantiates every `rot_generic` offset with the production divisor table. The
/// call sites live in this module so impl resolution matches the round functions'.
#[cfg(test)]
fn generic_rotations(x: Lane, k: RotConstants) -> Array<(u32, Lane)> {
    let m4: UnitInt<16> = 16;
    let m11: UnitInt<2048> = 2048;
    let m12: UnitInt<4096> = 4096;
    let m13: UnitInt<8192> = 8192;
    let m16: UnitInt<65536> = 65536;
    let m17: UnitInt<131072> = 131072;
    let m19: UnitInt<524288> = 524288;
    let m22: UnitInt<4194304> = 4194304;
    let m23: UnitInt<8388608> = 8388608;
    let m26: UnitInt<67108864> = 67108864;
    let m30: UnitInt<1073741824> = 1073741824;
    let m34: UnitInt<17179869184> = 17179869184;
    let m35: UnitInt<34359738368> = 34359738368;
    let m37: UnitInt<137438953472> = 137438953472;
    let m38: UnitInt<274877906944> = 274877906944;
    let m40: UnitInt<1099511627776> = 1099511627776;
    let m42: UnitInt<4398046511104> = 4398046511104;
    let m47: UnitInt<140737488355328> = 140737488355328;
    let m48: UnitInt<281474976710656> = 281474976710656;
    let m53: UnitInt<9007199254740992> = 9007199254740992;
    let m54: UnitInt<18014398509481984> = 18014398509481984;
    let m59: UnitInt<576460752303423488> = 576460752303423488;
    let m60: UnitInt<1152921504606846976> = 1152921504606846976;
    array![
        (4, rot_generic(x, k.rd4, m4)), (11, rot_generic(x, k.rd11, m11)),
        (12, rot_generic(x, k.rd12, m12)), (13, rot_generic(x, k.rd13, m13)),
        (16, rot_generic(x, k.rd16, m16)), (17, rot_generic(x, k.rd17, m17)),
        (19, rot_generic(x, k.rd19, m19)), (22, rot_generic(x, k.rd22, m22)),
        (23, rot_generic(x, k.rd23, m23)), (26, rot_generic(x, k.rd26, m26)),
        (30, rot_generic(x, k.rd30, m30)), (34, rot_generic(x, k.rd34, m34)),
        (35, rot_generic(x, k.rd35, m35)), (37, rot_generic(x, k.rd37, m37)),
        (38, rot_generic(x, k.rd38, m38)), (40, rot_generic(x, k.rd40, m40)),
        (42, rot_generic(x, k.rd42, m42)), (47, rot_generic(x, k.rd47, m47)),
        (48, rot_generic(x, k.rd48, m48)), (53, rot_generic(x, k.rd53, m53)),
        (54, rot_generic(x, k.rd54, m54)), (59, rot_generic(x, k.rd59, m59)),
        (60, rot_generic(x, k.rd60, m60)),
    ]
}

#[cfg(test)]
mod tests {
    use openzeppelin_corelib_imports::bounded_int::{downcast, upcast};
    use super::{
        Lane, MASK_128, MASK_64, TWO_POW_65_NZ, generic_rotations, rot18, rot20, rot21, rot25,
        rot28, rot39, rot41, rot43, rot45, rot56, rot6, rot61, rot62, rot8, rot_constants,
        rotl1_lane_and_pair, rotl1_two_pairs, shake256,
    };

    fn lane_of(x: u128) -> Lane {
        downcast(x).unwrap()
    }

    fn pow2(n: u32) -> u256 {
        let mut r: u256 = 1;
        let mut i = 0;
        while i != n {
            r = r * 2;
            i += 1;
        }
        r
    }

    /// Left-rotation reference over plain integers.
    fn rot_ref(x: u128, n: u32) -> u128 {
        let w: u256 = x.into();
        ((w * pow2(n)) % pow2(64) + w / pow2(64 - n)).try_into().unwrap()
    }

    fn rot1_pair_ref(a: u128, b: u128) -> u128 {
        let paired = rot_ref(a, 1).into() + rot_ref(b, 1).into() * 0x10000000000000000_u256;
        paired.try_into().unwrap()
    }

    // 0, 1, both split_top_bit halves at their extremes, and asymmetric patterns.
    const ROT_INPUTS: [u128; 6] = [
        0, 1, 0x8000000000000000, 0xffffffffffffffff, 0x0123456789abcdef, 0xfedcba9876543210,
    ];

    #[test]
    fn test_rotations_match_u128_reference_for_all_offsets() {
        let k = rot_constants();
        for value in ROT_INPUTS.span() {
            let x = *value;
            let r: u128 = upcast(rot6(lane_of(x), k.rd6));
            assert_eq!(r, rot_ref(x, 6));
            let r: u128 = upcast(rot8(lane_of(x), k.rd8));
            assert_eq!(r, rot_ref(x, 8));
            let r: u128 = upcast(rot18(lane_of(x), k.rd18));
            assert_eq!(r, rot_ref(x, 18));
            let r: u128 = upcast(rot20(lane_of(x), k.rd20));
            assert_eq!(r, rot_ref(x, 20));
            let r: u128 = upcast(rot21(lane_of(x), k.rd21));
            assert_eq!(r, rot_ref(x, 21));
            let r: u128 = upcast(rot25(lane_of(x), k.rd25));
            assert_eq!(r, rot_ref(x, 25));
            let r: u128 = upcast(rot28(lane_of(x), k.rd28));
            assert_eq!(r, rot_ref(x, 28));
            let r: u128 = upcast(rot39(lane_of(x), k.rd39));
            assert_eq!(r, rot_ref(x, 39));
            let r: u128 = upcast(rot41(lane_of(x), k.rd41));
            assert_eq!(r, rot_ref(x, 41));
            let r: u128 = upcast(rot43(lane_of(x), k.rd43));
            assert_eq!(r, rot_ref(x, 43));
            let r: u128 = upcast(rot45(lane_of(x), k.rd45));
            assert_eq!(r, rot_ref(x, 45));
            let r: u128 = upcast(rot56(lane_of(x), k.rd56));
            assert_eq!(r, rot_ref(x, 56));
            let r: u128 = upcast(rot61(lane_of(x), k.rd61));
            assert_eq!(r, rot_ref(x, 61));
            let r: u128 = upcast(rot62(lane_of(x), k.rd62));
            assert_eq!(r, rot_ref(x, 62));
            for entry in generic_rotations(lane_of(x), k).span() {
                let (n, rotated) = *entry;
                let rotated: u128 = upcast(rotated);
                assert_eq!(rotated, rot_ref(x, n));
            }
        }
    }

    #[test]
    fn test_rotl1_covers_every_top_bit_combination() {
        let options: [u128; 2] = [0x0123456789abcdef, 0x89abcdef01234567];
        for c0 in options.span() {
            for ca in options.span() {
                for cb in options.span() {
                    let (r, pair) = rotl1_lane_and_pair(
                        lane_of(*c0), lane_of(*ca), lane_of(*cb), TWO_POW_65_NZ, MASK_64, MASK_128,
                    );
                    let r: u128 = upcast(r);
                    assert_eq!(r, rot_ref(*c0, 1));
                    assert_eq!(pair, rot1_pair_ref(*ca, *cb));
                }
            }
        }
        for ca in options.span() {
            for cb in options.span() {
                for cc in options.span() {
                    for cd in options.span() {
                        let (p0, p1) = rotl1_two_pairs(
                            lane_of(*ca),
                            lane_of(*cb),
                            lane_of(*cc),
                            lane_of(*cd),
                            TWO_POW_65_NZ,
                            MASK_64,
                            MASK_128,
                        );
                        assert_eq!(p0, rot1_pair_ref(*ca, *cb));
                        assert_eq!(p1, rot1_pair_ref(*cc, *cd));
                    }
                }
            }
        }
    }

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
        while i != 200_u32 {
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
#[cfg(test)]
mod keccak_f_vectors {
    use super::keccak_f1600;
    #[test]
    fn test_keccak_f_vector_0_falcon_512_shake() {
        let out = keccak_f1600(
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        );
        assert!(
            out
                .span() == [
                    0xf1258f7940e1dde7, 0x84d5ccf933c0478a, 0xd598261ea65aa9ee, 0xbd1547306f80494d,
                    0x8b284e056253d057, 0xff97a42d7f8e6fd4, 0x90fee5a0a44647c4, 0x8c5bda0cd6192e76,
                    0xad30a6f71b19059c, 0x30935ab7d08ffc64, 0xeb5aa93f2317d635, 0xa9a6e6260d712103,
                    0x81a57c16dbcf555f, 0x43b831cd0347c826, 0x1f22f1a11a5569f, 0x5e5635a21d9ae61,
                    0x64befef28cc970f2, 0x613670957bc46611, 0xb87c5a554fd00ecb, 0x8c3ee88a1ccf32c8,
                    0x940c7922ae3a2614, 0x1841f924a2c509e4, 0x16f53526e70465c2, 0x75f644e97f30a13b,
                    0xeaf1ff7b5ceca249,
                ]
                .span(),
        );
    }
    #[test]
    fn test_keccak_f_vector_1_falcon_512_shake() {
        let out = keccak_f1600(
            [
                0xf1258f7940e1dde7, 0x84d5ccf933c0478a, 0xd598261ea65aa9ee, 0xbd1547306f80494d,
                0x8b284e056253d057, 0xff97a42d7f8e6fd4, 0x90fee5a0a44647c4, 0x8c5bda0cd6192e76,
                0xad30a6f71b19059c, 0x30935ab7d08ffc64, 0xeb5aa93f2317d635, 0xa9a6e6260d712103,
                0x81a57c16dbcf555f, 0x43b831cd0347c826, 0x1f22f1a11a5569f, 0x5e5635a21d9ae61,
                0x64befef28cc970f2, 0x613670957bc46611, 0xb87c5a554fd00ecb, 0x8c3ee88a1ccf32c8,
                0x940c7922ae3a2614, 0x1841f924a2c509e4, 0x16f53526e70465c2, 0x75f644e97f30a13b,
                0xeaf1ff7b5ceca249,
            ],
        );
        assert!(
            out
                .span() == [
                    0x2d5c954df96ecb3c, 0x6a332cd07057b56d, 0x93d8d1270d76b6c, 0x8a20d9b25569d094,
                    0x4f9c4f99e5e7f156, 0xf957b9a2da65fb38, 0x85773dae1275af0d, 0xfaf4f247c3d810f7,
                    0x1f1b9ee6f79a8759, 0xe4fecc0fee98b425, 0x68ce61b6b9ce68a1, 0xdeea66c4ba8f974f,
                    0x33c43d836eafb1f5, 0xe00654042719dbd9, 0x7cf8a9f009831265, 0xfd5449a6bf174743,
                    0x97ddad33d8994b40, 0x48ead5fc5d0be774, 0xe3b8c8ee55b7b03c, 0x91a0226e649e42e9,
                    0x900e3129e7badd7b, 0x202a9ec5faa3cce8, 0x5b3402464e1c3db6, 0x609f4e62a44c1059,
                    0x20d06cd26a8fbf5c,
                ]
                .span(),
        );
    }
    #[test]
    fn test_keccak_f_vector_2_falcon_512_shake() {
        let out = keccak_f1600(
            [
                0xc93a7b79aeda89b, 0x19274f6f35db5136, 0x25baf726d0c8f9d1, 0x324e9ede6bb6a26c,
                0x3ee2469606a44b07, 0x4b75ee4da191f3a2, 0x580996053c7f9c3d, 0x649d3dbcd76d44d8,
                0x7130e574725aed73, 0x7dc48d2c0d48960e, 0x8a5834e3a8363ea9, 0x96ebdc9b4323e744,
                0xa37f8452de118fdf, 0xb0132c0a78ff387a, 0xbca6d3c213ece115, 0xc93a7b79aeda89b0,
                0xd5ce233149c8324b, 0xe261cae8e4b5dae6, 0xeef572a07fa38381, 0xfb891a581a912c1c,
                0x81cc20fb57ed4b7, 0x14b069c7506c7d52, 0x2144117eeb5a25ed, 0x2dd7b9368647ce88,
                0x3a6b60ee21357723,
            ],
        );
        assert!(
            out
                .span() == [
                    0x9a55f58818107b8b, 0x9c237535940baf72, 0xbd0c324152d6220d, 0x9da8569ccdb5dd3a,
                    0xf0d46ce0f516f6ef, 0x53e71ddc3d52f807, 0xf4607b43da76737, 0x335f9806c8093c30,
                    0xb7fe91f3443df64, 0xa8daf764a67c5b2d, 0xc4d14662ca484e1d, 0xce05173999243243,
                    0xce0794b41ae88376, 0x58bc49864db0750d, 0x95e1762981b2c986, 0xe589329e740f147,
                    0x43a283a94c4c4392, 0x48b1b58973e61ee2, 0x32d7ccb6f0dd477b, 0x7d5ca23bf2b6a73,
                    0x69dd5a92ff95434d, 0x8d7da9e66673bf7a, 0x28df10e4105aab86, 0xae75fe0245d5b0de,
                    0xf6e32cdf7679c422,
                ]
                .span(),
        );
    }
    #[test]
    fn test_keccak_f_vector_3_falcon_512_shake() {
        let out = keccak_f1600(
            [
                0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff,
                0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff,
                0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff,
                0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff,
                0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff,
                0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff, 0xffffffffffffffff,
                0xffffffffffffffff,
            ],
        );
        assert!(
            out
                .span() == [
                    0x9f00f21bba6817c4, 0xcdf5aa0d21af5e78, 0xd6539abf24095b97, 0x8bb6f30a010f8228,
                    0xf0f711ba0547331d, 0x4f44330558eb182f, 0x2213b79d9055207c, 0xeb5e5b55ca4fb490,
                    0xbfaeb81a299b5d4, 0x9e5d924f1a65ed48, 0x4650c533b7bfb3, 0xddad454b84d7ab05,
                    0xf03ce56503e82921, 0xce442e92c6728660, 0x1a9ce5e4b37ddcd3, 0xf63b60e27cea6f0e,
                    0xcc4cc7fca665bfad, 0x40cf4eba54a2285d, 0x2725f1f142304213, 0x554d327de6fbad9b,
                    0x19866a26cbc8bdc2, 0xe8c3c28faf02c7f5, 0xc6bc1f3512a665ae, 0xcaa831f1a5dc86ce,
                    0x3f82afe91ca4b9b0,
                ]
                .span(),
        );
    }
    #[test]
    fn test_keccak_f_iterated_falcon_512_shake() {
        let mut s: [u128; 25] = [0; 25];
        let mut i: u32 = 0;
        while i < 5 {
            s = keccak_f1600(s);
            i += 1;
        }
        assert!(
            s
                .span() == [
                    0xc9f309ff271c6631, 0x9281c8b3825841b4, 0x2219cb1928ca14c4, 0xf50d1d2ae140281a,
                    0xf0a33a68985b6934, 0xd8a79767500429f6, 0xbe55a8fff0767faf, 0xbc2a9530cca9d7a8,
                    0x7e7947debc81b851, 0x772429b40aa052a8, 0x58f891e79ce86365, 0x3110152cadf8860f,
                    0x7f6f0628bda22d08, 0xa89fb4db4293cc0a, 0x390bca6688ab09be, 0xfadcbb8bbbedce4b,
                    0x2d78a388460c4a73, 0xe692f192c06ea9ae, 0x909de0d99f0083f0, 0x76773fcdc7e9d261,
                    0x344d00ae9d02c853, 0x9d85cb92ef2a6155, 0xa1a8ecf6537e0b3, 0xa6da3fb1f1688e95,
                    0xcfe9307b7db8bed0,
                ]
                .span(),
        );
    }
}
