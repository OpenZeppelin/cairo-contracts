use starknet::ClassHash;
use starknet::ContractAddress;
use starknet::class_hash_const;
use starknet::contract_address_const;

const NAME: felt252 = 'NAME';
const SYMBOL: felt252 = 'SYMBOL';
const DECIMALS: u8 = 18_u8;
const SUPPLY: u256 = 2000;
const VALUE: u256 = 300;
const ROLE: felt252 = 'ROLE';
const OTHER_ROLE: felt252 = 'OTHER_ROLE';
const URI: felt252 = 'URI';
const TOKEN_ID: u256 = 21;
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
