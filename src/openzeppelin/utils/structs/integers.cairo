use option::OptionTrait;
use integer::BoundedInt;
use integer::NumericLiteral;
use integer::{u256_overflowing_add, u256_overflow_sub};

/// Represents a 220-bit unsigned integer.
/// TODO: Implement the rest of the traits to make this a full-fledged Cairo integer.
#[derive(Copy, Drop, PartialEq, Serde)]
struct u220 {
    inner: u256
}

impl NumericLiteralU220 of NumericLiteral<u220>;

fn u220_overflowing_add(lhs: u220, rhs: u220) -> (u220, bool) {
    let (sum, overflow) = u256_overflowing_add(lhs.inner, rhs.inner);
    (u220 { inner: sum }, overflow || sum > BoundedInt::max().inner)
}

fn u220_overflow_sub(lhs: u220, rhs: u220) -> (u220, bool) {
    let (sub, overflow) = u256_overflow_sub(lhs.inner, rhs.inner);
    (u220 { inner: sub }, overflow)
}

fn u220_checked_add(lhs: u220, rhs: u220) -> Option<u220> {
    let (r, overflow) = u220_overflowing_add(lhs, rhs);
    if overflow {
        Option::None
    } else {
        Option::Some(r)
    }
}

impl U220Add of Add<u220> {
    fn add(lhs: u220, rhs: u220) -> u220 {
        u220_checked_add(lhs, rhs).expect('u220_add Overflow')
    }
}

impl U220AddEq of AddEq<u220> {
    #[inline(always)]
    fn add_eq(ref self: u220, other: u220) {
        self = Add::add(self, other);
    }
}

fn u220_checked_sub(lhs: u220, rhs: u220) -> Option<u220> {
    let (r, overflow) = u220_overflow_sub(lhs, rhs);
    if overflow {
        Option::None
    } else {
        Option::Some(r)
    }
}

impl U220Sub of Sub<u220> {
    fn sub(lhs: u220, rhs: u220) -> u220 {
        u220_checked_sub(lhs, rhs).expect('u220_sub Overflow')
    }
}
impl U220SubEq of SubEq<u220> {
    #[inline(always)]
    fn sub_eq(ref self: u220, other: u220) {
        self = Sub::sub(self, other);
    }
}

impl BoundedU220 of BoundedInt<u220> {
    #[inline(always)]
    fn min() -> u220 nopanic {
        u220 { inner: 0 }
    }
    #[inline(always)]
    fn max() -> u220 nopanic {
        u220 { inner: 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffff }
    }
}
