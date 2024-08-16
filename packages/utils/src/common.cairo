// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.15.1 (utils/common.cairo)

use core::traits::PartialOrd;

pub impl Felt252PartialOrd of PartialOrd<felt252> {
    #[inline(always)]
    fn le(lhs: felt252, rhs: felt252) -> bool {
        let lhs: u256 = lhs.into();
        lhs <= rhs.into()
    }
    #[inline(always)]
    fn ge(lhs: felt252, rhs: felt252) -> bool {
        let lhs: u256 = lhs.into();
        lhs >= rhs.into()
    }
    #[inline(always)]
    fn lt(lhs: felt252, rhs: felt252) -> bool {
        let lhs: u256 = lhs.into();
        lhs < rhs.into()
    }
    #[inline(always)]
    fn gt(lhs: felt252, rhs: felt252) -> bool {
        let lhs: u256 = lhs.into();
        lhs > rhs.into()
    }
}
