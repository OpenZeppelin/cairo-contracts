use core::integer::{u512, u512_safe_div_rem_by_u256};
use core::num::traits::OverflowingAdd;
use crate::math::average;

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
fn test_average_u256(a: u256, b: u256) {
    let actual = average(a, b);
    let mut expected = 0;

    let (sum, overflow) = a.overflowing_add(b);
    if !overflow {
        expected = sum / 2;
    } else {
        let u512_sum = u512 { limb0: sum.low, limb1: sum.high, limb2: 1, limb3: 0 };
        let (res, _) = u512_safe_div_rem_by_u256(u512_sum, 2);
        expected = res.try_into().unwrap();
    }

    assert_eq!(actual, expected);
}
