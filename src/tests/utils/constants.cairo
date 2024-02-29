use openzeppelin::account::interface::EthPublicKey;
use starknet::ClassHash;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;
use starknet::class_hash_const;
use starknet::contract_address_const;
use starknet::secp256k1::secp256k1_get_point_from_x_syscall;

const DECIMALS: u8 = 18_u8;
const SUPPLY: u256 = 2000;
const VALUE: u256 = 300;
const ROLE: felt252 = 'ROLE';
const OTHER_ROLE: felt252 = 'OTHER_ROLE';
const TOKEN_ID: u256 = 21;
const TOKEN_ID_2: u256 = 121;
const TOKEN_VALUE: u256 = 42;
const TOKEN_VALUE_2: u256 = 142;
const PUBKEY: felt252 = 'PUBKEY';
const NEW_PUBKEY: felt252 = 'NEW_PUBKEY';
const SALT: felt252 = 'SALT';
const SUCCESS: felt252 = 123123;
const FAILURE: felt252 = 456456;
const MIN_TRANSACTION_VERSION: felt252 = 1;
// 2**128
const QUERY_OFFSET: felt252 = 0x100000000000000000000000000000000;
// QUERY_OFFSET + MIN_TRANSACTION_VERSION
const QUERY_VERSION: felt252 = 0x100000000000000000000000000000001;

fn NAME() -> ByteArray {
    "NAME"
}

fn SYMBOL() -> ByteArray {
    "SYMBOL"
}

fn BASE_URI() -> ByteArray {
    "https://api.example.com/v1/"
}

fn BASE_URI_2() -> ByteArray {
    "https://api.example.com/v2/"
}

fn ETH_PUBKEY() -> EthPublicKey {
    secp256k1_get_point_from_x_syscall(3, false).unwrap_syscall().unwrap()
}

fn NEW_ETH_PUBKEY() -> EthPublicKey {
    secp256k1_get_point_from_x_syscall(4, false).unwrap_syscall().unwrap()
}

fn ADMIN() -> ContractAddress {
    contract_address_const::<'ADMIN'>()
}

fn AUTHORIZED() -> ContractAddress {
    contract_address_const::<'AUTHORIZED'>()
}

fn ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

fn CLASS_HASH_ZERO() -> ClassHash {
    class_hash_const::<0>()
}

fn CALLER() -> ContractAddress {
    contract_address_const::<'CALLER'>()
}

fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

fn NEW_OWNER() -> ContractAddress {
    contract_address_const::<'NEW_OWNER'>()
}

fn OTHER() -> ContractAddress {
    contract_address_const::<'OTHER'>()
}

fn OTHER_ADMIN() -> ContractAddress {
    contract_address_const::<'OTHER_ADMIN'>()
}

fn SPENDER() -> ContractAddress {
    contract_address_const::<'SPENDER'>()
}

fn RECIPIENT() -> ContractAddress {
    contract_address_const::<'RECIPIENT'>()
}

fn OPERATOR() -> ContractAddress {
    contract_address_const::<'OPERATOR'>()
}

fn DATA(success: bool) -> Span<felt252> {
    let mut data = array![];
    if success {
        data.append(SUCCESS);
    } else {
        data.append(FAILURE);
    }
    data.span()
}

fn EMPTY_DATA() -> Span<felt252> {
    array![].span()
}
