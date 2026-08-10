// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.1 (account/src/falcon_512.cairo)

//! Falcon-512 SHAKE account component and verifier strategies.
//!
//! `Falcon512ShakeVerifier` validates the FALCON submission relation with a verifier-checked
//! polynomial-product hint that reduces on-chain execution cost. `Falcon512ShakeDirectVerifier`
//! recomputes the product on-chain. Both strategies use SHAKE-256 hash-to-point and
//! contract-specific felt encodings; they are not FN-DSA (FIPS 206) implementations.
//!
//! `Falcon512AccountComponent` provides SRC6 account behavior and owner-authorized key rotation
//! for canonical packed Falcon-512 public keys. Ready-to-deploy compositions are provided by the
//! `openzeppelin_presets` package.

pub mod account;
pub(crate) mod falcon;
pub(crate) mod hashing;
pub(crate) mod ntt;
pub(crate) mod packing;
pub mod verifier;
pub mod verifier_impls;
pub(crate) mod zq;

pub use account::Falcon512AccountComponent;
pub use verifier::Falcon512SignatureVerifier;
pub use verifier_impls::{Falcon512ShakeDirectVerifier, Falcon512ShakeVerifier};
