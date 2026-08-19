// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.1 (account/src/falcon_512/packing.cairo)

//! Base-`Q` packing of 512 `Z_q` coefficients into 29 `felt252` slots.
//!
//! Each full slot carries two `u128` halves; each half Horner-packs 9 coefficients in base
//! `Q = 12289` (`Q^9 < 2^128`): `half = c0 + Q*(c1 + Q*(c2 + ...))`. 28 full slots
//! hold 18 coefficients each; the last slot holds the remaining 8 in its low half.
//!
//! Unpacking accepts exactly canonical encodings: each full half is downcast to `[0, Q^9)`, the
//! final low half to `[0, Q^8)`, and the final high half must be zero. The accepted felt vectors
//! are therefore in bijection with coefficient vectors in `[0, Q)^512`.

use openzeppelin_corelib_imports::bounded_int::{
    BoundedInt, DivRemHelper, UnitInt, bounded_int_div_rem, downcast, upcast,
};
#[cfg(test)]
use super::zq::Q;

/// Coefficients per full `felt252` slot (two `u128` halves of 9).
#[cfg(test)]
pub const VALS_PER_FELT: u32 = 18;
/// `felt252` slots for 512 coefficients: 28 full slots + 1 slot with 8.
pub const PACKED_SLOTS: u32 = 29;
/// Coefficients in the last slot: 512 - 28*18.
#[cfg(test)]
const LAST_SLOT_VALS: u32 = 8;

#[cfg(test)]
const TWO_POW_128: felt252 = 0x100000000000000000000000000000000;

type PackingZq = BoundedInt<0, 12288>;
type PackingQ = UnitInt<12289>;
type Acc1 = BoundedInt<0, 151019520>;
type Acc2 = BoundedInt<0, 1855878893568>;
type Acc3 = BoundedInt<0, 22806895723069440>;
type Acc4 = BoundedInt<0, 280273941540800360448>;
type Acc5 = BoundedInt<0, 3444286467594895629557760>;
type Acc6 = BoundedInt<0, 42326836400273672391635324928>;
type Acc7 = BoundedInt<0, 520154492522963160020806508052480>;
type Acc8 = BoundedInt<0, 6392178558614694273495691177456939008>;

const PACKING_Q_NZ: NonZero<PackingQ> = 12289;

impl PackingDivRemAcc1Impl of DivRemHelper<Acc1, PackingQ> {
    type DivT = PackingZq;
    type RemT = PackingZq;
}

impl PackingDivRemAcc2Impl of DivRemHelper<Acc2, PackingQ> {
    type DivT = Acc1;
    type RemT = PackingZq;
}

impl PackingDivRemAcc3Impl of DivRemHelper<Acc3, PackingQ> {
    type DivT = Acc2;
    type RemT = PackingZq;
}

impl PackingDivRemAcc4Impl of DivRemHelper<Acc4, PackingQ> {
    type DivT = Acc3;
    type RemT = PackingZq;
}

impl PackingDivRemAcc5Impl of DivRemHelper<Acc5, PackingQ> {
    type DivT = Acc4;
    type RemT = PackingZq;
}

impl PackingDivRemAcc6Impl of DivRemHelper<Acc6, PackingQ> {
    type DivT = Acc5;
    type RemT = PackingZq;
}

impl PackingDivRemAcc7Impl of DivRemHelper<Acc7, PackingQ> {
    type DivT = Acc6;
    type RemT = PackingZq;
}

impl PackingDivRemAcc8Impl of DivRemHelper<Acc8, PackingQ> {
    type DivT = Acc7;
    type RemT = PackingZq;
}

/// Unpacks 29 packed felts into 512 coefficients in `[0, Q)`, as felts (each is a
/// base-Q digit, so the range holds by construction).
/// Returns `None` on wrong length or any non-canonical slot encoding.
#[cfg(test)]
pub fn unpack_512(packed: Span<felt252>) -> Option<Array<felt252>> {
    let coeffs_u16 = match unpack_512_u16(packed) {
        Some(v) => v,
        None => { return None; },
    };
    let mut coeffs_u16 = coeffs_u16.span();
    let mut coeffs: Array<felt252> = array![];
    while let Some(coeff) = coeffs_u16.pop_front() {
        coeffs.append((*coeff).into());
    }
    Some(coeffs)
}

