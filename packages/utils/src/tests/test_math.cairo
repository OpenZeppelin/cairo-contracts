use core::num::traits::Bounded;
use crate::math::Rounding;
use crate::math::u256_mul_div;

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
    let args_list = array![ // (x, y, denominator, expected result)
    (3, 4, 5, 2), (3, 5, 5, 3)]
        .span();

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
    let args_list = array![ // (x, y, denominator, expected result)
    (3, 4, 5, 3), (3, 5, 5, 3)]
        .span();

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
