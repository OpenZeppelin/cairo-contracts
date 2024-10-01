// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.17.0 (utils/math.cairo)

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

#[derive(Drop, Copy, Debug)]
pub enum Rounding {
    Floor, // Toward negative infinity
    Ceil, // Toward positive infinity
    Trunc, // Toward zero
    Expand // Away from zero
}

fn cast_rounding(rounding: Rounding) -> u8 {
    match rounding {
        Rounding::Floor => 0,
        Rounding::Ceil => 1,
        Rounding::Trunc => 2,
        Rounding::Expand => 3
    }
}

fn round_up(rounding: Rounding) -> bool {
    let u8_rounding = cast_rounding(rounding);
    u8_rounding % 2 == 1
}

pub fn u256_mul_div(x: u256, y: u256, denominator: u256, rounding: Rounding) -> u256 {
    let (q, r) = _raw_u256_mul_div(x, y, denominator);

    // Prepare vars for bitwise op
    let felt_is_round_up: felt252 = round_up(rounding).into();
    let has_remainder: felt252 = (r > 0).into();

    q + BitAnd::bitand(felt_is_round_up.into(), has_remainder.into())
}

pub fn _raw_u256_mul_div(x: u256, y: u256, denominator: u256) -> (u256, u256) {
    assert(denominator != 0, 'Math: division by zero');
    let p = x.wide_mul(y);
    let (mut q, r) = u512_safe_div_rem_by_u256(p, denominator.try_into().unwrap());
    let q = q.try_into().expect('Math: quotient > u256');
    (q, r)
}

#[cfg(test)]
mod Test {
    use core::num::traits::Bounded;
    use super::Rounding;
    use super::u256_mul_div;

    #[test]
    #[should_panic(expected: 'Math: division by zero')]
    fn test_mul_div_divide_by_zero() {
        let x = 1;
        let y = 1;
        let denominator = 0;

        u256_mul_div(x, y, denominator, Rounding::Floor);
    }

    #[test]
    #[should_panic(expected: 'Math: quotient > u256')]
    fn test_mul_div_result_gt_u256() {
        let x = 5;
        let y = Bounded::MAX;
        let denominator = 2;

        u256_mul_div(x, y, denominator, Rounding::Floor);
    }

    #[test]
    fn test_mul_div_round_down_small_values() {
        let round_down = array![Rounding::Floor, Rounding::Trunc];
        let args_list = array![// (x, y, denominator, expected result)
        (3, 4, 5, 2), (3, 5, 5, 3)].span();

        for round in round_down {
            for args in args_list {
                let (x, y, denominator, expected) = args;
                assert_eq!(u256_mul_div(*x, *y, *denominator, round), *expected);
            }
        }
    }

    #[test]
    fn test_mul_div_round_down_large_values() {
        let round_down = array![Rounding::Floor, Rounding::Trunc];
        let u256_max: u256 = Bounded::MAX;
        let args_list = array![
            // (x, y, denominator, expected result)
            (42, u256_max - 1, u256_max, 41),
            (17, u256_max, u256_max, 17),
            (u256_max - 1, u256_max - 1, u256_max, u256_max - 2),
            (u256_max, u256_max - 1, u256_max, u256_max - 1),
            (u256_max, u256_max, u256_max, u256_max)
        ]
            .span();

        for round in round_down {
            for args in args_list {
                let (x, y, denominator, expected) = args;
                assert_eq!(u256_mul_div(*x, *y, *denominator, round), *expected);
            };
        };
    }

    #[test]
    fn test_mul_div_round_up_small_values() {
        let round_up = array![Rounding::Ceil, Rounding::Expand];
        let args_list = array![// (x, y, denominator, expected result)
        (3, 4, 5, 3), (3, 5, 5, 3)].span();

        for round in round_up {
            for args in args_list {
                let (x, y, denominator, expected) = args;
                assert_eq!(u256_mul_div(*x, *y, *denominator, round), *expected);
            }
        }
    }

    #[test]
    fn test_mul_div_round_up_large_values() {
        let round_up = array![Rounding::Ceil, Rounding::Expand];
        let u256_max: u256 = Bounded::MAX;
        let args_list = array![
            // (x, y, denominator, expected result)
            (42, u256_max - 1, u256_max, 42),
            (17, u256_max, u256_max, 17),
            (u256_max - 1, u256_max - 1, u256_max, u256_max - 1),
            (u256_max, u256_max - 1, u256_max, u256_max - 1),
            (u256_max, u256_max, u256_max, u256_max)
        ]
            .span();

        for round in round_up {
            for args in args_list {
                let (x, y, denominator, expected) = args;
                assert_eq!(u256_mul_div(*x, *y, *denominator, round), *expected);
            };
        };
    }
}
