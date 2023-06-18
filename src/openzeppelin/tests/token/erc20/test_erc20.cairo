use openzeppelin::token::erc20::ERC20;
use integer::BoundedInt;
use integer::u256;
use integer::u256_from_felt252;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing::set_caller_address;
use traits::Into;
use zeroable::Zeroable;

//
// Constants
//

const NAME: felt252 = 111;
const SYMBOL: felt252 = 222;
const DECIMALS: u8 = 18_u8;

fn SUPPLY() -> u256 {
    2000_u256
}

fn VALUE() -> u256 {
    300_u256
}

fn OWNER() -> ContractAddress {
    contract_address_const::<1>()
}

fn SPENDER() -> ContractAddress {
    contract_address_const::<2>()
}

fn RECIPIENT() -> ContractAddress {
    contract_address_const::<3>()
}

//
// Setup
//

fn setup() {
    ERC20::constructor(NAME, SYMBOL, SUPPLY(), OWNER());
}

//
// initializer & constructor
//

#[test]
#[available_gas(2000000)]
fn test_initializer() {
    ERC20::initializer(NAME, SYMBOL);

    assert(ERC20::name() == NAME, 'Name should be NAME');
    assert(ERC20::symbol() == SYMBOL, 'Symbol should be SYMBOL');
    assert(ERC20::decimals() == DECIMALS, 'Decimals should be 18');
    assert(ERC20::total_supply() == 0.into(), 'Supply should eq 0');
}


#[test]
#[available_gas(2000000)]
fn test_constructor() {
    ERC20::constructor(NAME, SYMBOL, SUPPLY(), OWNER());

    assert(ERC20::balance_of(OWNER()) == SUPPLY(), 'Should eq inital_supply');
    assert(ERC20::total_supply() == SUPPLY(), 'Should eq inital_supply');
    assert(ERC20::name() == NAME, 'Name should be NAME');
    assert(ERC20::symbol() == SYMBOL, 'Symbol should be SYMBOL');
    assert(ERC20::decimals() == DECIMALS, 'Decimals should be 18');
}

//
// Getters
//

#[test]
#[available_gas(2000000)]
fn test_total_supply() {
    ERC20::_mint(OWNER(), SUPPLY());
    assert(ERC20::total_supply() == SUPPLY(), 'Should eq SUPPLY');
}

#[test]
#[available_gas(2000000)]
fn test_totalSupply() {
    ERC20::_mint(OWNER(), SUPPLY());
    assert(ERC20::totalSupply() == SUPPLY(), 'Should eq SUPPLY');
}

#[test]
#[available_gas(2000000)]
fn test_balance_of() {
    ERC20::_mint(OWNER(), SUPPLY());
    assert(ERC20::balance_of(OWNER()) == SUPPLY(), 'Should eq SUPPLY');
}

#[test]
#[available_gas(2000000)]
fn test_balanceOf() {
    ERC20::_mint(OWNER(), SUPPLY());
    assert(ERC20::balanceOf(OWNER()) == SUPPLY(), 'Should eq SUPPLY');
}

#[test]
#[available_gas(2000000)]
fn test_allowance() {
    setup();
    set_caller_address(OWNER());
    ERC20::approve(SPENDER(), VALUE());

    assert(ERC20::allowance(OWNER(), SPENDER()) == VALUE(), 'Should eq VALUE');
}

//
// approve & _approve
//

#[test]
#[available_gas(2000000)]
fn test_approve() {
    setup();
    set_caller_address(OWNER());
    assert(ERC20::approve(SPENDER(), VALUE()), 'Should return true');

    assert(ERC20::allowance(OWNER(), SPENDER()) == VALUE(), 'Spender not approved correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve from 0', ))]
