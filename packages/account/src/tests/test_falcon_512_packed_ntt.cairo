// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.1 (account/src/tests/test_falcon_512_packed_ntt.cairo)

use openzeppelin_corelib_imports::bounded_int::{downcast, upcast};
use crate::falcon_512::ntt::falcon512_fast::ntt_falcon512_fast_u16_unchecked;
use crate::falcon_512::ntt::falcon512_packed::{
    EXTREME_HIGH, EXTREME_LOW, ntt_falcon512_packed, product_remainder,
};
use crate::falcon_512::packing::{PackingZq, pack_512, unpack_512_u16, unpack_512_zq};

fn constant(value: u16) -> Array<u16> {
    let mut out = array![];
    while out.len() < 512 {
        out.append(value);
    }
    out
}
fn canonical(values: Span<u16>) -> Array<PackingZq> {
    let mut out = array![];
    for value in values {
        out.append(downcast(*value).unwrap());
    }
    out
}
fn pseudo(seed: u64) -> Array<u16> {
    let mut out = array![];
    let mut state = seed;
    while out.len() < 512 {
        state = (state * 1664525 + 1013904223) % 0x100000000;
        out.append((state % 12289).try_into().unwrap());
    }
    out
}
fn basis(index: u32, value: u16) -> Array<u16> {
    let mut out = array![];
    while out.len() < 512 {
        out.append(if out.len() == index {
            value
        } else {
            0
        });
    }
    out
}
fn assert_pair(a: Span<u16>, b: Span<u16>) {
    let ca = canonical(a);
    let cb = canonical(b);
    let packed = ntt_falcon512_packed(ca.span(), cb.span());
    let ea = ntt_falcon512_fast_u16_unchecked(a);
    let eb = ntt_falcon512_fast_u16_unchecked(b);
    let mut i = 0;
    for value in packed.span() {
        // Independent u256 split also checks the generated split/remainder implementation.
        let encoded: felt252 = upcast(*value);
        let wide: u256 = encoded.into();
        let radix: u256 = 10633823966279326983230456482242756608;
        let lo = wide % radix;
        let hi = wide / radix;
        let lo: u128 = lo.try_into().unwrap();
        let hi: u128 = hi.try_into().unwrap();
        let a: u128 = (*ea.at(i)).into();
        let b: u128 = (*eb.at(i)).into();
        assert_eq!(lo % 12289, a);
        assert_eq!(hi % 12289, b);
        let key: u16 = match i % 4 {
            0 => 0,
            1 => 1,
            2 => 12288,
            _ => 65535,
        };
        let key128: u128 = key.into();
        let expected: felt252 = ((a * key128 + 12289 - b) % 12289).into();
        assert_eq!(product_remainder(*value, key), expected);
        i += 1;
    }
}
#[test]
fn test_pairs_boundaries_random() {
    assert_pair(constant(0).span(), constant(0).span());
    assert_pair(constant(0).span(), constant(12288).span());
    assert_pair(constant(12288).span(), constant(0).span());
    assert_pair(constant(12288).span(), constant(12288).span());
    assert_pair(pseudo(7).span(), pseudo(19).span());
    assert_pair(pseudo(12289).span(), pseudo(512).span());
}
#[test]
fn test_pairs_every_basis_vector() {
    let mut i = 0;
    while i < 512 {
        assert_pair(basis(i, 1).span(), basis((i * 7) % 512, 12288).span());
        i += 1;
    }
}

#[test]
fn test_packed_ntt_at_output_interval_extrema() {
    assert_pair(EXTREME_HIGH.span(), EXTREME_LOW.span());
    assert_pair(EXTREME_LOW.span(), EXTREME_HIGH.span());
}

#[test]
#[should_panic(expected: 'packed NTT: bad length')]
fn test_packed_ntt_rejects_short_first_input() {
    let values = canonical(constant(0).span());
    ntt_falcon512_packed(values.span().slice(0, 511), values.span());
}

#[test]
#[should_panic(expected: 'packed NTT: bad length')]
fn test_packed_ntt_rejects_long_second_input() {
    let values = canonical(constant(0).span());
    let mut long = canonical(constant(0).span());
    long.append(0);
    ntt_falcon512_packed(values.span(), long.span());
}
fn replaced(values: Span<felt252>, index: u32, value: felt252) -> Array<felt252> {
    let mut out = array![];
    let mut i = 0;
    for original in values {
        out.append(if i == index {
            value
        } else {
            *original
        });
        i += 1;
    }
    out
}
#[test]
fn test_decoder_preserves_values() {
    for values in array![constant(0), constant(12288), pseudo(7), pseudo(19)] {
        let encoded = pack_512(values.span());
        let a = unpack_512_zq(encoded.span()).unwrap();
        let b = unpack_512_u16(encoded.span()).unwrap();
        let mut i = 0;
        for value in a.span() {
            let x: u16 = upcast(*value);
            assert_eq!(x, *b.at(i));
            i += 1;
        }
        assert_eq!(i, 512);
    }
}
#[test]
fn test_decoder_rejects_every_noncanonical_limb() {
    let encoded = pack_512(constant(0).span());
    let q9: felt252 = 6392178558614694273495691177456939009;
    let q8: felt252 = 520154492522963160020806508052481;
    let r128: felt252 = 0x100000000000000000000000000000000;
    let mut i = 0;
    while i < 28 {
        assert!(unpack_512_zq(replaced(encoded.span(), i, q9).span()).is_none());
        assert!(unpack_512_zq(replaced(encoded.span(), i, q9 * r128).span()).is_none());
        i += 1;
    }
    assert!(unpack_512_zq(replaced(encoded.span(), 28, q8).span()).is_none());
    assert!(unpack_512_zq(replaced(encoded.span(), 28, r128).span()).is_none());
    assert!(unpack_512_zq(encoded.span().slice(0, 28)).is_none());
    let mut long = encoded;
    long.append(0);
    assert!(unpack_512_zq(long.span()).is_none());
}

