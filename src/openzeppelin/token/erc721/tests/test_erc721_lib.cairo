use erc721_lib::ERC721Library;

const NAME: felt = 111;
const SYMBOL: felt = 222;
const ACCOUNT1: felt = 1234;
const ACCOUNT2: felt = 5678;
const URI: felt = 555;

fn setup() -> u256 {
    let token = u256_from_felt(7);

    ERC721Library::initializer(NAME, SYMBOL);
    ERC721Library::_mint(ACCOUNT1, token);
    return token;
}

#[test]
#[available_gas(2000000)]
fn initialize() {
    ERC721Library::initializer(NAME, SYMBOL);

    assert(ERC721Library::name() == NAME, 'Name should be NAME');
    assert(ERC721Library::symbol() == SYMBOL, 'Symbol should be SYMBOL');
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn balance_of_from_zero_address() {
    ERC721Library::balance_of(0);
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn owner_of_is_zero_address() {
    ERC721Library::owner_of(u256_from_felt(7));
}

#[test]
#[available_gas(2000000)]
fn _mint() {
    let token = u256_from_felt(7);

    ERC721Library::initializer(NAME, SYMBOL);
    assert(ERC721Library::balance_of(ACCOUNT1) == u256_from_felt(0), 'Balance should be 0');

    ERC721Library::_mint(ACCOUNT1, token);

    assert(ERC721Library::balance_of(ACCOUNT1) == u256_from_felt(1), 'Balance should be 1');
    assert(ERC721Library::owner_of(token) == ACCOUNT1, 'Owner should be ACCOUNT1');
}

#[test]
#[available_gas(2000000)]
fn _approve() {
    let token = setup();
    assert(ERC721Library::get_approved(token) == 0, 'Approved should be 0');

    ERC721Library::_approve(ACCOUNT2, token);

    assert(ERC721Library::get_approved(token) == ACCOUNT2, 'Approved should be ACCOUNT2');
}

#[test]
#[available_gas(2000000)]
fn exists() {
    let token = setup();

    assert(ERC721Library::exists(token), 'Token should exist');
    ERC721Library::_burn(token);
    assert(!ERC721Library::exists(token), 'Token should not exist');
}

#[test]
#[available_gas(2000000)]
fn _is_approved_or_owner() {
    let token = setup();
    assert(ERC721Library::_is_approved_or_owner(ACCOUNT1, token), 'Owner is recognized');

    ERC721Library::_operator_approvals::write((ACCOUNT1, ACCOUNT2), true);
    assert(ERC721Library::_is_approved_or_owner(ACCOUNT2, token), 'ACCOUNT2 should be approved');
    // Set to false to test when account is approved
    ERC721Library::_operator_approvals::write((ACCOUNT1, ACCOUNT2), false);

    assert(!ERC721Library::_is_approved_or_owner(ACCOUNT2, token), 'ACCOUNT2 should not be approved');
    ERC721Library::_approve(ACCOUNT2, token);
    assert(ERC721Library::_is_approved_or_owner(ACCOUNT2, token), 'ACCOUNT2 should be approved');
}

#[test]
#[available_gas(2000000)]
fn _transfer() {
    let token = setup();

    ERC721Library::_transfer(ACCOUNT1, ACCOUNT2, token);

    assert(ERC721Library::balance_of(ACCOUNT1) == u256_from_felt(0), 'Balance should be 0');
    assert(ERC721Library::balance_of(ACCOUNT2) == u256_from_felt(1), 'Balance should be 1');

    assert(ERC721Library::owner_of(token) == ACCOUNT2, 'Token owner should be ACCOUNT2');
}

#[test]
#[available_gas(2000000)]
fn _burn() {
    let token = setup();

    ERC721Library::_approve(ACCOUNT2, token);
    ERC721Library::_burn(token);

    assert(ERC721Library::balance_of(ACCOUNT1) == u256_from_felt(0), 'Balance should be 0');
    assert(ERC721Library::_owners::read(token) == 0, 'Owner should be 0');
    assert(ERC721Library::_token_approvals::read(token) == 0, 'Token should not have approval');
}

#[test]
#[available_gas(2000000)]
fn _set_token_uri() {
    let token = setup();

    assert(ERC721Library::token_uri(token) == 0, 'URI should be 0');
    ERC721Library::_set_token_uri(token, URI);
    assert(ERC721Library::token_uri(token) == URI, 'URI should be set to URI var');
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn _set_token_uri_nonexistent_token() {
    let token = u256_from_felt(123);
    ERC721Library::_set_token_uri(token, URI);
}
