use openzeppelin::introspection::erc165;
use openzeppelin::token::erc721;
use openzeppelin::token::erc721::ERC721;

use starknet::contract_address_const;
use starknet::ContractAddress;
use starknet::testing::set_caller_address;
use integer::u256;
use integer::u256_from_felt252;
use traits::Into;
use zeroable::Zeroable;

const NAME: felt252 = 111;
const SYMBOL: felt252 = 222;
const URI: felt252 = 333;

fn TOKEN_ID() -> u256 {
    7.into()
}

fn ZERO() -> ContractAddress {
    Zeroable::zero()
}
fn OWNER() -> ContractAddress {
    contract_address_const::<1>()
}
fn RECIPIENT() -> ContractAddress {
    contract_address_const::<2>()
}
fn SPENDER() -> ContractAddress {
    contract_address_const::<3>()
}
fn OPERATOR() -> ContractAddress {
    contract_address_const::<4>()
}
fn OTHER() -> ContractAddress {
    contract_address_const::<5>()
}

///
/// Setup
///

fn setup() {
    ERC721::initializer(NAME, SYMBOL);
    ERC721::_mint(OWNER(), TOKEN_ID());
}

///
/// Initialize
///

#[test]
#[available_gas(2000000)]
fn test_initialize() {
    ERC721::initializer(NAME, SYMBOL);

    assert(ERC721::name() == NAME, 'Name should be NAME');
    assert(ERC721::symbol() == SYMBOL, 'Symbol should be SYMBOL');
    assert(ERC721::balance_of(OWNER()) == 0.into(), 'Balance should be zero');

    assert(ERC721::supports_interface(erc721::IERC721_ID), 'Missing interface ID');
    assert(ERC721::supports_interface(erc721::IERC721METADATA_ID), 'missing interface ID');
    assert(ERC721::supports_interface(erc165::IERC165_ID), 'missing interface ID');
    assert(!ERC721::supports_interface(erc165::INVALID_ID), 'invalid interface ID');
}

