// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.20.0 (utils/math.cairo)

use core::integer::u512_safe_div_rem_by_u256;
use core::num::traits::WideMul;
use core::traits::{BitAnd, BitXor, Into};

/// Returns the average of two numbers. The result is rounded down.
pub fn average<
    T,
    impl TDrop: Drop<T>,
    impl TCopy: Copy<T>,
    impl TAdd: Add<T>,
    impl TDiv: Div<T>,
    impl TBitAnd: BitAnd<T>,
    impl TBitXor: BitXor<T>,
    impl TInto: Into<u8, T>,
>(
    a: T, b: T,
) -> T {
    // (a + b) / 2 can overflow.
    (a & b) + (a ^ b) / 2_u8.into()
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
        Rounding::Floor => 0,
    };

    let has_remainder = if r > 0 {
        1
    } else {
        0
    };

    q + (is_rounded_up & has_remainder)
}

fn _raw_u256_mul_div(x: u256, y: u256, denominator: u256) -> (u256, u256) {
    let denominator = denominator.try_into().expect('mul_div division by zero');
    let p = x.wide_mul(y);
    let (mut q, r) = u512_safe_div_rem_by_u256(p, denominator);
    let q = q.try_into().expect('mul_div quotient > u256');
    (q, r)
}