/// Unpacks the canonical 29-slot encoding directly into the verifier's `u16` form.
/// Returns `None` on wrong length or any non-canonical slot encoding.
pub(crate) fn unpack_512_u16(packed: Span<felt252>) -> Option<Array<u16>> {
    if packed.len() != PACKED_SLOTS {
        return None;
    }
    let mut coeffs: Array<u16> = array![];
    let mut full_slots = packed.slice(0, PACKED_SLOTS - 1);
    while let Some(chunk) = full_slots.multi_pop_front::<7>() {
        let [f0, f1, f2, f3, f4, f5, f6] = (*chunk).unbox();
        if !unpack_full_slot_u16(f0, ref coeffs)
            || !unpack_full_slot_u16(f1, ref coeffs)
            || !unpack_full_slot_u16(f2, ref coeffs)
            || !unpack_full_slot_u16(f3, ref coeffs)
            || !unpack_full_slot_u16(f4, ref coeffs)
            || !unpack_full_slot_u16(f5, ref coeffs)
            || !unpack_full_slot_u16(f6, ref coeffs) {
            return None;
        }
    }
    let last: u256 = (*packed.at(PACKED_SLOTS - 1)).into();
    if last.high != 0 || !unpack_half8_u16(last.low, ref coeffs) {
        return None;
    }
    Some(coeffs)
}

#[inline(always)]
fn unpack_full_slot_u16(felt: felt252, ref coeffs: Array<u16>) -> bool {
    let value: u256 = felt.into();
    unpack_half9_u16(value.low, ref coeffs) && unpack_half9_u16(value.high, ref coeffs)
}

/// Extracts nine base-Q digits from a `u128` half. Values below `Q^9` are canonical;
/// after eight divisions the remaining quotient is the ninth digit.
#[inline(always)]
fn unpack_half9_u16(value: u128, ref coeffs: Array<u16>) -> bool {
    let value: Acc8 = match downcast(value) {
        Some(v) => v,
        None => { return false; },
    };
    let (rest, d0) = bounded_int_div_rem(value, PACKING_Q_NZ);
    let (rest, d1) = bounded_int_div_rem(rest, PACKING_Q_NZ);
    let (rest, d2) = bounded_int_div_rem(rest, PACKING_Q_NZ);
    let (rest, d3) = bounded_int_div_rem(rest, PACKING_Q_NZ);
    let (rest, d4) = bounded_int_div_rem(rest, PACKING_Q_NZ);
    let (rest, d5) = bounded_int_div_rem(rest, PACKING_Q_NZ);
    let (rest, d6) = bounded_int_div_rem(rest, PACKING_Q_NZ);
    let (rest, d7) = bounded_int_div_rem(rest, PACKING_Q_NZ);
    coeffs.append(upcast(d0));
    coeffs.append(upcast(d1));
    coeffs.append(upcast(d2));
    coeffs.append(upcast(d3));
    coeffs.append(upcast(d4));
    coeffs.append(upcast(d5));
    coeffs.append(upcast(d6));
    coeffs.append(upcast(d7));
    coeffs.append(upcast(rest));
    true
}

/// Extracts the final slot's eight digits after checking the value is below `Q^8`.
#[inline(always)]
fn unpack_half8_u16(value: u128, ref coeffs: Array<u16>) -> bool {
    let value: Acc7 = match downcast(value) {
        Some(v) => v,
        None => { return false; },
    };
    let (rest, d0) = bounded_int_div_rem(value, PACKING_Q_NZ);
    let (rest, d1) = bounded_int_div_rem(rest, PACKING_Q_NZ);
    let (rest, d2) = bounded_int_div_rem(rest, PACKING_Q_NZ);
    let (rest, d3) = bounded_int_div_rem(rest, PACKING_Q_NZ);
    let (rest, d4) = bounded_int_div_rem(rest, PACKING_Q_NZ);
    let (rest, d5) = bounded_int_div_rem(rest, PACKING_Q_NZ);
    let (rest, d6) = bounded_int_div_rem(rest, PACKING_Q_NZ);
    coeffs.append(upcast(d0));
    coeffs.append(upcast(d1));
    coeffs.append(upcast(d2));
    coeffs.append(upcast(d3));
    coeffs.append(upcast(d4));
    coeffs.append(upcast(d5));
    coeffs.append(upcast(d6));
    coeffs.append(upcast(rest));
    true
}

/// Packs 512 coefficients into 29 felts. Inverse of [`unpack_512`]; used by tests.
/// Panics unless `coeffs` contains exactly 512 coefficients in `[0, Q)`.
#[cfg(test)]
pub fn pack_512(coeffs: Span<u16>) -> Array<felt252> {
    assert(coeffs.len() == 512, 'pack: need 512 coeffs');
    let mut packed: Array<felt252> = array![];
    let mut slot: u32 = 0;
    while slot != PACKED_SLOTS - 1 {
        let low = pack_half(coeffs.slice(slot * VALS_PER_FELT, 9));
        let high = pack_half(coeffs.slice(slot * VALS_PER_FELT + 9, 9));
        packed.append(low.into() + high.into() * TWO_POW_128);
        slot += 1;
    }
    packed.append(pack_half(coeffs.slice(504, LAST_SLOT_VALS)).into());
    packed
}

/// Horner-encodes up to 9 coefficients into a `u128`: c0 + Q*(c1 + Q*(c2 + ...)).
#[cfg(test)]
fn pack_half(coeffs: Span<u16>) -> u128 {
    let mut acc: u128 = 0;
    let mut i = coeffs.len();
    while i != 0 {
        i -= 1;
        let c = *coeffs.at(i);
        assert(c < Q, 'pack: coeff >= Q');
        acc = acc * Q.into() + c.into();
    }
    acc
}

