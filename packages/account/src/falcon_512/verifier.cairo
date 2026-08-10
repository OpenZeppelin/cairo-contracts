// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.1 (account/src/falcon_512/verifier.cairo)

/// Verification strategy used by `Falcon512AccountComponent`.
pub trait Falcon512SignatureVerifier {
    /// Returns whether `signature` authenticates `message_hash` under `public_key`.
    fn verify(message_hash: felt252, public_key: Span<felt252>, signature: Span<felt252>) -> bool;

    /// Returns whether the packed public key has the required canonical encoding.
    fn is_valid_public_key(public_key: Span<felt252>) -> bool;
}