fn test_approve_from_zero() {
    setup();
    ERC20::approve(SPENDER(), VALUE());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve to 0', ))]
fn test_approve_to_zero() {
    setup();
    set_caller_address(OWNER());
    ERC20::approve(Zeroable::zero(), VALUE());
}

#[test]
#[available_gas(2000000)]
fn test__approve() {
    setup();
    set_caller_address(OWNER());
    ERC20::_approve(OWNER(), SPENDER(), VALUE());

    assert(ERC20::allowance(OWNER(), SPENDER()) == VALUE(), 'Spender not approved correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve from 0', ))]
fn test__approve_from_zero() {
    setup();
    ERC20::_approve(Zeroable::zero(), SPENDER(), VALUE());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve to 0', ))]
fn test__approve_to_zero() {
    setup();
    set_caller_address(OWNER());
    ERC20::_approve(OWNER(), Zeroable::zero(), VALUE());
}

//
// transfer & _transfer
//

#[test]
#[available_gas(2000000)]
fn test_transfer() {
    setup();
    set_caller_address(OWNER());
    assert(ERC20::transfer(RECIPIENT(), VALUE()), 'Should return true');

    assert(ERC20::balance_of(RECIPIENT()) == VALUE(), 'Balance should eq VALUE');
    assert(ERC20::balance_of(OWNER()) == SUPPLY() - VALUE(), 'Should eq supply - VALUE');
    assert(ERC20::total_supply() == SUPPLY(), 'Total supply should not change');
}

#[test]
#[available_gas(2000000)]
fn test__transfer() {
    setup();

    ERC20::_transfer(OWNER(), RECIPIENT(), VALUE());
    assert(ERC20::balance_of(RECIPIENT()) == VALUE(), 'Balance should eq amount');
    assert(ERC20::balance_of(OWNER()) == SUPPLY() - VALUE(), 'Should eq supply - amount');
    assert(ERC20::total_supply() == SUPPLY(), 'Total supply should not change');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow', ))]
fn test__transfer_not_enough_balance() {
    setup();
    set_caller_address(OWNER());

    let balance_plus_one = SUPPLY() + 1.into();
    ERC20::_transfer(OWNER(), RECIPIENT(), balance_plus_one);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: transfer from 0', ))]
fn test__transfer_from_zero() {
    setup();
    ERC20::_transfer(Zeroable::zero(), RECIPIENT(), VALUE());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: transfer to 0', ))]
fn test__transfer_to_zero() {
    setup();
    ERC20::_transfer(OWNER(), Zeroable::zero(), VALUE());
}

//
// transfer_from & transferFrom
//

#[test]
#[available_gas(2000000)]
fn test_transfer_from() {
    setup();
    set_caller_address(OWNER());
    ERC20::approve(SPENDER(), VALUE());

    set_caller_address(SPENDER());
    assert(ERC20::transfer_from(OWNER(), RECIPIENT(), VALUE()), 'Should return true');

    assert(ERC20::balance_of(RECIPIENT()) == VALUE(), 'Should eq amount');
    assert(ERC20::balance_of(OWNER()) == SUPPLY() - VALUE(), 'Should eq suppy - amount');
    assert(ERC20::allowance(OWNER(), SPENDER()) == 0.into(), 'Should eq 0');
    assert(ERC20::total_supply() == SUPPLY(), 'Total supply should not change');
}

#[test]
#[available_gas(2000000)]
fn test_transfer_from_doesnt_consume_infinite_allowance() {
    setup();
    set_caller_address(OWNER());
    ERC20::approve(SPENDER(), BoundedInt::max());

    set_caller_address(SPENDER());
    ERC20::transfer_from(OWNER(), RECIPIENT(), VALUE());

    assert(
        ERC20::allowance(OWNER(), SPENDER()) == BoundedInt::max(), 'Allowance should not change'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow', ))]
fn test_transfer_from_greater_than_allowance() {
    setup();
    set_caller_address(OWNER());
    ERC20::approve(SPENDER(), VALUE());

    set_caller_address(SPENDER());
    let allowance_plus_one = VALUE() + 1.into();
    ERC20::transfer_from(OWNER(), RECIPIENT(), allowance_plus_one);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: transfer to 0', ))]
fn test_transfer_from_to_zero_address() {
    setup();
    set_caller_address(OWNER());
    ERC20::approve(SPENDER(), VALUE());

    set_caller_address(SPENDER());
    ERC20::transfer_from(OWNER(), Zeroable::zero(), VALUE());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow', ))]
fn test_transfer_from_from_zero_address() {
    setup();
    ERC20::transfer_from(Zeroable::zero(), RECIPIENT(), VALUE());
}

#[test]
#[available_gas(2000000)]
fn test_transferFrom() {
    setup();
    set_caller_address(OWNER());
    ERC20::approve(SPENDER(), VALUE());

    set_caller_address(SPENDER());
    assert(ERC20::transferFrom(OWNER(), RECIPIENT(), VALUE()), 'Should return true');

    assert(ERC20::balanceOf(RECIPIENT()) == VALUE(), 'Should eq amount');
    assert(ERC20::balanceOf(OWNER()) == SUPPLY() - VALUE(), 'Should eq suppy - amount');
    assert(ERC20::allowance(OWNER(), SPENDER()) == 0.into(), 'Should eq 0');
    assert(ERC20::totalSupply() == SUPPLY(), 'Total supply should not change');
}

#[test]
#[available_gas(2000000)]
fn test_transferFrom_doesnt_consume_infinite_allowance() {
    setup();
    set_caller_address(OWNER());
    ERC20::approve(SPENDER(), BoundedInt::max());

    set_caller_address(SPENDER());
    ERC20::transferFrom(OWNER(), RECIPIENT(), VALUE());

    assert(
        ERC20::allowance(OWNER(), SPENDER()) == BoundedInt::max(), 'Allowance should not change'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow', ))]
fn test_transferFrom_greater_than_allowance() {
    setup();
    set_caller_address(OWNER());
    ERC20::approve(SPENDER(), VALUE());

    set_caller_address(SPENDER());
    let allowance_plus_one = VALUE() + 1.into();
    ERC20::transferFrom(OWNER(), RECIPIENT(), allowance_plus_one);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: transfer to 0', ))]
fn test_transferFrom_to_zero_address() {
    setup();
    set_caller_address(OWNER());
    ERC20::approve(SPENDER(), VALUE());

    set_caller_address(SPENDER());
    ERC20::transferFrom(OWNER(), Zeroable::zero(), VALUE());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow', ))]
fn test_transferFrom_from_zero_address() {
    setup();
    ERC20::transferFrom(Zeroable::zero(), RECIPIENT(), VALUE());
}

//
// increase_allowance & increaseAllowance
//

#[test]
#[available_gas(2000000)]
fn test_increase_allowance() {
    setup();
    set_caller_address(OWNER());
    ERC20::approve(SPENDER(), VALUE());

    assert(ERC20::increase_allowance(SPENDER(), VALUE()), 'Should return true');
    assert(ERC20::allowance(OWNER(), SPENDER()) == VALUE() * 2.into(), 'Should be amount * 2');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve to 0', ))]
fn test_increase_allowance_to_zero_address() {
    setup();
    set_caller_address(OWNER());
    ERC20::increase_allowance(Zeroable::zero(), VALUE());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve from 0', ))]
fn test_increase_allowance_from_zero_address() {
    setup();
    ERC20::increase_allowance(SPENDER(), VALUE());
}

#[test]
#[available_gas(2000000)]
fn test_increaseAllowance() {
    setup();
    set_caller_address(OWNER());
    ERC20::approve(SPENDER(), VALUE());

    assert(ERC20::increaseAllowance(SPENDER(), VALUE()), 'Should return true');
    assert(ERC20::allowance(OWNER(), SPENDER()) == VALUE() * 2.into(), 'Should be amount * 2');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve to 0', ))]
fn test_increaseAllowance_to_zero_address() {
    setup();
    set_caller_address(OWNER());
    ERC20::increaseAllowance(Zeroable::zero(), VALUE());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve from 0', ))]
fn test_increaseAllowance_from_zero_address() {
    setup();
    ERC20::increaseAllowance(SPENDER(), VALUE());
}

//
// decrease_allowance & decreaseAllowance
//

#[test]
#[available_gas(2000000)]
fn test_decrease_allowance() {
    setup();
    set_caller_address(OWNER());
    ERC20::approve(SPENDER(), VALUE());

    assert(ERC20::decrease_allowance(SPENDER(), VALUE()), 'Should return true');
    assert(ERC20::allowance(OWNER(), SPENDER()) == VALUE() - VALUE(), 'Should be 0');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow', ))]
fn test_decrease_allowance_to_zero_address() {
    setup();
    set_caller_address(OWNER());
    ERC20::decrease_allowance(Zeroable::zero(), VALUE());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow', ))]
fn test_decrease_allowance_from_zero_address() {
    setup();
    ERC20::decrease_allowance(SPENDER(), VALUE());
}

#[test]
#[available_gas(2000000)]
fn test_decreaseAllowance() {
    setup();
    set_caller_address(OWNER());
    ERC20::approve(SPENDER(), VALUE());

    assert(ERC20::decreaseAllowance(SPENDER(), VALUE()), 'Should return true');
    assert(ERC20::allowance(OWNER(), SPENDER()) == VALUE() - VALUE(), 'Should be 0');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow', ))]
fn test_decreaseAllowance_to_zero_address() {
    setup();
    set_caller_address(OWNER());
    ERC20::decreaseAllowance(Zeroable::zero(), VALUE());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow', ))]
fn test_decreaseAllowance_from_zero_address() {
    setup();
    ERC20::decreaseAllowance(SPENDER(), VALUE());
}

//
// _spend_allowance
//

#[test]
#[available_gas(2000000)]
fn test__spend_allowance_not_unlimited() {
    setup();

    ERC20::_approve(OWNER(), SPENDER(), SUPPLY());
    ERC20::_spend_allowance(OWNER(), SPENDER(), VALUE());
    assert(ERC20::allowance(OWNER(), SPENDER()) == SUPPLY() - VALUE(), 'Should eq supply - amount');
}

#[test]
#[available_gas(2000000)]
fn test__spend_allowance_unlimited() {
    setup();
    ERC20::_approve(OWNER(), SPENDER(), BoundedInt::max());

    let max_minus_one: u256 = BoundedInt::max() - 1.into();
    ERC20::_spend_allowance(OWNER(), SPENDER(), max_minus_one);

    assert(
        ERC20::allowance(OWNER(), SPENDER()) == BoundedInt::max(), 'Allowance should not change'
    );
}

//
// _mint
//

#[test]
#[available_gas(2000000)]
fn test__mint() {
    ERC20::_mint(OWNER(), VALUE());

    assert(ERC20::balance_of(OWNER()) == VALUE(), 'Should eq amount');
    assert(ERC20::total_supply() == VALUE(), 'Should eq total supply');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: mint to 0', ))]
fn test__mint_to_zero() {
    ERC20::_mint(Zeroable::zero(), VALUE());
}

//
// _burn
//

#[test]
#[available_gas(2000000)]
fn test__burn() {
    setup();
    ERC20::_burn(OWNER(), VALUE());

    assert(ERC20::total_supply() == SUPPLY() - VALUE(), 'Should eq supply - amount');
    assert(ERC20::balance_of(OWNER()) == SUPPLY() - VALUE(), 'Should eq supply - amount');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: burn from 0', ))]
fn test__burn_from_zero() {
    setup();
    ERC20::_burn(Zeroable::zero(), VALUE());
}
