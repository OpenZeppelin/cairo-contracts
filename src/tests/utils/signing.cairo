use snforge_std::signature::secp256k1_curve::{Secp256k1CurveSignerImpl, Secp256k1CurveKeyPairImpl};
use snforge_std::signature::stark_curve::{StarkCurveSignerImpl, StarkCurveKeyPairImpl};
use snforge_std::signature::{KeyPair, KeyPairTrait};
use starknet::secp256k1::Secp256k1Point;

pub type StarkKeyPair = KeyPair<felt252, felt252>;
pub type Secp256k1KeyPair = KeyPair<u256, Secp256k1Point>;

pub fn get_stark_keys_from(private_key: felt252) -> StarkKeyPair {
    StarkCurveKeyPairImpl::from_secret_key(private_key)
}

pub fn get_secp256k1_keys_from(private_key: u256) -> Secp256k1KeyPair {
    Secp256k1CurveKeyPairImpl::from_secret_key(private_key)
}

#[generate_trait]
pub impl StarkKeyPairExt of StarkKeyPairExtTrait {
    fn serialized_sign(self: StarkKeyPair, msg: felt252) -> Array<felt252> {
        let (r, s) = self.sign(msg).unwrap();
        array![r, s]
    }
}

#[generate_trait]
pub impl Secp256k1KeyPairExt of Secp256k1KeyPairExtTrait {
    fn serialized_sign(self: Secp256k1KeyPair, msg: u256) -> Array<felt252> {
        let (r, s) = self.sign(msg).unwrap();
        array![r.low.into(), r.high.into(), s.low.into(), s.high.into()]
    }
}
