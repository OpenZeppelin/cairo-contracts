use crate::falcon_512::ntt::engine::{intt, ntt};
#[cfg(feature: 'falcon_fast_tests')]
use crate::falcon_512::ntt::falcon512::PRODUCT_BITS;
use crate::falcon_512::ntt::falcon512::{
    PRODUCT_BOUND_FELT, REDUCED_BITS, config, config_for_degree,
};
#[cfg(feature: 'falcon_fast_tests')]
use crate::falcon_512::ntt::falcon512_fast::{
    ntt_falcon512_fast_u16_unchecked, ntt_falcon512_fast_unchecked,
};
use crate::falcon_512::ntt::roots_felt::get_even_roots_felt;
use crate::falcon_512::ntt::roots_scaled::get_scaled_inv_roots;

fn as_felts(mut values: Span<u16>) -> Array<felt252> {
    let mut output = array![];
    while let Some(value) = values.pop_front() {
        output.append((*value).into());
    }
    output
}

fn zeros() -> Array<u16> {
    let mut values = array![];
    while values.len() != 512 {
        values.append(0);
    }
    values
}

fn max_values() -> Array<u16> {
    let mut values = array![];
    while values.len() != 512 {
        values.append(12288);
    }
    values
}

fn basis(index: u32) -> Array<u16> {
    let mut values = array![];
    let mut current = 0;
    while current != 512 {
        if current == index {
            values.append(1);
        } else {
            values.append(0);
        }
        current += 1;
    }
    values
}

fn pseudorandom_values(seed: u64) -> Array<u16> {
    let mut values = array![];
    let mut state = seed;
    while values.len() != 512 {
        state = (state * 1664525 + 1013904223) % 0x100000000;
        values.append((state % 12289).try_into().unwrap());
    }
    values
}

#[cfg(feature: 'falcon_fast_tests')]
fn assert_fast_matches_generic(values: Span<u16>) {
    let input = as_felts(values);
    let generic = ntt(input.span(), @config());
    let fast_u16 = ntt_falcon512_fast_u16_unchecked(values);
    let fast_felt = ntt_falcon512_fast_unchecked(input.span());
    assert_eq!(generic.span(), as_felts(fast_u16.span()).span());
    assert_eq!(generic.span(), fast_felt.span());
}

#[cfg(feature: 'falcon_fast_tests')]
#[test]
fn test_fast_ntt_matches_generic_reference_on_adversarial_inputs() {
    assert_fast_matches_generic(zeros().span());
    assert_fast_matches_generic(max_values().span());
    assert_fast_matches_generic(basis(0).span());
    assert_fast_matches_generic(basis(511).span());
    assert_fast_matches_generic(pseudorandom_values(7).span());
}

#[cfg(feature: 'falcon_fast_tests')]
#[test]
fn test_fast_ntt_inverse_roundtrip() {
    let values = pseudorandom_values(19);
    let transformed = ntt_falcon512_fast_u16_unchecked(values.span());
    let transformed = as_felts(transformed.span());
    let recovered = intt(transformed.span(), REDUCED_BITS, 12289, @config());
    assert_eq!(recovered.span(), as_felts(values.span()).span());
}

#[cfg(feature: 'falcon_fast_tests')]
#[test]
fn test_ntt_negacyclic_product() {
    let left = ntt_falcon512_fast_u16_unchecked(basis(1).span());
    let right = ntt_falcon512_fast_u16_unchecked(basis(511).span());
    let mut products = array![];
    let mut left = left.span();
    let mut right = right.span();
    while let Some(a) = left.pop_front() {
        let a: felt252 = (*a).into();
        let b: felt252 = (*right.pop_front().unwrap()).into();
        products.append(a * b);
    }

    let product = intt(products.span(), PRODUCT_BITS, PRODUCT_BOUND_FELT, @config());
    let mut expected = array![12288];
    while expected.len() != 512 {
        expected.append(0);
    }
    assert_eq!(product.span(), expected.span());
}

#[test]
#[should_panic(expected: 'intt: bad input length')]
fn test_intt_rejects_wrong_length() {
    intt(array![].span(), REDUCED_BITS, 12289, @config());
}

#[test]
#[should_panic(expected: 'intt: input too large')]
fn test_intt_rejects_excessive_input_bound() {
    let values = as_felts(zeros().span());
    intt(values.span(), 120, PRODUCT_BOUND_FELT, @config());
}

#[test]
fn test_degree_four_roundtrip_exercises_reduction_tail() {
    let values = array![1, 2, 3, 4];
    let cfg = config_for_degree(4, 2);
    let transformed = ntt(values.span(), @cfg);
    let recovered = intt(transformed.span(), REDUCED_BITS, 12289, @cfg);
    assert_eq!(recovered.span(), values.span());
}

#[test]
fn test_intt_reduces_before_last_level() {
    let values = array![0, 0, 0, 0];
    let recovered = intt(values.span(), 111, 1, @config_for_degree(4, 2));
    assert_eq!(recovered.span(), values.span());
}

#[test]
#[should_panic]
fn test_forward_roots_reject_unsupported_degree() {
    get_even_roots_felt(3);
}

#[test]
#[should_panic]
fn test_inverse_roots_reject_unsupported_degree() {
    get_scaled_inv_roots(3);
}
