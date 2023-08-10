use integer::BoundedInt;
use openzeppelin::token::erc20::presets::ERC20VotesPreset;
use openzeppelin::token::erc20::presets::ERC20VotesPreset::ERC20Impl;
use openzeppelin::token::erc20::presets::ERC20VotesPreset::VotesImpl;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing;
use traits::Into;
use zeroable::Zeroable;

//
// Constants
//

const NAME: felt252 = 111;
const SYMBOL: felt252 = 222;
const DECIMALS: u8 = 18_u8;
const SUPPLY: u256 = 2000;
const VALUE: u256 = 300;

fn STATE() -> ERC20VotesPreset::ContractState {
    ERC20VotesPreset::contract_state_for_testing()
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

fn setup() -> ERC20VotesPreset::ContractState {
    let mut state = STATE();
    ERC20VotesPreset::constructor(ref state, NAME, SYMBOL, SUPPLY, OWNER());
    state
}

//
// constructor
//

#[test]
#[available_gas(2000000)]
fn test_constructor() {
    let mut state = STATE();
    ERC20VotesPreset::constructor(ref state, NAME, SYMBOL, SUPPLY, OWNER());

    assert(ERC20Impl::balance_of(@state, OWNER()) == SUPPLY, 'Should eq inital_supply');
    assert(ERC20Impl::total_supply(@state) == SUPPLY, 'Should eq inital_supply');
    assert(ERC20Impl::name(@state) == NAME, 'Name should be NAME');
    assert(ERC20Impl::symbol(@state) == SYMBOL, 'Symbol should be SYMBOL');
    assert(ERC20Impl::decimals(@state) == DECIMALS, 'Decimals should be 18');
}

//
// Getters
//

#[test]
#[available_gas(2000000)]
fn test_total_supply() {
    let mut state = setup();
    assert(ERC20Impl::total_supply(@state) == SUPPLY, 'Should eq SUPPLY');
}

#[test]
#[available_gas(20000000)]
fn test_balance_of() {
    let mut state = setup();

    testing::set_caller_address(OWNER());
    ERC20Impl::transfer(ref state, RECIPIENT(), SUPPLY);
    assert(ERC20Impl::balance_of(@state, RECIPIENT()) == SUPPLY, 'Should eq SUPPLY');
}

#[test]
#[available_gas(2000000)]
fn test_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    ERC20Impl::approve(ref state, SPENDER(), VALUE);

    assert(ERC20Impl::allowance(@state, OWNER(), SPENDER()) == VALUE, 'Should eq VALUE');
}

//
// approve
//

#[test]
#[available_gas(2000000)]
fn test_approve() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    assert(ERC20Impl::approve(ref state, SPENDER(), VALUE), 'Should return true');
    assert(
        ERC20Impl::allowance(@state, OWNER(), SPENDER()) == VALUE, 'Spender not approved correctly'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve from 0', ))]
fn test_approve_from_zero() {
    let mut state = setup();
    ERC20Impl::approve(ref state, SPENDER(), VALUE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve to 0', ))]
fn test_approve_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    ERC20Impl::approve(ref state, Zeroable::zero(), VALUE);
}

//
// transfer
//

#[test]
#[available_gas(20000000)]
fn test_transfer() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    assert(ERC20Impl::transfer(ref state, RECIPIENT(), VALUE), 'Should return true');

    assert(ERC20Impl::balance_of(@state, RECIPIENT()) == VALUE, 'Balance should eq VALUE');
    assert(ERC20Impl::balance_of(@state, OWNER()) == SUPPLY - VALUE, 'Should eq supply - VALUE');
    assert(ERC20Impl::total_supply(@state) == SUPPLY, 'Total supply should not change');
}

//
// transfer_from
//

#[test]
#[available_gas(20000000)]
fn test_transfer_from() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    ERC20Impl::approve(ref state, SPENDER(), VALUE);

    testing::set_caller_address(SPENDER());
    assert(ERC20Impl::transfer_from(ref state, OWNER(), RECIPIENT(), VALUE), 'Should return true');

    assert(ERC20Impl::balance_of(@state, RECIPIENT()) == VALUE, 'Should eq amount');
    assert(ERC20Impl::balance_of(@state, OWNER()) == SUPPLY - VALUE, 'Should eq suppy - amount');
    assert(ERC20Impl::allowance(@state, OWNER(), SPENDER()) == 0, 'Should eq 0');
    assert(ERC20Impl::total_supply(@state) == SUPPLY, 'Total supply should not change');
}