///
/// Getters
///

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: invalid account', ))]
fn test_balance_of_zero() {
    ERC721::balance_of(ZERO());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: invalid token ID', ))]
fn test_owner_of_non_minted() {
    ERC721::owner_of(u256_from_felt252(7));
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: invalid token ID', ))]
fn test_get_approved_nonexistent() {
    ERC721::get_approved(u256_from_felt252(7));
}

#[test]
#[available_gas(2000000)]
fn test__exists() {
    assert(!ERC721::_exists(TOKEN_ID()), 'Token should not exist');
    assert(ERC721::_owners::read(TOKEN_ID()) == ZERO(), 'Invalid owner');

    ERC721::_mint(RECIPIENT(), TOKEN_ID());

    assert(ERC721::_exists(TOKEN_ID()), 'Token should exist');
    assert(ERC721::_owners::read(TOKEN_ID()) == RECIPIENT(), 'Low level ownership');

    ERC721::_burn(TOKEN_ID());

    assert(!ERC721::_exists(TOKEN_ID()), 'Token should not exist');
    assert(ERC721::_owners::read(TOKEN_ID()) == ZERO(), 'Low level ownership');
}

///
/// approve & _approve
///

#[test]
#[available_gas(2000000)]
fn test_approve_from_owner() {
    setup();

    set_caller_address(OWNER());
    ERC721::approve(SPENDER(), TOKEN_ID());
    assert(ERC721::get_approved(TOKEN_ID()) == SPENDER(), 'Spender not approved correctly');
}

#[test]
#[available_gas(2000000)]
fn test_approve_from_operator() {
    setup();

    set_caller_address(OWNER());
    ERC721::set_approval_for_all(OPERATOR(), true);

    set_caller_address(OPERATOR());
    ERC721::approve(SPENDER(), TOKEN_ID());
    assert(ERC721::get_approved(TOKEN_ID()) == SPENDER(), 'Spender not approved correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: unauthorized caller', ))]
fn test_approve_from_unauthorized() {
    setup();

    set_caller_address(OTHER());
    ERC721::approve(SPENDER(), TOKEN_ID());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: approval to owner', ))]
fn test_approve_to_owner() {
    setup();

    set_caller_address(OWNER());
    ERC721::approve(OWNER(), TOKEN_ID());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: invalid token ID', ))]
fn test_approve_nonexistent() {
    ERC721::approve(SPENDER(), TOKEN_ID());
}

#[test]
#[available_gas(2000000)]
fn test__approve() {
    setup();

    ERC721::_approve(SPENDER(), TOKEN_ID());
    assert(ERC721::get_approved(TOKEN_ID()) == SPENDER(), 'Spender not approved correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: approval to owner', ))]
fn test__approve_to_owner() {
    setup();

    ERC721::_approve(OWNER(), TOKEN_ID());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: invalid token ID', ))]
fn test__approve_nonexistent() {
    ERC721::_approve(SPENDER(), TOKEN_ID());
}

///
/// set_approval_for_all & _set_approval_for_all
///

#[test]
#[available_gas(2000000)]
fn test_set_approval_for_all() {
    set_caller_address(OWNER());
    assert(!ERC721::is_approved_for_all(OWNER(), OPERATOR()), 'Invalid default value');

    ERC721::set_approval_for_all(OPERATOR(), true);
    assert(ERC721::is_approved_for_all(OWNER(), OPERATOR()), 'Operator not approved correctly');

    ERC721::set_approval_for_all(OPERATOR(), false);
    assert(!ERC721::is_approved_for_all(OWNER(), OPERATOR()), 'Operator not approved correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: self approval', ))]
fn test_set_approval_for_all_owner_equal_operator_true() {
    set_caller_address(OWNER());
    ERC721::set_approval_for_all(OWNER(), true);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: self approval', ))]
fn test_set_approval_for_all_owner_equal_operator_false() {
    set_caller_address(OWNER());
    ERC721::set_approval_for_all(OWNER(), false);
}

#[test]
#[available_gas(2000000)]
fn test__set_approval_for() {
    assert(!ERC721::is_approved_for_all(OWNER(), OPERATOR()), 'Invalid default value');

    ERC721::_set_approval_for_all(OWNER(), OPERATOR(), true);
    assert(ERC721::is_approved_for_all(OWNER(), OPERATOR()), 'Operator not approved correctly');

    ERC721::_set_approval_for_all(OWNER(), OPERATOR(), false);
    assert(!ERC721::is_approved_for_all(OWNER(), OPERATOR()), 'Operator not approved correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: self approval', ))]
fn test__set_approval_for_all_owner_equal_operator_true() {
    ERC721::_set_approval_for_all(OWNER(), OWNER(), true);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: self approval', ))]
fn test__set_approval_for_all_owner_equal_operator_false() {
    ERC721::_set_approval_for_all(OWNER(), OWNER(), false);
}

///
/// transfer_from
///

#[test]
#[available_gas(2000000)]
fn test_transfer_from_owner() {
    setup();

    // set approval to check reset
    ERC721::_approve(OTHER(), TOKEN_ID());

    assert(ERC721::owner_of(TOKEN_ID()) == OWNER(), 'Ownership before');
    assert(ERC721::balance_of(OWNER()) == 1.into(), 'Balance of owner before');
    assert(ERC721::balance_of(RECIPIENT()) == 0.into(), 'Balance of recipient before');
    assert(ERC721::get_approved(TOKEN_ID()) == OTHER(), 'Approval not implicitly reset');

    set_caller_address(OWNER());
    ERC721::transfer_from(OWNER(), RECIPIENT(), TOKEN_ID());

    assert(ERC721::owner_of(TOKEN_ID()) == RECIPIENT(), 'Ownership after');
    assert(ERC721::balance_of(OWNER()) == 0.into(), 'Balance of owner after');
    assert(ERC721::balance_of(RECIPIENT()) == 1.into(), 'Balance of recipient after');
    assert(ERC721::get_approved(TOKEN_ID()).is_zero(), 'Approval not implicitly reset');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: invalid token ID', ))]
fn test_transfer_from_nonexistent() {
    ERC721::transfer_from(ZERO(), RECIPIENT(), TOKEN_ID());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: invalid receiver', ))]
fn test_transfer_from_to_zero() {
    setup();

    set_caller_address(OWNER());
    ERC721::transfer_from(OWNER(), ZERO(), TOKEN_ID());
}

#[test]
#[available_gas(2000000)]
fn test_transfer_from_to_owner() {
    setup();

    assert(ERC721::owner_of(TOKEN_ID()) == OWNER(), 'Ownership before');
    assert(ERC721::balance_of(OWNER()) == 1.into(), 'Balance of owner before');

    set_caller_address(OWNER());
    ERC721::transfer_from(OWNER(), OWNER(), TOKEN_ID());

    assert(ERC721::owner_of(TOKEN_ID()) == OWNER(), 'Ownership after');
    assert(ERC721::balance_of(OWNER()) == 1.into(), 'Balance of owner after');
}

#[test]
#[available_gas(2000000)]
fn test_transfer_from_approved() {
    setup();

    assert(ERC721::owner_of(TOKEN_ID()) == OWNER(), 'Ownership before');
    assert(ERC721::balance_of(OWNER()) == 1.into(), 'Balance of owner before');
    assert(ERC721::balance_of(RECIPIENT()) == 0.into(), 'Balance of recipient before');

    set_caller_address(OWNER());
    ERC721::approve(OPERATOR(), TOKEN_ID());

    set_caller_address(OPERATOR());
    ERC721::transfer_from(OWNER(), RECIPIENT(), TOKEN_ID());

    assert(ERC721::owner_of(TOKEN_ID()) == RECIPIENT(), 'Ownership after');
    assert(ERC721::balance_of(OWNER()) == 0.into(), 'Balance of owner after');
    assert(ERC721::balance_of(RECIPIENT()) == 1.into(), 'Balance of recipient after');
    assert(ERC721::get_approved(TOKEN_ID()) == ZERO(), 'Approval not implicitly reset');
}

#[test]
#[available_gas(2000000)]
fn test_transfer_from_approved_for_all() {
    setup();

    assert(ERC721::owner_of(TOKEN_ID()) == OWNER(), 'Ownership before');
    assert(ERC721::balance_of(OWNER()) == 1.into(), 'Balance of owner before');
    assert(ERC721::balance_of(RECIPIENT()) == 0.into(), 'Balance of recipient before');

    set_caller_address(OWNER());
    ERC721::set_approval_for_all(OPERATOR(), true);

    set_caller_address(OPERATOR());
    ERC721::transfer_from(OWNER(), RECIPIENT(), TOKEN_ID());

    assert(ERC721::owner_of(TOKEN_ID()) == RECIPIENT(), 'Ownership after');
    assert(ERC721::balance_of(OWNER()) == 0.into(), 'Balance of owner after');
    assert(ERC721::balance_of(RECIPIENT()) == 1.into(), 'Balance of recipient after');
    assert(ERC721::get_approved(TOKEN_ID()) == ZERO(), 'Approval not implicitly reset');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: unauthorized caller', ))]
fn test_transfer_from_unauthorized() {
    setup();

    set_caller_address(OTHER());
    ERC721::transfer_from(OWNER(), RECIPIENT(), TOKEN_ID());
}

#[test]
#[available_gas(2000000)]
fn test__transfer() {
    setup();

    assert(ERC721::owner_of(TOKEN_ID()) == OWNER(), 'Ownership before');
    assert(ERC721::balance_of(OWNER()) == 1.into(), 'Balance of owner before');
    assert(ERC721::balance_of(RECIPIENT()) == 0.into(), 'Balance of recipient before');

    ERC721::_transfer(OWNER(), RECIPIENT(), TOKEN_ID());

    assert(ERC721::owner_of(TOKEN_ID()) == RECIPIENT(), 'Ownership after');
    assert(ERC721::balance_of(OWNER()) == 0.into(), 'Balance of owner after');
    assert(ERC721::balance_of(RECIPIENT()) == 1.into(), 'Balance of recipient after');
    assert(ERC721::get_approved(TOKEN_ID()) == ZERO(), 'Approval not implicitly reset');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: invalid token ID', ))]
fn test__transfer_nonexistent() {
    ERC721::_transfer(ZERO(), RECIPIENT(), TOKEN_ID());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: invalid receiver', ))]
fn test__transfer_to_zero() {
    setup();

    ERC721::_transfer(OWNER(), ZERO(), TOKEN_ID());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: wrong sender', ))]
fn test__transfer_from_invalid_owner() {
    setup();

    ERC721::_transfer(RECIPIENT(), OWNER(), TOKEN_ID());
}

///
/// Mint
///

#[test]
#[available_gas(2000000)]
fn test__mint() {
    assert(ERC721::balance_of(RECIPIENT()) == 0.into(), 'Balance of recipient before');

    ERC721::_mint(RECIPIENT(), TOKEN_ID());

    assert(ERC721::owner_of(TOKEN_ID()) == RECIPIENT(), 'Ownership after');
    assert(ERC721::balance_of(RECIPIENT()) == 1.into(), 'Balance of recipient after');
    assert(ERC721::get_approved(TOKEN_ID()) == ZERO(), 'Approval implicitly set');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: invalid receiver', ))]
fn test__mint_to_zero() {
    ERC721::_mint(ZERO(), TOKEN_ID());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: token already minted', ))]
fn test__mint_already_exist() {
    setup();

    ERC721::_mint(RECIPIENT(), TOKEN_ID());
}

///
/// Burn
///

#[test]
#[available_gas(2000000)]
fn test__burn() {
    setup();

    ERC721::_approve(OTHER(), TOKEN_ID());

    assert(ERC721::owner_of(TOKEN_ID()) == OWNER(), 'Ownership before');
    assert(ERC721::balance_of(OWNER()) == 1.into(), 'Balance of owner before');
    assert(ERC721::get_approved(TOKEN_ID()) == OTHER(), 'Approval before');

    ERC721::_burn(TOKEN_ID());

    assert(ERC721::_owners::read(TOKEN_ID()) == ZERO(), 'Ownership after');
    assert(ERC721::balance_of(OWNER()) == 0.into(), 'Balance of owner after');
    assert(ERC721::_token_approvals::read(TOKEN_ID()) == ZERO(), 'Approval after');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: invalid token ID', ))]
fn test__burn_nonexistent() {
    ERC721::_burn(TOKEN_ID());
}

///
/// _set_token_uri
///

#[test]
#[available_gas(2000000)]
fn test__set_token_uri() {
    setup();

    assert(ERC721::token_uri(TOKEN_ID()) == 0, 'URI should be 0');
    ERC721::_set_token_uri(TOKEN_ID(), URI);
    assert(ERC721::token_uri(TOKEN_ID()) == URI, 'URI should be set');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('ERC721: invalid token ID', ))]
fn test__set_token_uri_nonexistent() {
    ERC721::_set_token_uri(TOKEN_ID(), URI);
}
