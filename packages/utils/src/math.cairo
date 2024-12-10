// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.20.0-rc.0 (utils/math.cairo)

use core::integer::u512_safe_div_rem_by_u256;
use core::num::traits::WideMul;
use core::traits::{Into, BitAnd, BitXor};

/// Returns the average of two numbers. The result is rounded down.
pub fn average<
    T,
    impl TDrop: Drop<T>,
    impl TCopy: Copy<T>,
    impl TAdd: Add<T>,
    impl TDiv: Div<T>,
    impl TBitAnd: BitAnd<T>,
    impl TBitXor: BitXor<T>,
    impl TInto: Into<u8, T>
>(
    a: T, b: T
) -> T {
    // (a + b) / 2 can overflow.
    (a & b) + (a ^ b) / 2_u8.into()
}

/// TMP. Raises `base` to the power of `exp`. Will panic if the result is greater than 2 ** 256 - 1.
///
/// NOTE: This should be removed in favor of the corelib's Pow implementation when available.
/// https://github.com/starkware-libs/cairo/pull/6694
pub fn power<T, +Drop<T>, +PartialEq<T>, +TryInto<u256, T>, +Into<T, u256>, +Into<u8, T>>(
    base: T, exp: T
) -> T {
    assert!(base != 0_u8.into(), "Math: base cannot be zero");
    let base: u256 = base.into();
    let exp: u256 = exp.into();
    let mut result: u256 = 1;

    for _ in 0..exp {
        result *= base;
    };

    result.try_into().unwrap()
}

#[derive(Drop, Copy, Debug)]
pub enum Rounding {
    Floor, // Toward negative infinity
    Ceil, // Toward positive infinity
    Trunc, // Toward zero
    Expand // Away from zero
}

/// Returns the quotient of x * y / denominator and rounds up or down depending on `rounding`.
/// Uses `u512_safe_div_rem_by_u256` for precision.
///
/// Requirements:
///
/// - `denominator` cannot be zero.
/// - The quotient cannot be greater than u256.
pub fn u256_mul_div(x: u256, y: u256, denominator: u256, rounding: Rounding) -> u256 {
    let (q, r) = _raw_u256_mul_div(x, y, denominator);

    let is_rounded_up = match rounding {
        Rounding::Ceil => 1,
        Rounding::Expand => 1,
        Rounding::Trunc => 0,
        Rounding::Expand => 0
    };

    let has_remainder = if r > 0 { 1 } else { 0 };

    q + (is_rounded_up & has_remainder)
}

fn _raw_u256_mul_div(x: u256, y: u256, denominator: u256) -> (u256, u256) {
    let denominator = denominator.try_into().expect('mul_div division by zero');
    let p = x.wide_mul(y);
    let (mut q, r) = u512_safe_div_rem_by_u256(p, denominator);
    let q = q.try_into().expect('mul_div quotient > u256');
    (q, r)
}
