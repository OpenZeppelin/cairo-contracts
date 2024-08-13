// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.15.0 (utils/cryptography/hashes.cairo)

use core::pedersen::pedersen;
use core::poseidon::poseidon_hash_span;
use openzeppelin_utils::common::Felt252PartialOrd;

/// Commutative hash of a sorted pair of felt252.
///
/// This is usually implemented as an extension of a non-commutative hash function, like
/// Pedersen or Poseidon, returning the hash of the concatenation of the two values by first
/// sorting them.
///
/// Frequently used when working with merkle proofs.
pub trait CommutativeHash {
    fn commutative_hash(a: felt252, b: felt252) -> felt252;
}

/// Pedersen commutative hash of a sorted pair of felt252.
pub impl Pedersen of CommutativeHash {
    /// Computes the Pedersen hash of the concatenation of two values, sorting the pair first.
    fn commutative_hash(a: felt252, b: felt252) -> felt252 {
        if a < b {
            pedersen(a, b)
        } else {
            pedersen(b, a)
        }
    }
}

/// Poseidon commutative hash of a sorted pair of felt252.
pub impl Poseidon of CommutativeHash {
    /// Computes the Poseidon hash of the concatenation of two values, sorting the pair first.
    fn commutative_hash(a: felt252, b: felt252) -> felt252 {
        if a < b {
            poseidon_hash_span([a, b].span())
        } else {
            poseidon_hash_span([b, a].span())
        }
    }
}
