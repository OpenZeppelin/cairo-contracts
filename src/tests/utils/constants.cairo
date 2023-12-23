use starknet::ClassHash;
use starknet::ContractAddress;
use starknet::class_hash_const;
use starknet::contract_address_const;

//const NAME: ByteArray = "NAME";
//const SYMBOL: ByteArray = "SYMBOL";
const DECIMALS: u8 = 18_u8;
const SUPPLY: u256 = 2000;
const VALUE: u256 = 300;
const ROLE: felt252 = 'ROLE';
const OTHER_ROLE: felt252 = 'OTHER_ROLE';
//const URI: ByteArray = "URI";
const TOKEN_ID: u256 = 21;
const PUBKEY: felt252 = 'PUBKEY';
const NEW_PUBKEY: felt252 = 'NEW_PUBKEY';
const SALT: felt252 = 'SALT';
const SUCCESS: felt252 = 123123;
const FAILURE: felt252 = 456456;

fn NAME() -> ByteArray {
    let ba: ByteArray = "NAME";
    ba
}

fn SYMBOL() -> ByteArray {
    let ba: ByteArray = "SYMBOL";
    ba
}

fn URI() -> ByteArray {
    let ba: ByteArray = "URI";
    ba
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

//fn DATA(success: bool) -> ByteArray {
//    let mut data: ByteArray = "";
//    if success {
//        data.append_byte(1);
//    } else {
//        data.append(0);
//    }
//    data
//}
