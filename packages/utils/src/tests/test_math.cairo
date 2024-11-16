use crate::math::average;
use core::num::traits::Bounded;

#[test]
fn test_average_u8(a: u8, b: u8) {
    let actual = average(a, b);

    let a: u256 = a.into();
    let b: u256 = b.into();
    let expected = (a + b) / 2;

    assert_eq!(actual, expected.try_into().unwrap());
}

#[test]
fn test_average_u16(a: u16, b: u16) {
    let actual = average(a, b);

    let a: u256 = a.into();
    let b: u256 = b.into();
    let expected = (a + b) / 2;

    assert_eq!(actual, expected.try_into().unwrap());
}

#[test]
fn test_average_u32(a: u32, b: u32) {
    let actual = average(a, b);

    let a: u256 = a.into();
    let b: u256 = b.into();
    let expected = (a + b) / 2;

    assert_eq!(actual, expected.try_into().unwrap());
}

#[test]
fn test_average_u64(a: u64, b: u64) {
    let actual = average(a, b);

    let a: u256 = a.into();
    let b: u256 = b.into();
    let expected = (a + b) / 2;

    assert_eq!(actual, expected.try_into().unwrap());
}

#[test]
fn test_average_u128(a: u128, b: u128) {
    let actual = average(a, b);

    let a: u256 = a.into();
    let b: u256 = b.into();
    let expected = (a + b) / 2;

    assert_eq!(actual, expected.try_into().unwrap());
}

#[test]
fn test_average_u256_odd_numbers() {
    let a = 57417_u256;
    let b = 95431_u256;

    let actual = average(a, b);
    let expected = (a + b) / 2;

    assert_eq!(actual, expected);
}

#[test]
fn test_average_u256_even_numbers() {
    let a = 42304_u256;
    let b = 84346_u256;

    let actual = average(a, b);
    let expected = (a + b) / 2;

    assert_eq!(actual, expected);
}

#[test]
fn test_average_u256_one_even_one_odd() {
    let a = 57417_u256;
    let b = 84346_u256;

    let actual = average(a, b);
    let expected = (a + b) / 2;

    assert_eq!(actual, expected);
}

#[test]
fn test_average_u256_two_max_u256() {
    let a: u256 = Bounded::MAX;
    let b: u256 = Bounded::MAX;

    let actual = average(a, b);
    let expected = a;

    assert_eq!(actual, expected);
}
