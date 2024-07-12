pub mod stark {
    use snforge_std::signature::stark_curve::{StarkCurveSignerImpl, StarkCurveKeyPairImpl};
    use snforge_std::signature::{KeyPair, KeyPairTrait};

    pub type StarkKeyPair = KeyPair<felt252, felt252>;

    pub const PRIVATE_KEY: felt252 = 'PRIVATE_KEY';
    pub const PUBKEY: felt252 = 0x454c2645c42b23ea47717675e972e3fdcc1865a40ada320286e33b5a921ecd3;
    pub const KEY_PAIR: StarkKeyPair = StarkKeyPair { secret_key: PRIVATE_KEY, public_key: PUBKEY };

    pub const PRIVATE_KEY_2: felt252 = 'PRIVATE_KEY_2';
    pub const PUBKEY_2: felt252 = 0x3611882107b0c824d5a0f3d1dd9468d71bc5a8584ee30b2e166e532a7cd8eda;
    pub const KEY_PAIR_2: StarkKeyPair =
        StarkKeyPair { secret_key: PRIVATE_KEY_2, public_key: PUBKEY_2 };

    pub fn key_pair_from(private_key: felt252) -> StarkKeyPair {
        StarkCurveKeyPairImpl::from_secret_key(private_key)
    }
}

pub mod secp256k1 {
    use snforge_std::signature::secp256k1_curve::{
        Secp256k1CurveSignerImpl, Secp256k1CurveKeyPairImpl
    };
    use snforge_std::signature::{KeyPair, KeyPairTrait};
    use starknet::secp256k1::Secp256k1Point;

    pub type Secp256k1KeyPair = KeyPair<u256, Secp256k1Point>;

    pub const PRIVATE_KEY: u256 = u256 { low: 'PRIVATE_LOW', high: 'PRIVATE_HIGH' };
    pub fn KEY_PAIR() -> Secp256k1KeyPair {
        Secp256k1CurveKeyPairImpl::from_secret_key(PRIVATE_KEY)
    }

    pub const PRIVATE_KEY_2: u256 = u256 { low: 'PRIVATE_LOW_2', high: 'PRIVATE_HIGH_2' };
    pub fn KEY_PAIR_2() -> Secp256k1KeyPair {
        Secp256k1CurveKeyPairImpl::from_secret_key(PRIVATE_KEY_2)
    }

    pub fn key_pair_from(private_key: u256) -> Secp256k1KeyPair {
        Secp256k1CurveKeyPairImpl::from_secret_key(private_key)
    }
}
