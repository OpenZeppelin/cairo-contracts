// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v1.0.0 (utils/math.cairo)

use core::traits::{BitAnd, BitXor, Into};

/// Returns the average of two unsigned integers. The result is rounded down.
pub fn average<
    T, +Unsigned<T>, +Add<T>, +Div<T>, +BitAnd<T>, +BitXor<T>, +Into<u8, T>, +Copy<T>, +Drop<T>,
>(
    a: T, b: T,
) -> T {
    // (a + b) / 2 can overflow.
    (a & b) + (a ^ b) / 2_u8.into()
}

/// A trait to represent unsigned integers.
pub trait Unsigned<T>;

impl U8Unsigned of Unsigned<u8>;
impl U16Unsigned of Unsigned<u16>;
impl U32Unsigned of Unsigned<u32>;
impl U64Unsigned of Unsigned<u64>;
impl U128Unsigned of Unsigned<u128>;
impl U256Unsigned of Unsigned<u256>;
