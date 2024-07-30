use openzeppelin::account::interface::EthPublicKey;
use starknet::ClassHash;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;
use starknet::class_hash::class_hash_const;
use starknet::contract_address_const;
use starknet::secp256_trait::Secp256Trait;

pub(crate) const DECIMALS: u8 = 18_u8;
pub(crate) const SUPPLY: u256 = 2000;
pub(crate) const VALUE: u256 = 300;
pub(crate) const FELT_VALUE: felt252 = 'FELT_VALUE';
pub(crate) const ROLE: felt252 = 'ROLE';
pub(crate) const OTHER_ROLE: felt252 = 'OTHER_ROLE';
pub(crate) const TOKEN_ID: u256 = 21;
pub(crate) const TOKEN_ID_2: u256 = 121;
pub(crate) const TOKEN_VALUE: u256 = 42;
pub(crate) const TOKEN_VALUE_2: u256 = 142;
pub(crate) const PUBKEY: felt252 = 'PUBKEY';
pub(crate) const DAPP_NAME: felt252 = 'DAPP_NAME';
pub(crate) const DAPP_VERSION: felt252 = 'DAPP_VERSION';
pub(crate) const SALT: felt252 = 'SALT';
pub(crate) const SUCCESS: felt252 = 123123;
pub(crate) const FAILURE: felt252 = 456456;
pub(crate) const MIN_TRANSACTION_VERSION: felt252 = 1;
pub(crate) const TRANSACTION_HASH: felt252 = 'TRANSACTION_HASH';
// 2**128
pub(crate) const QUERY_OFFSET: felt252 = 0x100000000000000000000000000000000;
// QUERY_OFFSET + MIN_TRANSACTION_VERSION
pub(crate) const QUERY_VERSION: felt252 = 0x100000000000000000000000000000001;

pub(crate) fn NAME() -> ByteArray {
    "NAME"
}

pub(crate) fn SYMBOL() -> ByteArray {
    "SYMBOL"
}

pub(crate) fn BASE_URI() -> ByteArray {
    "https://api.example.com/v1/"
}

pub(crate) fn BASE_URI_2() -> ByteArray {
    "https://api.example.com/v2/"
}

pub(crate) fn ADMIN() -> ContractAddress {
    contract_address_const::<'ADMIN'>()
}

pub(crate) fn AUTHORIZED() -> ContractAddress {
    contract_address_const::<'AUTHORIZED'>()
}

pub(crate) fn ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

pub(crate) fn CLASS_HASH_ZERO() -> ClassHash {
    class_hash_const::<0>()
}

pub(crate) fn CALLER() -> ContractAddress {
    contract_address_const::<'CALLER'>()
}

pub(crate) fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

pub(crate) fn NEW_OWNER() -> ContractAddress {
    contract_address_const::<'NEW_OWNER'>()
}

pub(crate) fn OTHER() -> ContractAddress {
    contract_address_const::<'OTHER'>()
}

pub(crate) fn OTHER_ADMIN() -> ContractAddress {
    contract_address_const::<'OTHER_ADMIN'>()
}

pub(crate) fn SPENDER() -> ContractAddress {
    contract_address_const::<'SPENDER'>()
}

pub(crate) fn RECIPIENT() -> ContractAddress {
    contract_address_const::<'RECIPIENT'>()
}

pub(crate) fn OPERATOR() -> ContractAddress {
    contract_address_const::<'OPERATOR'>()
}

pub(crate) fn DATA(success: bool) -> Span<felt252> {
    let mut data = array![];
    if success {
        data.append(SUCCESS);
    } else {
        data.append(FAILURE);
    }
    data.span()
}

pub(crate) fn EMPTY_DATA() -> Span<felt252> {
    array![].span()
}

//
// Signing keys
//

pub(crate) mod secp256k1 {
    use openzeppelin::tests::utils::signing::{Secp256k1KeyPair, get_secp256k1_keys_from};

    pub(crate) fn KEY_PAIR() -> Secp256k1KeyPair {
        let private_key = u256 { low: 'PRIVATE_LOW', high: 'PRIVATE_HIGH' };
        get_secp256k1_keys_from(private_key)
    }

    pub(crate) fn KEY_PAIR_2() -> Secp256k1KeyPair {
        let private_key = u256 { low: 'PRIVATE_LOW_2', high: 'PRIVATE_HIGH_2' };
        get_secp256k1_keys_from(private_key)
    }
}

pub(crate) mod stark {
    use openzeppelin::tests::utils::signing::{StarkKeyPair, get_stark_keys_from};

    pub(crate) fn KEY_PAIR() -> StarkKeyPair {
        get_stark_keys_from('PRIVATE_KEY')
    }

    pub(crate) fn KEY_PAIR_2() -> StarkKeyPair {
        get_stark_keys_from('PRIVATE_KEY_2')
    }
}
