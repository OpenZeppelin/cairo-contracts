use openzeppelin_corelib_imports::bounded_int::{downcast, upcast};
use crate::falcon_512::ntt::falcon512_fast::ntt_falcon512_fast_u16_unchecked;
use crate::falcon_512::ntt::falcon512_packed::{
    EXTREME_HIGH, EXTREME_LOW, ntt_falcon512_packed, product_remainder,
};
use crate::falcon_512::packing::PackingZq;

/// The packed transform's channel radix, `2^123`.
const TWO_POW_123: u256 = 10633823966279326983230456482242756608;

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
        let lo = wide % TWO_POW_123;
        let hi = wide / TWO_POW_123;
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
fn test_packed_ntt_pairs_boundaries_random() {
    assert_pair(constant(0).span(), constant(0).span());
    assert_pair(constant(0).span(), constant(12288).span());
    assert_pair(constant(12288).span(), constant(0).span());
    assert_pair(constant(12288).span(), constant(12288).span());
    assert_pair(pseudo(7).span(), pseudo(19).span());
    assert_pair(pseudo(12289).span(), pseudo(512).span());
}

#[test]
fn test_packed_ntt_every_basis_vector() {
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