#[cfg(test)]
mod tests {
    use super::{PACKED_SLOTS, pack_512, unpack_512, unpack_512_u16};

    /// Q^9: the smallest non-canonical low-half value (all 9 digits zero, residue 1).
    const Q_POW_9: felt252 = 6392178558614694273495691177456939009;
    /// Q^8: the smallest non-canonical last-slot value.
    const Q_POW_8: felt252 = 520154492522963160020806508052481;
    const TWO_POW_128: felt252 = 0x100000000000000000000000000000000;

    fn pseudorandom_coeffs() -> Array<u16> {
        let mut f: Array<u16> = array![];
        let mut state: u64 = 7;
        for _ in 0_u32..512 {
            state = (state * 1664525 + 1013904223) % 0x100000000;
            f.append((state % 12289).try_into().unwrap());
        }
        f
    }

    fn as_felts(mut vals: Span<u16>) -> Array<felt252> {
        let mut out: Array<felt252> = array![];
        while let Some(v) = vals.pop_front() {
            out.append((*v).into());
        }
        out
    }

    #[test]
    fn test_pack_unpack_roundtrip() {
        let coeffs = pseudorandom_coeffs();
        let packed = pack_512(coeffs.span());
        assert_eq!(packed.len(), PACKED_SLOTS);
        let unpacked = unpack_512(packed.span()).unwrap();
        assert_eq!(unpacked.span(), as_felts(coeffs.span()).span());
        assert_eq!(unpack_512_u16(packed.span()).unwrap().span(), coeffs.span());
    }

    #[test]
    fn test_unpack_all_zero_and_max() {
        let mut zeros: Array<u16> = array![];
        let mut maxed: Array<u16> = array![];
        for _ in 0_u32..512 {
            zeros.append(0);
            maxed.append(12288);
        }
        let z = unpack_512(pack_512(zeros.span()).span()).unwrap();
        assert_eq!(z.span(), as_felts(zeros.span()).span());
        let m = unpack_512(pack_512(maxed.span()).span()).unwrap();
        assert_eq!(m.span(), as_felts(maxed.span()).span());
    }

    #[test]
    fn test_unpack_rejects_wrong_length() {
        let coeffs = pseudorandom_coeffs();
        let packed = pack_512(coeffs.span());
        assert!(unpack_512(packed.span().slice(0, 28)).is_none());
        assert!(unpack_512(array![].span()).is_none());
        let mut too_long = packed;
        too_long.append(0);
        assert!(unpack_512(too_long.span()).is_none());
    }

    #[test]
    fn test_unpack_rejects_noncanonical_slot_in_each_unrolled_position() {
        let packed = pack_512(pseudorandom_coeffs().span());
        let mut bad_index = 0;
        while bad_index != 7 {
            let mut tampered: Array<felt252> = array![];
            let mut index = 0;
            while index != packed.len() {
                if index == bad_index {
                    tampered.append(Q_POW_9);
                } else {
                    tampered.append(*packed.at(index));
                }
                index += 1;
            }
            assert!(unpack_512(tampered.span()).is_none());
            bad_index += 1;
        }
    }

    #[test]
    fn test_unpack_rejects_noncanonical_half() {
        // Q^9 in a low half: nine zero digits with a nonzero residue.
        let mut packed = pack_512(pseudorandom_coeffs().span());
        let mut tampered: Array<felt252> = array![Q_POW_9];
        let mut rest = packed.span().slice(1, 28);
        while let Some(f) = rest.pop_front() {
            tampered.append(*f);
        }
        assert!(unpack_512(tampered.span()).is_none());
        // Same overflow in a high half.
        let mut tampered2: Array<felt252> = array![Q_POW_9 * TWO_POW_128];
        let mut rest2 = packed.span().slice(1, 28);
        while let Some(f) = rest2.pop_front() {
            tampered2.append(*f);
        }
        assert!(unpack_512(tampered2.span()).is_none());
    }

    #[test]
    fn test_unpack_rejects_noncanonical_last_slot() {
        let packed = pack_512(pseudorandom_coeffs().span());
        // Non-zero high half in the last slot.
        let mut tampered: Array<felt252> = array![];
        let mut head = packed.span().slice(0, 28);
        while let Some(f) = head.pop_front() {
            tampered.append(*f);
        }
        tampered.append(TWO_POW_128);
        assert!(unpack_512(tampered.span()).is_none());
        // Q^8 in the last slot: eight zero digits with a nonzero residue.
        let mut tampered2: Array<felt252> = array![];
        let mut head2 = packed.span().slice(0, 28);
        while let Some(f) = head2.pop_front() {
            tampered2.append(*f);
        }
        tampered2.append(Q_POW_8);
        assert!(unpack_512(tampered2.span()).is_none());
    }
}
