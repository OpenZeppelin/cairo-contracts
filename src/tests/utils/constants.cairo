use starknet::ContractAddress;
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
const DAPP_NAME: felt252 = 'OZ-DAPP';
const DAPP_VERSION: felt252 = '2.0.0';
// Public key of the private key equal 0x1234
const PUBLIC_KEY: felt252 = 0x26da8d11938b76025862be14fdb8b28438827f73e75e86f7bfa38b196951fa7;

fn ADMIN() -> ContractAddress {
    contract_address_const::<'ADMIN'>()
}

fn OTHER_ADMIN() -> ContractAddress {
    contract_address_const::<'OTHER_ADMIN'>()
}

fn AUTHORIZED() -> ContractAddress {
    contract_address_const::<'AUTHORIZED'>()
}

fn ZERO() -> ContractAddress {
    contract_address_const::<0>()
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

fn SPENDER() -> ContractAddress {
    contract_address_const::<2>()
}

fn RECIPIENT() -> ContractAddress {
    contract_address_const::<'RECIPIENT'>()
}

fn OTHER() -> ContractAddress {
    contract_address_const::<'OTHER'>()
}

fn OPERATOR() -> ContractAddress {
    contract_address_const::<'OPERATOR'>()
}
