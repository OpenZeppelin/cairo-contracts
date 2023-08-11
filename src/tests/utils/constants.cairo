use starknet::ContractAddress;
use starknet::contract_address_const;

const NAME: felt252 = 'NAME';
const SYMBOL: felt252 = 'SYMBOL';
const DECIMALS: u8 = 18_u8;
const SUPPLY: u256 = 2000;
const VALUE: u256 = 300;

fn ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

fn SPENDER() -> ContractAddress {
    contract_address_const::<2>()
}

fn RECIPIENT() -> ContractAddress {
    contract_address_const::<'RECIPIENT'>()
}
