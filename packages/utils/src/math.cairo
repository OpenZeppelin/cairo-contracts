// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.18.0 (utils/math.cairo)

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
