use snforge_std::signature::stark_curve::{StarkCurveSignerImpl, StarkCurveKeyPairImpl};
use snforge_std::signature::{KeyPair, KeyPairTrait};

pub type StarkKeyPair = KeyPair<felt252, felt252>;

pub fn KEY_PAIR() -> StarkKeyPair {
    KeyPairTrait::from_secret_key('SECRET_KEY')
}
pub fn KEY_PAIR_2() -> StarkKeyPair {
    KeyPairTrait::from_secret_key('SECRET_KEY_2')
}
