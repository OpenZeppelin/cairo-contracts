use openzeppelin::token::erc721::ERC721;
use openzeppelin::token::erc721::IERC721_ID;
use openzeppelin::token::erc721::IERC721METADATA_ID;

use starknet::contract_address_const;
use starknet::ContractAddress;
use integer::u256_from_felt252;

const NAME: felt252 = 111;
const SYMBOL: felt252 = 222;
const URI: felt252 = 333;

fn TOKEN_ID() -> u256 {
    u256_from_felt252(7)
}

fn ADDRESS_ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

fn ACCOUNT1() -> ContractAddress {
    contract_address_const::<1234>()
}

fn ACCOUNT2() -> ContractAddress {
    contract_address_const::<5678>()
}

fn setup() {
    ERC721::initializer(NAME, SYMBOL);
    ERC721::_mint(ACCOUNT1(), TOKEN_ID());
}

#[test]
#[available_gas(2000000)]
fn initialize() {
    ERC721::initializer(NAME, SYMBOL);

    assert(ERC721::name() == NAME, 'Name should be NAME');
    assert(ERC721::symbol() == SYMBOL, 'Symbol should be SYMBOL');
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn balance_of_from_zero_address() {
    ERC721::balance_of(ADDRESS_ZERO());
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn owner_of_is_zero_address() {
    ERC721::owner_of(TOKEN_ID());
}

#[test]
#[available_gas(2000000)]
fn _mint() {
    ERC721::initializer(NAME, SYMBOL);
    assert(ERC721::balance_of(ACCOUNT1()) == u256_from_felt252(0), 'Balance should be 0');

    ERC721::_mint(ACCOUNT1(), TOKEN_ID());

    assert(ERC721::balance_of(ACCOUNT1()) == u256_from_felt252(1), 'Balance should be 1');
    assert(ERC721::owner_of(TOKEN_ID()) == ACCOUNT1(), 'Owner should be ACCOUNT1');
}

#[test]
#[available_gas(2000000)]
fn _approve() {
    setup();
    assert(ERC721::get_approved(TOKEN_ID()) == ADDRESS_ZERO(), 'Approved should be 0');

    ERC721::_approve(ACCOUNT2(), TOKEN_ID());

    assert(ERC721::get_approved(TOKEN_ID()) == ACCOUNT2(), 'Approved should be ACCOUNT2');
}

#[test]
#[available_gas(2000000)]
fn _exists() {
    setup();

    assert(ERC721::_exists(TOKEN_ID()), 'Token should exist');
    ERC721::_burn(TOKEN_ID());
    assert(!ERC721::_exists(TOKEN_ID()), 'Token should not exist');
}

#[test]
#[available_gas(2000000)]
fn _is_approved_or_owner() {
    setup();
    assert(ERC721::_is_approved_or_owner(ACCOUNT1(), TOKEN_ID()), 'Owner is recognized');

    ERC721::_operator_approvals::write((ACCOUNT1(), ACCOUNT2()), true);
    assert(ERC721::_is_approved_or_owner(ACCOUNT2(), TOKEN_ID()), 'ACCOUNT2 should be approved');
    // Set to false to test when account is approved
    ERC721::_operator_approvals::write((ACCOUNT1(), ACCOUNT2()), false);

    assert(
        !ERC721::_is_approved_or_owner(ACCOUNT2(), TOKEN_ID()), 'ACCOUNT2 should not be approved'
    );
    ERC721::_approve(ACCOUNT2(), TOKEN_ID());
    assert(ERC721::_is_approved_or_owner(ACCOUNT2(), TOKEN_ID()), 'ACCOUNT2 should be approved');
}

#[test]
#[available_gas(2000000)]
fn _transfer() {
    setup();

    ERC721::_transfer(ACCOUNT1(), ACCOUNT2(), TOKEN_ID());

    assert(ERC721::balance_of(ACCOUNT1()) == u256_from_felt252(0), 'Balance should be 0');
    assert(ERC721::balance_of(ACCOUNT2()) == u256_from_felt252(1), 'Balance should be 1');

    assert(ERC721::owner_of(TOKEN_ID()) == ACCOUNT2(), 'Token owner should be ACCOUNT2');
}

#[test]
#[available_gas(2000000)]
fn _burn() {
    setup();

    ERC721::_approve(ACCOUNT2(), TOKEN_ID());
    ERC721::_burn(TOKEN_ID());

    assert(ERC721::balance_of(ACCOUNT1()) == u256_from_felt252(0), 'Balance should be 0');
    assert(ERC721::_owners::read(TOKEN_ID()) == ADDRESS_ZERO(), 'Owner should be 0');
    assert(
        ERC721::_token_approvals::read(TOKEN_ID()) == ADDRESS_ZERO(),
        'Token should not have approval'
    );
}

#[test]
#[available_gas(2000000)]
fn _set_token_uri() {
    setup();

    assert(ERC721::token_uri(TOKEN_ID()) == 0, 'URI should be 0');
    ERC721::_set_token_uri(TOKEN_ID(), URI);
    assert(ERC721::token_uri(TOKEN_ID()) == URI, 'URI should be set to URI var');
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn _set_token_uri_nonexistent_token() {
    ERC721::_set_token_uri(TOKEN_ID(), URI);
}