#[test]
#[available_gas(20000000)]
fn test_transfer_from_doesnt_consume_infinite_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    ERC20Impl::approve(ref state, SPENDER(), BoundedInt::max());

    testing::set_caller_address(SPENDER());
    ERC20Impl::transfer_from(ref state, OWNER(), RECIPIENT(), VALUE);

    assert(
        ERC20Impl::allowance(@state, OWNER(), SPENDER()) == BoundedInt::max(),
        'Allowance should not change'
    );
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('u256_sub Overflow', ))]
fn test_transfer_from_greater_than_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    ERC20Impl::approve(ref state, SPENDER(), VALUE);

    testing::set_caller_address(SPENDER());
    let allowance_plus_one = VALUE + 1;
    ERC20Impl::transfer_from(ref state, OWNER(), RECIPIENT(), allowance_plus_one);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC20: transfer to 0', ))]
fn test_transfer_from_to_zero_address() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    ERC20Impl::approve(ref state, SPENDER(), VALUE);

    testing::set_caller_address(SPENDER());
    ERC20Impl::transfer_from(ref state, OWNER(), Zeroable::zero(), VALUE);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('u256_sub Overflow', ))]
fn test_transfer_from_from_zero_address() {
    let mut state = setup();
    ERC20Impl::transfer_from(ref state, Zeroable::zero(), RECIPIENT(), VALUE);
}

//
// increase_allowance
//

#[test]
#[available_gas(2000000)]
fn test_increase_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    ERC20Impl::approve(ref state, SPENDER(), VALUE);

    assert(ERC20VotesPreset::increase_allowance(ref state, SPENDER(), VALUE), 'Should return true');
    assert(ERC20Impl::allowance(@state, OWNER(), SPENDER()) == VALUE * 2, 'Should be amount * 2');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve to 0', ))]
fn test_increase_allowance_to_zero_address() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    ERC20VotesPreset::increase_allowance(ref state, Zeroable::zero(), VALUE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve from 0', ))]
fn test_increase_allowance_from_zero_address() {
    let mut state = setup();
    ERC20VotesPreset::increase_allowance(ref state, SPENDER(), VALUE);
}

//
// decrease_allowance
//

#[test]
#[available_gas(2000000)]
fn test_decrease_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    ERC20Impl::approve(ref state, SPENDER(), VALUE);

    assert(ERC20VotesPreset::decrease_allowance(ref state, SPENDER(), VALUE), 'Should return true');
    assert(ERC20Impl::allowance(@state, OWNER(), SPENDER()) == VALUE - VALUE, 'Should be 0');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow', ))]
fn test_decrease_allowance_to_zero_address() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    ERC20VotesPreset::decrease_allowance(ref state, Zeroable::zero(), VALUE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow', ))]
fn test_decrease_allowance_from_zero_address() {
    let mut state = setup();
    ERC20VotesPreset::decrease_allowance(ref state, SPENDER(), VALUE);
}

//
// get_votes
//

#[test]
#[available_gas(20000000)]
fn test_get_votes() {
    let mut state = setup();

    testing::set_caller_address(OWNER());
    VotesImpl::delegate(ref state, OWNER());

    assert(VotesImpl::get_votes(@state, OWNER()) == SUPPLY, 'Should eq SUPPLY');
}
