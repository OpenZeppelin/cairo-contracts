use starknet::ClassHash;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;
use starknet::class_hash::class_hash_const;
use starknet::contract_address_const;
use starknet::secp256_trait::Secp256Trait;

pub type EthPublicKey = starknet::secp256k1::Secp256k1Point;

pub const DECIMALS: u8 = 18_u8;
pub const SUPPLY: u256 = 2000;
pub const VALUE: u256 = 300;
pub const FELT_VALUE: felt252 = 'FELT_VALUE';
pub const ROLE: felt252 = 'ROLE';
pub const OTHER_ROLE: felt252 = 'OTHER_ROLE';
pub const TOKEN_ID: u256 = 21;
pub const TOKEN_ID_2: u256 = 121;
pub const TOKEN_VALUE: u256 = 42;
pub const TOKEN_VALUE_2: u256 = 142;
pub const PUBKEY: felt252 = 'PUBKEY';
pub const NEW_PUBKEY: felt252 = 0x26da8d11938b76025862be14fdb8b28438827f73e75e86f7bfa38b196951fa7;
pub const DAPP_NAME: felt252 = 'DAPP_NAME';
pub const DAPP_VERSION: felt252 = 'DAPP_VERSION';
pub const SALT: felt252 = 'SALT';
pub const SUCCESS: felt252 = 123123;
pub const FAILURE: felt252 = 456456;
pub const MIN_TRANSACTION_VERSION: felt252 = 1;
pub const TRANSACTION_HASH: felt252 = 'TRANSACTION_HASH';
// 2**128
pub const QUERY_OFFSET: felt252 = 0x100000000000000000000000000000000;
// QUERY_OFFSET + MIN_TRANSACTION_VERSION
pub const QUERY_VERSION: felt252 = 0x100000000000000000000000000000001;

pub fn NAME() -> ByteArray {
    "NAME"
}

pub fn SYMBOL() -> ByteArray {
    "SYMBOL"
}

pub fn BASE_URI() -> ByteArray {
    "https://api.example.com/v1/"
}

pub fn BASE_URI_2() -> ByteArray {
    "https://api.example.com/v2/"
}

pub fn ETH_PUBKEY() -> EthPublicKey {
    Secp256Trait::secp256_ec_get_point_from_x_syscall(3, false).unwrap_syscall().unwrap()
}

pub fn NEW_ETH_PUBKEY() -> EthPublicKey {
    Secp256Trait::secp256_ec_get_point_from_x_syscall(4, false).unwrap_syscall().unwrap()
}

pub fn ADMIN() -> ContractAddress {
    contract_address_const::<'ADMIN'>()
}

pub fn AUTHORIZED() -> ContractAddress {
    contract_address_const::<'AUTHORIZED'>()
}

pub fn ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

pub fn CLASS_HASH_ZERO() -> ClassHash {
    class_hash_const::<0>()
}

pub fn CALLER() -> ContractAddress {
    contract_address_const::<'CALLER'>()
}

pub fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

pub fn NEW_OWNER() -> ContractAddress {
    contract_address_const::<'NEW_OWNER'>()
}

pub fn OTHER() -> ContractAddress {
    contract_address_const::<'OTHER'>()
}

pub fn OTHER_ADMIN() -> ContractAddress {
    contract_address_const::<'OTHER_ADMIN'>()
}

pub fn SPENDER() -> ContractAddress {
    contract_address_const::<'SPENDER'>()
}

pub fn RECIPIENT() -> ContractAddress {
    contract_address_const::<'RECIPIENT'>()
}

pub fn OPERATOR() -> ContractAddress {
    contract_address_const::<'OPERATOR'>()
}

pub fn DATA(success: bool) -> Span<felt252> {
    let mut data = array![];
    if success {
        data.append(SUCCESS);
    } else {
        data.append(FAILURE);
    }
    data.span()
}

pub fn EMPTY_DATA() -> Span<felt252> {
    array![].span()
}

//
// Signing keys
//

pub mod secp256k1 {
    use openzeppelin_test_utils::signing::{Secp256k1KeyPair, get_secp256k1_keys_from};

    pub fn KEY_PAIR() -> Secp256k1KeyPair {
        let private_key = u256 { low: 'PRIVATE_LOW', high: 'PRIVATE_HIGH' };
        get_secp256k1_keys_from(private_key)
    }

    pub fn KEY_PAIR_2() -> Secp256k1KeyPair {
        let private_key = u256 { low: 'PRIVATE_LOW_2', high: 'PRIVATE_HIGH_2' };
        get_secp256k1_keys_from(private_key)
    }
}

pub mod stark {
    use openzeppelin_test_utils::signing::{StarkKeyPair, get_stark_keys_from};

    pub fn KEY_PAIR() -> StarkKeyPair {
        get_stark_keys_from('PRIVATE_KEY')
    }

    pub fn KEY_PAIR_2() -> StarkKeyPair {
        get_stark_keys_from('PRIVATE_KEY_2')
    }
}
