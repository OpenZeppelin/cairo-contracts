use snforge_std::signature::secp256k1_curve::{Secp256k1CurveSignerImpl, Secp256k1CurveKeyPairImpl};
use snforge_std::signature::stark_curve::{StarkCurveSignerImpl, StarkCurveKeyPairImpl};
use snforge_std::signature::{KeyPair, KeyPairTrait};
use starknet::secp256k1::Secp256k1Point;

pub type StarkKeyPair = KeyPair<felt252, felt252>;
pub type Secp256k1KeyPair = KeyPair<u256, Secp256k1Point>;

/// Builds a Stark Key Pair from a private key represented by a `felt252` value.
pub fn get_stark_keys_from(private_key: felt252) -> StarkKeyPair {
    StarkCurveKeyPairImpl::from_secret_key(private_key)
}

/// Builds a Secp256k1 Key Pair from a private key represented by a `u256` value.
pub fn get_secp256k1_keys_from(private_key: u256) -> Secp256k1KeyPair {
    Secp256k1CurveKeyPairImpl::from_secret_key(private_key)
}

/// A helper trait that facilitates converting a signature into a serialized format.
pub trait SerializedSigning<KP, M> {
    fn serialized_sign(self: KP, msg: M) -> Array<felt252>;
}

pub impl StarkSerializedSigning of SerializedSigning<StarkKeyPair, felt252> {
    fn serialized_sign(self: StarkKeyPair, msg: felt252) -> Array<felt252> {
        let (r, s) = self.sign(msg).unwrap();
        array![r, s]
    }
}

pub impl Secp256k1SerializedSigning of SerializedSigning<Secp256k1KeyPair, u256> {
    fn serialized_sign(self: Secp256k1KeyPair, msg: u256) -> Array<felt252> {
        let (r, s) = self.sign(msg).unwrap();
        array![r.low.into(), r.high.into(), s.low.into(), s.high.into()]
    }
}
