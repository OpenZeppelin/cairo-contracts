// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.15.1 (merkle_tree/hashes.cairo)

use core::hash::HashStateTrait;
use core::pedersen::PedersenTrait;
use core::poseidon::PoseidonTrait;
use core::traits::PartialOrd;

/// Computes a commutative hash of a sorted pair of felt252.
///
/// This is usually implemented as an extension of a non-commutative hash function, like
/// Pedersen or Poseidon, returning the hash of the concatenation of the two values by first
/// sorting them.
///
/// Frequently used when working with merkle proofs.
pub trait CommutativeHasher {
    fn commutative_hash(a: felt252, b: felt252) -> felt252;
}

/// Computes Pedersen's commutative hash of a sorted pair of felt252.
pub impl PedersenCHasher of CommutativeHasher {
    /// Computes the Pedersen hash of chaining the two values
    /// with the len, sorting the pair first.
    fn commutative_hash(a: felt252, b: felt252) -> felt252 {
        let hash_state = PedersenTrait::new(0);
        if a < b {
            hash_state.update(a).update(b).update(2).finalize()
        } else {
            hash_state.update(b).update(a).update(2).finalize()
        }
    }
}

/// Computes Poseidon's commutative hash of a sorted pair of felt252.
pub impl PoseidonCHasher of CommutativeHasher {
    /// Computes the Poseidon hash of the concatenation of two values, sorting the pair first.
    fn commutative_hash(a: felt252, b: felt252) -> felt252 {
        let hash_state = PoseidonTrait::new();
        if a < b {
            hash_state.update(a).update(b).finalize()
        } else {
            hash_state.update(b).update(a).finalize()
        }
    }
}

impl Felt252AsIntPartialOrd of PartialOrd<felt252> {
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
