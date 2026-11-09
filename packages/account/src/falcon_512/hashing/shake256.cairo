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
//! The packing is an internal optimization only: [`keccak_f1600`] preserves the plain
//! 25-lane interface, and the permutation known-answer vectors plus the FIPS 202 XOF
//! known-answer tests below pin both entry points to the standard.
//!
//! `hash_to_point::hash_to_point_shake_512` drives [`keccak_f1600_packed`] directly to
//! keep the state packed across squeezed blocks.

use openzeppelin_corelib_imports::bounded_int::{
    AddHelper, BoundedInt, ConstrainHelper, DivRemHelper, MulHelper, SubHelper, UnitInt,
    bounded_int, constrain, upcast,
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
impl jg of SubHelper<Mask128, u128> {
    type Result = BoundedInt<0, 0xffffffffffffffffffffffffffffffff>;
}
#[inline(always)]
fn split_lanes(w: u128) -> (u128, u128) {
    let (high, low) = bounded_int::div_rem(w, TWO_POW_64_NZ);
    (upcast(high), upcast(low))
}

#[inline(always)]
pub(crate) fn pack_lanes(lo: u128, hi: u128) -> u128 {
    let packed: felt252 = lo.into() + hi.into() * 0x10000000000000000;
    packed.try_into().unwrap()
}
impl gR of DivRemHelper<u128, TwoPow64> {
    type DivT = Lane;
    type RemT = Lane;
}
type TwoPow64Mul = UnitInt<0x10000000000000000>;
type HighHalf = BoundedInt<0, 0xffffffffffffffff0000000000000000>;
impl jc of MulHelper<Lane, TwoPow64Mul> {
    type Result = HighHalf;
}
impl he of AddHelper<Lane, HighHalf> {
    type Result = BoundedInt<0, 0xffffffffffffffffffffffffffffffff>;
}
/// Packs two lanes into one `u128` pair: `lo + hi * 2^64`.
#[inline(always)]
pub(crate) fn pair(lo: Lane, hi: Lane) -> u128 {
    let two64: TwoPow64Mul = 0x10000000000000000;
    upcast(bounded_int::add(lo, bounded_int::mul(hi, two64)))
}
/// Places a lane in a pair's high half (`lane * 2^64`).
#[inline(always)]
fn high_lane(hi: Lane) -> HighHalf {
    let two64: TwoPow64Mul = 0x10000000000000000;
    bounded_int::mul(hi, two64)
}
type DuplicateMul = UnitInt<0x10000000000000001>;
impl fv of MulHelper<Lane, DuplicateMul> {
    type Result = BoundedInt<0, 0xffffffffffffffffffffffffffffffff>;
}
/// Duplicates a lane into both halves (`lane * (2^64 + 1)`), so one XOR
/// against the result updates two lanes at once.
#[inline(always)]
fn duplicate_lane(x: Lane) -> u128 {
    let m: DuplicateMul = 0x10000000000000001;
    upcast(bounded_int::mul(x, m))
}
/// Packs a lane with an already-shifted high half.
#[inline(always)]
fn pair_high(lo: Lane, hi: HighHalf) -> u128 {
    upcast(bounded_int::add(lo, hi))
}
type LaneLow = BoundedInt<0, 0x7fffffffffffffff>;
type LaneEven = BoundedInt<0, 0xfffffffffffffffe>;
type hw = BoundedInt<0, 63>;
type hB = BoundedInt<0, 0x3ffffffffffffff>;
type hr = BoundedInt<0, 0xffffffffffffffc0>;
impl jx of DivRemHelper<Lane, UnitInt<0x400000000000000>> {
    type DivT = hw;
    type RemT = hB;
}
impl nF of MulHelper<hB, UnitInt<64>> {
    type Result = hr;
}
impl ns of AddHelper<hr, hw> {
    type Result = Lane;
}
type hx = BoundedInt<0, 255>;
type hC = BoundedInt<0, 0xffffffffffffff>;
type hs = BoundedInt<0, 0xffffffffffffff00>;
impl jy of DivRemHelper<Lane, UnitInt<72057594037927936>> {
    type DivT = hx;
    type RemT = hC;
}
impl nG of MulHelper<hC, UnitInt<256>> {
    type Result = hs;
}
impl nt of AddHelper<hs, hx> {
    type Result = Lane;
}
type fV = BoundedInt<0, 1048575>;
type gv = BoundedInt<0, 0xfffffffffff>;
type fC = BoundedInt<0, 0xfffffffffff00000>;
impl iT of DivRemHelper<Lane, UnitInt<17592186044416>> {
    type DivT = fV;
    type RemT = gv;
}
impl mY of MulHelper<gv, UnitInt<1048576>> {
    type Result = fC;
}
impl mE of AddHelper<fC, fV> {
    type Result = Lane;
}
type fW = BoundedInt<0, 2097151>;
type gw = BoundedInt<0, 8796093022207>;
type fD = BoundedInt<0, 0xffffffffffe00000>;
impl iU of DivRemHelper<Lane, UnitInt<8796093022208>> {
    type DivT = fW;
    type RemT = gw;
}
impl mZ of MulHelper<gw, UnitInt<2097152>> {
    type Result = fD;
}
impl mF of AddHelper<fD, fW> {
    type Result = Lane;
}
type fX = BoundedInt<0, 33554431>;
type gx = BoundedInt<0, 549755813887>;
type fE = BoundedInt<0, 0xfffffffffe000000>;
impl iV of DivRemHelper<Lane, UnitInt<549755813888>> {
    type DivT = fX;
    type RemT = gx;
}
impl na of MulHelper<gx, UnitInt<33554432>> {
    type Result = fE;
}
impl mG of AddHelper<fE, fX> {
    type Result = Lane;
}
type fZ = BoundedInt<0, 268435455>;
type gz = BoundedInt<0, 68719476735>;
type fG = BoundedInt<0, 0xfffffffff0000000>;
impl iX of DivRemHelper<Lane, UnitInt<68719476736>> {
    type DivT = fZ;
    type RemT = gz;
}
impl nd of MulHelper<gz, UnitInt<268435456>> {
    type Result = fG;
}
impl mI of AddHelper<fG, fZ> {
    type Result = Lane;
}
type gd = BoundedInt<0, 549755813887>;
type gB = BoundedInt<0, 33554431>;
type fI = BoundedInt<0, 0xffffff8000000000>;
impl iZ of DivRemHelper<Lane, UnitInt<33554432>> {
    type DivT = gd;
    type RemT = gB;
}
impl ng of MulHelper<gB, UnitInt<549755813888>> {
    type Result = fI;
}
impl mK of AddHelper<fI, gd> {
    type Result = Lane;
}
type gf = BoundedInt<0, 2199023255551>;
type gC = BoundedInt<0, 8388607>;
type fJ = BoundedInt<0, 0xfffffe0000000000>;
impl i0 of DivRemHelper<Lane, UnitInt<8388608>> {
    type DivT = gf;
    type RemT = gC;
}
impl nh of MulHelper<gC, UnitInt<2199023255552>> {
    type Result = fJ;
}
impl mL of AddHelper<fJ, gf> {
    type Result = Lane;
}
type gg = BoundedInt<0, 8796093022207>;
type gD = BoundedInt<0, 2097151>;
type fK = BoundedInt<0, 0xfffff80000000000>;
impl i1 of DivRemHelper<Lane, UnitInt<2097152>> {
    type DivT = gg;
    type RemT = gD;
}
impl ni of MulHelper<gD, UnitInt<8796093022208>> {
    type Result = fK;
}
impl mM of AddHelper<fK, gg> {
    type Result = Lane;
}
type gk = BoundedInt<0, 35184372088831>;
type gF = BoundedInt<0, 524287>;
type fM = BoundedInt<0, 0xffffe00000000000>;
impl i4 of DivRemHelper<Lane, UnitInt<524288>> {
    type DivT = gk;
    type RemT = gF;
}
impl nk of MulHelper<gF, UnitInt<35184372088832>> {
    type Result = fM;
}
impl mO of AddHelper<fM, gk> {
    type Result = Lane;
}
type gp = BoundedInt<0, 0x3fffffffffffffff>;
type gJ = BoundedInt<0, 3>;
type fQ = BoundedInt<0, 0xc000000000000000>;
impl i9 of DivRemHelper<Lane, UnitInt<4>> {
    type DivT = gp;
    type RemT = gJ;
}
impl no of MulHelper<gJ, UnitInt<0x4000000000000000>> {
    type Result = fQ;
}
impl mS of AddHelper<fQ, gp> {
    type Result = Lane;
}
type fU = BoundedInt<0, 262143>;
type gu = BoundedInt<0, 70368744177663>;
type fB = BoundedInt<0, 0xfffffffffffc0000>;
impl iS of DivRemHelper<Lane, UnitInt<70368744177664>> {
    type DivT = fU;
    type RemT = gu;
}
impl mX of MulHelper<gu, UnitInt<262144>> {
    type Result = fB;
}
impl mD of AddHelper<fB, fU> {
    type Result = Lane;
}
#[inline(always)]
fn rot18(x: Lane, d: NonZero<UnitInt<70368744177664>>) -> Lane {
    let m: UnitInt<262144> = 262144;
    let (aH, rest) = bounded_int::div_rem(x, d);
    bounded_int::add(bounded_int::mul(rest, m), aH)
}
type gn = BoundedInt<0, 0xffffffffffffff>;
type gH = BoundedInt<0, 255>;
type fO = BoundedInt<0, 0xff00000000000000>;
impl i6 of DivRemHelper<Lane, UnitInt<256>> {
    type DivT = gn;
    type RemT = gH;
}
impl nm of MulHelper<gH, UnitInt<72057594037927936>> {
    type Result = fO;
}
impl mQ of AddHelper<fO, gn> {
    type Result = Lane;
}
#[inline(always)]
fn rot56(x: Lane, d: NonZero<UnitInt<256>>) -> Lane {
    let m: UnitInt<72057594037927936> = 72057594037927936;
    let (aH, rest) = bounded_int::div_rem(x, d);
    bounded_int::add(bounded_int::mul(rest, m), aH)
}
type go = BoundedInt<0, 0x1fffffffffffffff>;
type gI = BoundedInt<0, 7>;
type fP = BoundedInt<0, 0xe000000000000000>;
impl i7 of DivRemHelper<Lane, UnitInt<8>> {
    type DivT = go;
    type RemT = gI;
}
impl nn of MulHelper<gI, UnitInt<0x2000000000000000>> {
    type Result = fP;
}
impl mR of AddHelper<fP, go> {
    type Result = Lane;
}
#[inline(always)]
fn rot61(x: Lane, d: NonZero<UnitInt<8>>) -> Lane {
    let m: UnitInt<0x2000000000000000> = 0x2000000000000000;
    let (aH, rest) = bounded_int::div_rem(x, d);
    bounded_int::add(bounded_int::mul(rest, m), aH)
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
    let (t, r) = bounded_int::div_rem(x, d);
    bounded_int::add(bounded_int::mul(r, m), t)
}
impl ve of DivRemHelper<Lane, UnitInt<9007199254740992>> {
    type DivT = BoundedInt<0, 2047>;
    type RemT = BoundedInt<0, 9007199254740991>;
}
impl vA of MulHelper<BoundedInt<0, 9007199254740991>, UnitInt<2048>> {
    type Result = BoundedInt<0, 0xfffffffffffff800>;
}
impl uN of AddHelper<BoundedInt<0, 0xfffffffffffff800>, BoundedInt<0, 2047>> {
    type Result = Lane;
}
const M11: UnitInt<2048> = 2048;
impl vf of DivRemHelper<Lane, UnitInt<4503599627370496>> {
    type DivT = BoundedInt<0, 4095>;
    type RemT = BoundedInt<0, 0xfffffffffffff>;
}
impl vB of MulHelper<BoundedInt<0, 0xfffffffffffff>, UnitInt<4096>> {
    type Result = BoundedInt<0, 0xfffffffffffff000>;
}
impl uO of AddHelper<BoundedInt<0, 0xfffffffffffff000>, BoundedInt<0, 4095>> {
    type Result = Lane;
}
const M12: UnitInt<4096> = 4096;
impl vh of DivRemHelper<Lane, UnitInt<0x800000000000>> {
    type DivT = BoundedInt<0, 131071>;
    type RemT = BoundedInt<0, 0x7fffffffffff>;
}
impl vD of MulHelper<BoundedInt<0, 0x7fffffffffff>, UnitInt<131072>> {
    type Result = BoundedInt<0, 0xfffffffffffe0000>;
}
impl uQ of AddHelper<BoundedInt<0, 0xfffffffffffe0000>, BoundedInt<0, 131071>> {
    type Result = Lane;
}
const M17: UnitInt<131072> = 131072;
impl vi of DivRemHelper<Lane, UnitInt<4398046511104>> {
    type DivT = BoundedInt<0, 4194303>;
    type RemT = BoundedInt<0, 4398046511103>;
}
impl vE of MulHelper<BoundedInt<0, 4398046511103>, UnitInt<4194304>> {
    type Result = BoundedInt<0, 0xffffffffffc00000>;
}
impl uR of AddHelper<BoundedInt<0, 0xffffffffffc00000>, BoundedInt<0, 4194303>> {
    type Result = Lane;
}
const M22: UnitInt<4194304> = 4194304;
impl vj of DivRemHelper<Lane, UnitInt<2199023255552>> {
    type DivT = BoundedInt<0, 8388607>;
    type RemT = BoundedInt<0, 2199023255551>;
}
impl vF of MulHelper<BoundedInt<0, 2199023255551>, UnitInt<8388608>> {
    type Result = BoundedInt<0, 0xffffffffff800000>;
}
impl uS of AddHelper<BoundedInt<0, 0xffffffffff800000>, BoundedInt<0, 8388607>> {
    type Result = Lane;
}
const M23: UnitInt<8388608> = 8388608;
impl vk of DivRemHelper<Lane, UnitInt<274877906944>> {
    type DivT = BoundedInt<0, 67108863>;
    type RemT = BoundedInt<0, 274877906943>;
}
impl vG of MulHelper<BoundedInt<0, 274877906943>, UnitInt<67108864>> {
    type Result = BoundedInt<0, 0xfffffffffc000000>;
}
impl uT of AddHelper<BoundedInt<0, 0xfffffffffc000000>, BoundedInt<0, 67108863>> {
    type Result = Lane;
}
const M26: UnitInt<67108864> = 67108864;
impl vm of DivRemHelper<Lane, UnitInt<17179869184>> {
    type DivT = BoundedInt<0, 1073741823>;
    type RemT = BoundedInt<0, 17179869183>;
}
impl vI of MulHelper<BoundedInt<0, 17179869183>, UnitInt<1073741824>> {
    type Result = BoundedInt<0, 0xffffffffc0000000>;
}
impl uV of AddHelper<BoundedInt<0, 0xffffffffc0000000>, BoundedInt<0, 1073741823>> {
    type Result = Lane;
}
const M30: UnitInt<1073741824> = 1073741824;
impl vo of DivRemHelper<Lane, UnitInt<1073741824>> {
    type DivT = BoundedInt<0, 17179869183>;
    type RemT = BoundedInt<0, 1073741823>;
}
impl vK of MulHelper<BoundedInt<0, 1073741823>, UnitInt<17179869184>> {
    type Result = BoundedInt<0, 0xfffffffc00000000>;
}
impl uX of AddHelper<BoundedInt<0, 0xfffffffc00000000>, BoundedInt<0, 17179869183>> {
    type Result = Lane;
}
const M34: UnitInt<17179869184> = 17179869184;
impl vp of DivRemHelper<Lane, UnitInt<536870912>> {
    type DivT = BoundedInt<0, 34359738367>;
    type RemT = BoundedInt<0, 536870911>;
}
impl vL of MulHelper<BoundedInt<0, 536870911>, UnitInt<34359738368>> {
    type Result = BoundedInt<0, 0xfffffff800000000>;
}
impl uY of AddHelper<BoundedInt<0, 0xfffffff800000000>, BoundedInt<0, 34359738367>> {
    type Result = Lane;
}
const M35: UnitInt<34359738368> = 34359738368;
impl vq of DivRemHelper<Lane, UnitInt<67108864>> {
    type DivT = BoundedInt<0, 274877906943>;
    type RemT = BoundedInt<0, 67108863>;
}
impl vM of MulHelper<BoundedInt<0, 67108863>, UnitInt<274877906944>> {
    type Result = BoundedInt<0, 0xffffffc000000000>;
}
impl uZ of AddHelper<BoundedInt<0, 0xffffffc000000000>, BoundedInt<0, 274877906943>> {
    type Result = Lane;
}
const M38: UnitInt<274877906944> = 274877906944;
impl vr of DivRemHelper<Lane, UnitInt<16777216>> {
    type DivT = BoundedInt<0, 0xffffffffff>;
    type RemT = BoundedInt<0, 16777215>;
}
impl vN of MulHelper<BoundedInt<0, 16777215>, UnitInt<1099511627776>> {
    type Result = BoundedInt<0, 0xffffff0000000000>;
}
impl u5 of AddHelper<BoundedInt<0, 0xffffff0000000000>, BoundedInt<0, 0xffffffffff>> {
    type Result = Lane;
}
const M40: UnitInt<1099511627776> = 1099511627776;
impl vs of DivRemHelper<Lane, UnitInt<131072>> {
    type DivT = BoundedInt<0, 0x7fffffffffff>;
    type RemT = BoundedInt<0, 131071>;
}
impl vO of MulHelper<BoundedInt<0, 131071>, UnitInt<0x800000000000>> {
    type Result = BoundedInt<0, 0xffff800000000000>;
}
impl u6 of AddHelper<BoundedInt<0, 0xffff800000000000>, BoundedInt<0, 0x7fffffffffff>> {
    type Result = Lane;
}
const M47: UnitInt<0x800000000000> = 0x800000000000;
impl vt of DivRemHelper<Lane, UnitInt<65536>> {
    type DivT = BoundedInt<0, 0xffffffffffff>;
    type RemT = BoundedInt<0, 65535>;
}
impl vP of MulHelper<BoundedInt<0, 65535>, UnitInt<281474976710656>> {
    type Result = BoundedInt<0, 0xffff000000000000>;
}
impl u7 of AddHelper<BoundedInt<0, 0xffff000000000000>, BoundedInt<0, 0xffffffffffff>> {
    type Result = Lane;
}
const M48: UnitInt<281474976710656> = 281474976710656;
impl vz of DivRemHelper<Lane, UnitInt<32>> {
    type DivT = BoundedInt<0, 0x7ffffffffffffff>;
    type RemT = BoundedInt<0, 31>;
}
impl vU of MulHelper<BoundedInt<0, 31>, UnitInt<0x800000000000000>> {
    type Result = BoundedInt<0, 0xf800000000000000>;
}
impl vd of AddHelper<BoundedInt<0, 0xf800000000000000>, BoundedInt<0, 0x7ffffffffffffff>> {
    type Result = Lane;
}
const M59: UnitInt<0x800000000000000> = 0x800000000000000;
impl vg of DivRemHelper<Lane, UnitInt<281474976710656>> {
    type DivT = BoundedInt<0, 65535>;
    type RemT = BoundedInt<0, 0xffffffffffff>;
}
impl vC of MulHelper<BoundedInt<0, 0xffffffffffff>, UnitInt<65536>> {
    type Result = BoundedInt<0, 0xffffffffffff0000>;
}
impl uP of AddHelper<BoundedInt<0, 0xffffffffffff0000>, BoundedInt<0, 65535>> {
    type Result = Lane;
}
const M16: UnitInt<65536> = 65536;
impl vy of DivRemHelper<Lane, UnitInt<2048>> {
    type DivT = BoundedInt<0, 9007199254740991>;
    type RemT = BoundedInt<0, 2047>;
}
impl vT of MulHelper<BoundedInt<0, 2047>, UnitInt<9007199254740992>> {
    type Result = BoundedInt<0, 0xffe0000000000000>;
}
impl vc of AddHelper<BoundedInt<0, 0xffe0000000000000>, BoundedInt<0, 9007199254740991>> {
    type Result = Lane;
}
const M53: UnitInt<9007199254740992> = 9007199254740992;
type TwoPow65 = UnitInt<0x20000000000000000>;
type LaneCarry = BoundedInt<0, 0x1ffffffffffffffff>;
impl gS of DivRemHelper<u128, TwoPow65> {
    type DivT = BoundedInt<0, 0x7fffffffffffffff>;
    type RemT = LaneCarry;
}
impl LaneCarrySplit of ConstrainHelper<LaneCarry, 0x10000000000000000> {
    type LowT = Lane;
    type HighT = BoundedInt<0x10000000000000000, 0x1ffffffffffffffff>;
}
impl iJ of SubHelper<
    BoundedInt<0x10000000000000000, 0x1ffffffffffffffff>, UnitInt<0x10000000000000000>,
> {
    type Result = Lane;
}
impl iD of AddHelper<BoundedInt<0, 0x7fffffffffffffff>, UnitInt<0x8000000000000000>> {
    type Result = BoundedInt<0x8000000000000000, 0xffffffffffffffff>;
}
/// Splits a value one bit wider than a pair (below `2^65`), folding the low
/// half's carry bit into the high lane.
#[inline(always)]
fn split_pair_carry(w: u128, two65: NonZero<TwoPow65>) -> (Lane, Lane) {
    let (q, rem) = bounded_int::div_rem(w, two65);
    match constrain::<LaneCarry, 0x10000000000000000>(rem) {
        Ok(lo) => (lo, upcast(q)),
        Err(hi) => {
            let t: UnitInt<0x10000000000000000> = 0x10000000000000000;
            let p: UnitInt<0x8000000000000000> = 0x8000000000000000;
            (bounded_int::sub(hi, t), upcast(bounded_int::add(q, p)))
        },
    }
}
type Mask64 = UnitInt<0xffffffffffffffff>;
impl iI of SubHelper<Mask64, Lane> {
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
    let nb: u64 = upcast(bounded_int::sub(mask128, b));
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
    upcast(bounded_int::sub(mask128, x))
}
/// Splits a pair into `(high, low)` lanes.
#[inline(always)]
fn split_pair(w: u128, two64: NonZero<TwoPow64>) -> (Lane, Lane) {
    bounded_int::div_rem(w, two64)
}
impl gP of ConstrainHelper<Lane, 0x8000000000000000> {
    type LowT = BoundedInt<0, 0x7fffffffffffffff>;
    type HighT = BoundedInt<0x8000000000000000, 0xffffffffffffffff>;
}
impl jh of SubHelper<
    BoundedInt<0x10000000000000000, 0x1fffffffffffffffe>, UnitInt<0xffffffffffffffff>,
> {
    type Result = BoundedInt<1, 0xffffffffffffffff>;
}
#[inline(always)]
fn rot6(x: Lane, d: NonZero<UnitInt<0x400000000000000>>) -> Lane {
    let m: UnitInt<64> = 64;
    let (aH, rest) = bounded_int::div_rem(x, d);
    bounded_int::add(bounded_int::mul(rest, m), aH)
}
#[inline(always)]
fn rot8(x: Lane, d: NonZero<UnitInt<72057594037927936>>) -> Lane {
    let m: UnitInt<256> = 256;
    let (aH, rest) = bounded_int::div_rem(x, d);
    bounded_int::add(bounded_int::mul(rest, m), aH)
}
#[inline(always)]
fn rot20(x: Lane, d: NonZero<UnitInt<17592186044416>>) -> Lane {
    let m: UnitInt<1048576> = 1048576;
    let (aH, rest) = bounded_int::div_rem(x, d);
    bounded_int::add(bounded_int::mul(rest, m), aH)
}
#[inline(always)]
fn rot21(x: Lane, d: NonZero<UnitInt<8796093022208>>) -> Lane {
    let m: UnitInt<2097152> = 2097152;
    let (aH, rest) = bounded_int::div_rem(x, d);
    bounded_int::add(bounded_int::mul(rest, m), aH)
}
#[inline(always)]
fn rot25(x: Lane, d: NonZero<UnitInt<549755813888>>) -> Lane {
    let m: UnitInt<33554432> = 33554432;
    let (aH, rest) = bounded_int::div_rem(x, d);
    bounded_int::add(bounded_int::mul(rest, m), aH)
}
#[inline(always)]
fn rot28(x: Lane, d: NonZero<UnitInt<68719476736>>) -> Lane {
    let m: UnitInt<268435456> = 268435456;
    let (aH, rest) = bounded_int::div_rem(x, d);
    bounded_int::add(bounded_int::mul(rest, m), aH)
}
#[inline(always)]
fn rot39(x: Lane, d: NonZero<UnitInt<33554432>>) -> Lane {
    let m: UnitInt<549755813888> = 549755813888;
    let (aH, rest) = bounded_int::div_rem(x, d);
    bounded_int::add(bounded_int::mul(rest, m), aH)
}
#[inline(always)]
fn rot41(x: Lane, d: NonZero<UnitInt<8388608>>) -> Lane {
    let m: UnitInt<2199023255552> = 2199023255552;
    let (aH, rest) = bounded_int::div_rem(x, d);
    bounded_int::add(bounded_int::mul(rest, m), aH)
}
#[inline(always)]
fn rot43(x: Lane, d: NonZero<UnitInt<2097152>>) -> Lane {
    let m: UnitInt<8796093022208> = 8796093022208;
    let (aH, rest) = bounded_int::div_rem(x, d);
    bounded_int::add(bounded_int::mul(rest, m), aH)
}
#[inline(always)]
fn rot45(x: Lane, d: NonZero<UnitInt<524288>>) -> Lane {
    let m: UnitInt<35184372088832> = 35184372088832;
    let (aH, rest) = bounded_int::div_rem(x, d);
    bounded_int::add(bounded_int::mul(rest, m), aH)
}
#[inline(always)]
fn rot62(x: Lane, d: NonZero<UnitInt<4>>) -> Lane {
    let m: UnitInt<0x4000000000000000> = 0x4000000000000000;
    let (aH, rest) = bounded_int::div_rem(x, d);
    bounded_int::add(bounded_int::mul(rest, m), aH)
}
/// Bitwise NOT of a single lane: `(2^64 - 1) - x`.
#[inline(always)]
fn not64(x: Lane, mask128: Mask64) -> Lane {
    bounded_int::sub(mask128, x)
}
impl pO of MulHelper<BoundedInt<0, 0x7fffffffffffffff>, UnitInt<0x20000000000000000>> {
    type Result = BoundedInt<0, 0xfffffffffffffffe0000000000000000>;
}
impl pP of AddHelper<
    BoundedInt<0, 0xfffffffffffffffe0000000000000000>, BoundedInt<0, 0x7fffffffffffffff>,
> {
    type Result = BoundedInt<0, 0xfffffffffffffffe7fffffffffffffff>;
}
impl nH of AddHelper<
    BoundedInt<0x100000000000000000000000000000000, 0x1fffffffffffffffe0000000000000000>,
    BoundedInt<0x8000000000000000, 0xffffffffffffffff>,
> {
    type Result =
        BoundedInt<0x100000000000000008000000000000000, 0x1fffffffffffffffeffffffffffffffff>;
}
impl nI of SubHelper<
    BoundedInt<0x100000000000000008000000000000000, 0x1fffffffffffffffeffffffffffffffff>,
    UnitInt<0xffffffffffffffffffffffffffffffff>,
> {
    type Result = BoundedInt<0x8000000000000001, 0xffffffffffffffff0000000000000000>;
}
impl nJ of AddHelper<
    BoundedInt<0x8000000000000001, 0xffffffffffffffff0000000000000000>,
    BoundedInt<0x8000000000000000, 0xffffffffffffffff>,
> {
    type Result = BoundedInt<0x10000000000000001, 0xffffffffffffffffffffffffffffffff>;
}
impl pQ of AddHelper<
    BoundedInt<0, 0xfffffffffffffffe7fffffffffffffff>, BoundedInt<0, 0x7fffffffffffffff>,
> {
    type Result = BoundedInt<0, 0xfffffffffffffffefffffffffffffffe>;
}
impl pR of MulHelper<
    BoundedInt<0x8000000000000000, 0xffffffffffffffff>, UnitInt<0x20000000000000000>,
> {
    type Result =
        BoundedInt<0x100000000000000000000000000000000, 0x1fffffffffffffffe0000000000000000>;
}
impl pS of AddHelper<
    BoundedInt<0x100000000000000000000000000000000, 0x1fffffffffffffffe0000000000000000>,
    BoundedInt<0, 0x7fffffffffffffff>,
> {
    type Result =
        BoundedInt<0x100000000000000000000000000000000, 0x1fffffffffffffffe7fffffffffffffff>;
}
impl pT of SubHelper<
    BoundedInt<0x100000000000000000000000000000000, 0x1fffffffffffffffe7fffffffffffffff>,
    UnitInt<0xffffffffffffffff0000000000000000>,
> {
    type Result = BoundedInt<0x10000000000000000, 0xffffffffffffffff7fffffffffffffff>;
}
impl pU of AddHelper<
    BoundedInt<0x10000000000000000, 0xffffffffffffffff7fffffffffffffff>,
    BoundedInt<0, 0x7fffffffffffffff>,
> {
    type Result = BoundedInt<0x10000000000000000, 0xfffffffffffffffffffffffffffffffe>;
}
impl pV of AddHelper<
    BoundedInt<0, 0xfffffffffffffffe0000000000000000>,
    BoundedInt<0x8000000000000000, 0xffffffffffffffff>,
> {
    type Result = BoundedInt<0x8000000000000000, 0xfffffffffffffffeffffffffffffffff>;
}
impl pW of SubHelper<
    BoundedInt<0x8000000000000000, 0xfffffffffffffffeffffffffffffffff>, UnitInt<0xffffffffffffffff>,
> {
    type Result = BoundedInt<-0x7fffffffffffffff, 0xfffffffffffffffe0000000000000000>;
}
impl pX of AddHelper<
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
fn first_round_theta(u0: u128, parities: ColumnParities) -> (u128, Lane, Lane, Lane, u128) {
    first_round_theta_with(u0, parities, TWO_POW_64_NZ, MASK_64, MASK_128)
}

/// First-round theta core, explicit over the threaded constants.
#[inline(always)]
fn first_round_theta_with(
    u0: u128,
    parities: ColumnParities,
    two64: NonZero<TwoPow64>,
    m64: Mask64,
    mask128_full: Mask128,
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
    let (di, c3, c4, r0, p12) = first_round_theta(u0, parities);
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
    let (TWO_POW_63_UNIT, zm) = bounded_int::div_rem(e2 ^ jH, k.two65);
    let (r0, cq, cJ, cL) = rotl1_pair_split(c0, cq, TWO_POW_63_UNIT, zm, k.mask64);
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
    let pn = pair(b15, b17);
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
            pg ^ (jM | jN) ^ rc, pi ^ (jO | jP), pl ^ (jQ | jR), pn ^ (jS | jT), pp ^ (jU | jV),
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

type QR4 = BoundedInt<0, 0xfffffffffffffff>;
type QT4 = BoundedInt<0, 0xf>;
type QP4 = BoundedInt<0, 0xfffffffffffffff0>;
impl QDR4 of DivRemHelper<Lane, UnitInt<0x1000000000000000>> {
    type DivT = QT4;
    type RemT = QR4;
}
impl QMR4 of MulHelper<QR4, UnitInt<16>> {
    type Result = QP4;
}
impl QAR4 of AddHelper<QP4, QT4> {
    type Result = Lane;
}
const M4: UnitInt<16> = 16;
type QR13 = BoundedInt<0, 0x7ffffffffffff>;
type QT13 = BoundedInt<0, 0x1fff>;
type QP13 = BoundedInt<0, 0xffffffffffffe000>;
impl QDR13 of DivRemHelper<Lane, UnitInt<0x8000000000000>> {
    type DivT = QT13;
    type RemT = QR13;
}
impl QMR13 of MulHelper<QR13, UnitInt<8192>> {
    type Result = QP13;
}
impl QAR13 of AddHelper<QP13, QT13> {
    type Result = Lane;
}
const M13: UnitInt<8192> = 8192;
type QR19 = BoundedInt<0, 0x1fffffffffff>;
type QT19 = BoundedInt<0, 0x7ffff>;
type QP19 = BoundedInt<0, 0xfffffffffff80000>;
impl QDR19 of DivRemHelper<Lane, UnitInt<0x200000000000>> {
    type DivT = QT19;
    type RemT = QR19;
}
impl QMR19 of MulHelper<QR19, UnitInt<524288>> {
    type Result = QP19;
}
impl QAR19 of AddHelper<QP19, QT19> {
    type Result = Lane;
}
const M19: UnitInt<524288> = 524288;
type QR37 = BoundedInt<0, 0x7ffffff>;
type QT37 = BoundedInt<0, 0x1fffffffff>;
type QP37 = BoundedInt<0, 0xffffffe000000000>;
impl QDR37 of DivRemHelper<Lane, UnitInt<0x8000000>> {
    type DivT = QT37;
    type RemT = QR37;
}
impl QMR37 of MulHelper<QR37, UnitInt<137438953472>> {
    type Result = QP37;
}
impl QAR37 of AddHelper<QP37, QT37> {
    type Result = Lane;
}
const M37: UnitInt<137438953472> = 137438953472;
type QR42 = BoundedInt<0, 0x3fffff>;
type QT42 = BoundedInt<0, 0x3ffffffffff>;
type QP42 = BoundedInt<0, 0xfffffc0000000000>;
impl QDR42 of DivRemHelper<Lane, UnitInt<0x400000>> {
    type DivT = QT42;
    type RemT = QR42;
}
impl QMR42 of MulHelper<QR42, UnitInt<4398046511104>> {
    type Result = QP42;
}
impl QAR42 of AddHelper<QP42, QT42> {
    type Result = Lane;
}
const M42: UnitInt<4398046511104> = 4398046511104;
type QR54 = BoundedInt<0, 0x3ff>;
type QT54 = BoundedInt<0, 0x3fffffffffffff>;
type QP54 = BoundedInt<0, 0xffc0000000000000>;
impl QDR54 of DivRemHelper<Lane, UnitInt<0x400>> {
    type DivT = QT54;
    type RemT = QR54;
}
impl QMR54 of MulHelper<QR54, UnitInt<18014398509481984>> {
    type Result = QP54;
}
impl QAR54 of AddHelper<QP54, QT54> {
    type Result = Lane;
}
const M54: UnitInt<18014398509481984> = 18014398509481984;
type QR60 = BoundedInt<0, 0xf>;
type QT60 = BoundedInt<0, 0xfffffffffffffff>;
type QP60 = BoundedInt<0, 0xf000000000000000>;
impl QDR60 of DivRemHelper<Lane, UnitInt<0x10>> {
    type DivT = QT60;
    type RemT = QR60;
}
impl QMR60 of MulHelper<QR60, UnitInt<1152921504606846976>> {
    type Result = QP60;
}
impl QAR60 of AddHelper<QP60, QT60> {
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
    let (cq, crem) = bounded_int::div_rem(o0 ^ n31, k.two65);
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
    let (TWO_POW_63_UNIT, zm) = bounded_int::div_rem(e2 ^ ee, k.two65);
    let (r0, cq, cJ, cL) = rotl1_pair_split(c0, cq, TWO_POW_63_UNIT, zm, k.mask64);
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
impl QA1 of AddHelper<LaneLow, LaneLow> {
    type Result = LaneEven;
}
impl QA2 of AddHelper<LaneHigh, LaneHigh> {
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
    upcast(bounded_int::add(bounded_int::add(bounded_int::mul(b, bo), a), a))
}
#[inline(always)]
fn rotl1_pair_ll(a: LaneLow, b: LaneLow, bo: TwoPow65) -> u128 {
    let k: UnitInt<0> = 0;
    upcast(bounded_int::add(bounded_int::sub(bounded_int::add(bounded_int::mul(b, bo), a), k), a))
}
impl Z0S of SubHelper<BoundedInt<0, 0xfffffffffffffffe7fffffffffffffff>, UnitInt<0>> {
    type Result = BoundedInt<0, 0xfffffffffffffffe7fffffffffffffff>;
}
#[inline(always)]
fn rotl1_pair_lh(a: LaneLow, b: LaneHigh, bo: TwoPow65) -> u128 {
    let k: UnitInt<0xffffffffffffffff0000000000000000> = 0xffffffffffffffff0000000000000000;
    upcast(bounded_int::add(bounded_int::sub(bounded_int::add(bounded_int::mul(b, bo), a), k), a))
}
#[inline(always)]
fn rotl1_pair_hl(a: LaneHigh, b: LaneLow, bo: TwoPow65, m64: Mask64) -> u128 {
    upcast(bounded_int::add(bounded_int::sub(bounded_int::add(bounded_int::mul(b, bo), a), m64), a))
}
#[inline(always)]
fn rotl1_pair_hh(a: LaneHigh, b: LaneHigh, bo: TwoPow65, mask128_full: Mask128) -> u128 {
    upcast(
        bounded_int::add(
            bounded_int::sub(bounded_int::add(bounded_int::mul(b, bo), a), mask128_full), a,
        ),
    )
}
#[inline(always)]
fn rotl1_plain(x: LaneLow) -> Lane {
    upcast(bounded_int::add(x, x))
}
#[inline(always)]
fn rotl1_low(x: LaneLow) -> Lane {
    let k: UnitInt<0> = 0;
    upcast(bounded_int::sub(bounded_int::add(x, x), k))
}
impl ZR0S of SubHelper<LaneEven, UnitInt<0>> {
    type Result = LaneEven;
}
#[inline(always)]
fn rotl1_high(x: LaneHigh, m64: Mask64) -> Lane {
    upcast(bounded_int::sub(bounded_int::add(x, x), m64))
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
                    let (o3, o1) = (
                        bounded_int::sub(lo, TWO_POW_64_UNIT),
                        upcast(bounded_int::add(cq, TWO_POW_63_UNIT)),
                    );
                    (rotl1_low(ya), rotl1_low(yb), o3, o1)
                },
            },
            Err(yb) => match constrain::<LaneCarry, 0x10000000000000000>(crem) {
                Ok(lo) => {
                    let (o3, o1) = (lo, upcast(cq));
                    (rotl1_low(ya), rotl1_high(yb, m64), o3, o1)
                },
                Err(lo) => {
                    let (o3, o1) = (
                        bounded_int::sub(lo, TWO_POW_64_UNIT),
                        upcast(bounded_int::add(cq, TWO_POW_63_UNIT)),
                    );
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
                    let (o3, o1) = (
                        bounded_int::sub(lo, TWO_POW_64_UNIT),
                        upcast(bounded_int::add(cq, TWO_POW_63_UNIT)),
                    );
                    (rotl1_high(ya, m64), rotl1_low(yb), o3, o1)
                },
            },
            Err(yb) => match constrain::<LaneCarry, 0x10000000000000000>(crem) {
                Ok(lo) => {
                    let (o3, o1) = (lo, upcast(cq));
                    (rotl1_high(ya, m64), rotl1_high(yb, m64), o3, o1)
                },
                Err(lo) => {
                    let (o3, o1) = (
                        bounded_int::sub(lo, TWO_POW_64_UNIT),
                        upcast(bounded_int::add(cq, TWO_POW_63_UNIT)),
                    );
                    (rotl1_high(ya, m64), rotl1_high(yb, m64), o3, o1)
                },
            },
        },
    }
}
