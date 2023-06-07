use array::ArrayTrait;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing::set_caller_address;
use openzeppelin::token::erc721::ERC721;
use openzeppelin::token::erc721::dual721::DualERC721;
use openzeppelin::token::erc721::dual721::DualERC721Trait;
use openzeppelin::tests::utils;

///
/// Constants
///

const NAME: felt252 = 111;
const SYMBOL: felt252 = 222;
const URI: felt252 = 333;

fn ZERO() -> ContractAddress {
    Zeroable::zero()
}
fn OWNER() -> ContractAddress {
    contract_address_const::<10>()
}

///
/// Setup
///

fn setup_snake_target() -> DualERC721 {
    let mut calldata = ArrayTrait::new();
    calldata.append(NAME);
    calldata.append(SYMBOL);
    set_caller_address(OWNER());
    let target = utils::deploy(ERC721::TEST_CLASS_HASH, calldata);
    DualERC721 { target: target }
}

fn setup_camel_target() -> DualERC721 {
    let mut calldata = ArrayTrait::new();
    calldata.append(NAME);
    calldata.append(SYMBOL);
    set_caller_address(OWNER());
    let target = utils::deploy(ERC721::TEST_CLASS_HASH, calldata);
    DualERC721 { target: target }
}

///
/// case agnostic methods
///

#[test]
#[available_gas(2000000)]
fn test_dual_name() {
}

#[test]
#[available_gas(2000000)]
fn test_dual_symbol() {
}

#[test]
#[available_gas(2000000)]
fn test_dual_approve() {
}

///
/// snake_case target
///

#[test]
#[available_gas(2000000)]
fn test_dual_balance_of() {
    let dual721 = setup_snake_target();
    assert(dual721.balance_of(OWNER()) == 0, 'Should return balance');
}

#[test]
#[available_gas(2000000)]
fn test_dual_owner_of() {
    let dual721 = setup_snake_target();
}

#[test]
#[available_gas(2000000)]
fn test_dual_transfer_from() {
    let dual721 = setup_snake_target();
}

#[test]
#[available_gas(2000000)]
fn test_dual_safe_transfer_from() {
    let dual721 = setup_snake_target();
}

#[test]
#[available_gas(2000000)]
fn test_dual_get_approved() {
    let dual721 = setup_snake_target();
}

#[test]
#[available_gas(2000000)]
fn test_dual_set_approval_for_all() {
    let dual721 = setup_snake_target();
}

#[test]
#[available_gas(2000000)]
fn test_dual_is_approved_for_all() {
    let dual721 = setup_snake_target();
}

#[test]
#[available_gas(2000000)]
fn test_dual_token_uri() {
    let dual721 = setup_snake_target();
}

///
/// camelCase target
///

#[test]
#[available_gas(2000000)]
fn test_dual_balanceOf() {
    let dual721 = setup_camel_target();
    assert(dual721.balance_of(OWNER()) == 0, 'Should return balance');
}

#[test]
#[available_gas(2000000)]
fn test_dual_ownerOf() {
}

#[test]
#[available_gas(2000000)]
fn test_dual_transfeFrom() {
}

#[test]
#[available_gas(2000000)]
fn test_dual_safeTransferFrom() {
}

#[test]
#[available_gas(2000000)]
fn test_dual_getApproved() {
}

#[test]
#[available_gas(2000000)]
fn test_dual_setApprovalForAll() {
}

#[test]
#[available_gas(2000000)]
fn test_dual_isApprovedForAll() {
}

#[test]
#[available_gas(2000000)]
fn test_dualTokenUri() {
}

///
/// failures
///

#[test]
#[available_gas(2000000)]
fn test_dual_non_existent() {
}

#[test]
#[available_gas(2000000)]
fn test_dual_exists_but_reverts() {
}
