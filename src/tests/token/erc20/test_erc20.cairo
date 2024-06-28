use core::integer::BoundedInt;
use openzeppelin::tests::mocks::erc20_mocks::DualCaseERC20Mock;
use openzeppelin::tests::utils::constants::{
    ZERO, OWNER, SPENDER, RECIPIENT, NAME, SYMBOL, DECIMALS, SUPPLY, VALUE
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::ERC20Component::{ERC20CamelOnlyImpl, ERC20Impl};
use openzeppelin::token::erc20::ERC20Component::{ERC20MetadataImpl, InternalImpl};
use openzeppelin::token::erc20::ERC20Component;
use snforge_std::{test_address, start_cheat_caller_address};
use starknet::ContractAddress;

use super::common::{assert_event_approval, assert_only_event_approval, assert_only_event_transfer};

//
// Setup
//

type ComponentState = ERC20Component::ComponentState<DualCaseERC20Mock::ContractState>;

fn COMPONENT_STATE() -> ComponentState {
    ERC20Component::component_state_for_testing()
}

fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    state.initializer(NAME(), SYMBOL());
    state.mint(OWNER(), SUPPLY);
    state
}

//
// initializer & constructor
//

#[test]
fn test_initializer() {
    let mut state = COMPONENT_STATE();
    state.initializer(NAME(), SYMBOL());

    assert_eq!(state.name(), NAME());
    assert_eq!(state.symbol(), SYMBOL());
    assert_eq!(state.decimals(), DECIMALS);
    assert_eq!(state.total_supply(), 0);
}

//
// Getters
//

#[test]
fn test_total_supply() {
    let mut state = COMPONENT_STATE();
    state.mint(OWNER(), SUPPLY);
    assert_eq!(state.total_supply(), SUPPLY);
}

#[test]
fn test_totalSupply() {
    let mut state = COMPONENT_STATE();
    state.mint(OWNER(), SUPPLY);
    assert_eq!(state.totalSupply(), SUPPLY);
}

#[test]
fn test_balance_of() {
    let mut state = COMPONENT_STATE();
    state.mint(OWNER(), SUPPLY);
    assert_eq!(state.balance_of(OWNER()), SUPPLY);
}

#[test]
fn test_balanceOf() {
    let mut state = COMPONENT_STATE();
    state.mint(OWNER(), SUPPLY);
    assert_eq!(state.balanceOf(OWNER()), SUPPLY);
}

#[test]
fn test_allowance() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OWNER());
    state.approve(SPENDER(), VALUE);

    let allowance = state.allowance(OWNER(), SPENDER());
    assert_eq!(allowance, VALUE);
}

//
// approve & _approve
//

#[test]
fn test_approve() {
    let mut state = setup();
    let contract_address = test_address();
    let mut spy = utils::spy_on(contract_address);

    start_cheat_caller_address(contract_address, OWNER());
    assert!(state.approve(SPENDER(), VALUE));

    assert_only_event_approval(ref spy, contract_address, OWNER(), SPENDER(), VALUE);

    let allowance = state.allowance(OWNER(), SPENDER());
    assert_eq!(allowance, VALUE);
}

#[test]
#[should_panic(expected: ('ERC20: approve from 0',))]
fn test_approve_from_zero() {
    let mut state = setup();
    state.approve(SPENDER(), VALUE);
}

#[test]
#[should_panic(expected: ('ERC20: approve to 0',))]
fn test_approve_to_zero() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OWNER());
    state.approve(ZERO(), VALUE);
}

#[test]
fn test__approve() {
    let mut state = setup();
    let contract_address = test_address();
    let mut spy = utils::spy_on(contract_address);

    start_cheat_caller_address(contract_address, OWNER());
    state._approve(OWNER(), SPENDER(), VALUE);

    assert_only_event_approval(ref spy, contract_address, OWNER(), SPENDER(), VALUE);

    let allowance = state.allowance(OWNER(), SPENDER());
    assert_eq!(allowance, VALUE);
}

#[test]
#[should_panic(expected: ('ERC20: approve from 0',))]
fn test__approve_from_zero() {
    let mut state = setup();
    state._approve(ZERO(), SPENDER(), VALUE);
}

#[test]
#[should_panic(expected: ('ERC20: approve to 0',))]
fn test__approve_to_zero() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OWNER());
    state._approve(OWNER(), ZERO(), VALUE);
}

//
// transfer & _transfer
//

#[test]
fn test_transfer() {
    let mut state = setup();
    let contract_address = test_address();
    let mut spy = utils::spy_on(contract_address);

    start_cheat_caller_address(contract_address, OWNER());
    assert!(state.transfer(RECIPIENT(), VALUE));

    assert_only_event_transfer(ref spy, contract_address, OWNER(), RECIPIENT(), VALUE);
    assert_eq!(state.balance_of(RECIPIENT()), VALUE);
    assert_eq!(state.balance_of(OWNER()), SUPPLY - VALUE);
    assert_eq!(state.total_supply(), SUPPLY);
}

#[test]
#[should_panic(expected: ('ERC20: insufficient balance',))]
fn test_transfer_not_enough_balance() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OWNER());

    let balance_plus_one = SUPPLY + 1;
    state.transfer(RECIPIENT(), balance_plus_one);
}

#[test]
#[should_panic(expected: ('ERC20: transfer from 0',))]
fn test_transfer_from_zero() {
    let mut state = setup();
    state.transfer(RECIPIENT(), VALUE);
}

#[test]
#[should_panic(expected: ('ERC20: transfer to 0',))]
fn test_transfer_to_zero() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OWNER());
    state.transfer(ZERO(), VALUE);
}

#[test]
fn test__transfer() {
    let mut state = setup();
    let contract_address = test_address();
    let mut spy = utils::spy_on(contract_address);

    state._transfer(OWNER(), RECIPIENT(), VALUE);

    assert_only_event_transfer(ref spy, contract_address, OWNER(), RECIPIENT(), VALUE);
    assert_eq!(state.balance_of(RECIPIENT()), VALUE);
    assert_eq!(state.balance_of(OWNER()), SUPPLY - VALUE);
    assert_eq!(state.total_supply(), SUPPLY);
}

#[test]
#[should_panic(expected: ('ERC20: insufficient balance',))]
fn test__transfer_not_enough_balance() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OWNER());

    let balance_plus_one = SUPPLY + 1;
    state._transfer(OWNER(), RECIPIENT(), balance_plus_one);
}

#[test]
#[should_panic(expected: ('ERC20: transfer from 0',))]
fn test__transfer_from_zero() {
    let mut state = setup();
    state._transfer(ZERO(), RECIPIENT(), VALUE);
}

#[test]
#[should_panic(expected: ('ERC20: transfer to 0',))]
fn test__transfer_to_zero() {
    let mut state = setup();
    state._transfer(OWNER(), ZERO(), VALUE);
}

//
// transfer_from & transferFrom
//

#[test]
fn test_transfer_from() {
    let mut state = setup();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, OWNER());
    state.approve(SPENDER(), VALUE);

    let mut spy = utils::spy_on(contract_address);
    start_cheat_caller_address(contract_address, SPENDER());
    assert!(state.transfer_from(OWNER(), RECIPIENT(), VALUE));

    assert_event_approval(ref spy, contract_address, OWNER(), SPENDER(), 0);
    assert_only_event_transfer(ref spy, contract_address, OWNER(), RECIPIENT(), VALUE);

    let allowance = state.allowance(OWNER(), SPENDER());
    assert_eq!(allowance, 0);

    assert_eq!(state.balance_of(RECIPIENT()), VALUE);
    assert_eq!(state.balance_of(OWNER()), SUPPLY - VALUE);
    assert_eq!(state.total_supply(), SUPPLY);
}

#[test]
fn test_transfer_from_doesnt_consume_infinite_allowance() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OWNER());
    state.approve(SPENDER(), BoundedInt::max());

    start_cheat_caller_address(test_address(), SPENDER());
    state.transfer_from(OWNER(), RECIPIENT(), VALUE);

    let allowance = state.allowance(OWNER(), SPENDER());
    assert_eq!(allowance, BoundedInt::max());
}

#[test]
#[should_panic(expected: ('ERC20: insufficient allowance',))]
fn test_transfer_from_greater_than_allowance() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OWNER());
    state.approve(SPENDER(), VALUE);

    start_cheat_caller_address(test_address(), SPENDER());
    let allowance_plus_one = VALUE + 1;
    state.transfer_from(OWNER(), RECIPIENT(), allowance_plus_one);
}

#[test]
#[should_panic(expected: ('ERC20: transfer to 0',))]
fn test_transfer_from_to_zero_address() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OWNER());
    state.approve(SPENDER(), VALUE);

    start_cheat_caller_address(test_address(), SPENDER());
    state.transfer_from(OWNER(), ZERO(), VALUE);
}

#[test]
#[should_panic(expected: ('ERC20: insufficient allowance',))]
fn test_transfer_from_from_zero_address() {
    let mut state = setup();
    state.transfer_from(ZERO(), RECIPIENT(), VALUE);
}

#[test]
fn test_transferFrom() {
    let mut state = setup();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, OWNER());
    state.approve(SPENDER(), VALUE);

    let mut spy = utils::spy_on(contract_address);
    start_cheat_caller_address(contract_address, SPENDER());
    assert!(state.transferFrom(OWNER(), RECIPIENT(), VALUE));

    assert_event_approval(ref spy, contract_address, OWNER(), SPENDER(), 0);
    assert_only_event_transfer(ref spy, contract_address, OWNER(), RECIPIENT(), VALUE);

    let allowance = state.allowance(OWNER(), SPENDER());
    assert_eq!(allowance, 0);

    assert_eq!(state.balance_of(RECIPIENT()), VALUE);
    assert_eq!(state.balance_of(OWNER()), SUPPLY - VALUE);
    assert_eq!(state.total_supply(), SUPPLY);
    assert_eq!(allowance, 0);
}

#[test]
fn test_transferFrom_doesnt_consume_infinite_allowance() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OWNER());
    state.approve(SPENDER(), BoundedInt::max());

    start_cheat_caller_address(test_address(), SPENDER());
    state.transferFrom(OWNER(), RECIPIENT(), VALUE);

    let allowance = state.allowance(OWNER(), SPENDER());
    assert_eq!(allowance, BoundedInt::max());
}

#[test]
#[should_panic(expected: ('ERC20: insufficient allowance',))]
fn test_transferFrom_greater_than_allowance() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OWNER());
    state.approve(SPENDER(), VALUE);

    start_cheat_caller_address(test_address(), SPENDER());
    let allowance_plus_one = VALUE + 1;
    state.transferFrom(OWNER(), RECIPIENT(), allowance_plus_one);
}

#[test]
#[should_panic(expected: ('ERC20: transfer to 0',))]
fn test_transferFrom_to_zero_address() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OWNER());
    state.approve(SPENDER(), VALUE);

    start_cheat_caller_address(test_address(), SPENDER());
    state.transferFrom(OWNER(), ZERO(), VALUE);
}

#[test]
#[should_panic(expected: ('ERC20: insufficient allowance',))]
fn test_transferFrom_from_zero_address() {
    let mut state = setup();
    state.transferFrom(ZERO(), RECIPIENT(), VALUE);
}

//
// _spend_allowance
//

#[test]
fn test__spend_allowance_not_unlimited() {
    let mut state = setup();
    let contract_address = test_address();

    state._approve(OWNER(), SPENDER(), SUPPLY);

    let mut spy = utils::spy_on(contract_address);
    state._spend_allowance(OWNER(), SPENDER(), VALUE);

    assert_only_event_approval(ref spy, contract_address, OWNER(), SPENDER(), SUPPLY - VALUE);

    let allowance = state.allowance(OWNER(), SPENDER());
    assert_eq!(allowance, SUPPLY - VALUE);
}

#[test]
fn test__spend_allowance_unlimited() {
    let mut state = setup();
    state._approve(OWNER(), SPENDER(), BoundedInt::max());

    let max_minus_one: u256 = BoundedInt::max() - 1;
    state._spend_allowance(OWNER(), SPENDER(), max_minus_one);

    let allowance = state.allowance(OWNER(), SPENDER());
    assert_eq!(allowance, BoundedInt::max());
}

//
// mint
//

#[test]
fn test_mint() {
    let mut state = COMPONENT_STATE();
    let contract_address = test_address();

    let mut spy = utils::spy_on(contract_address);
    state.mint(OWNER(), VALUE);

    assert_only_event_transfer(ref spy, contract_address, ZERO(), OWNER(), VALUE);
    assert_eq!(state.balance_of(OWNER()), VALUE);
    assert_eq!(state.total_supply(), VALUE);
}

#[test]
#[should_panic(expected: ('ERC20: mint to 0',))]
fn test_mint_to_zero() {
    let mut state = COMPONENT_STATE();
    state.mint(ZERO(), VALUE);
}

//
// burn
//

#[test]
fn test_burn() {
    let mut state = setup();
    let contract_address = test_address();

    let mut spy = utils::spy_on(contract_address);
    state.burn(OWNER(), VALUE);

    assert_only_event_transfer(ref spy, contract_address, OWNER(), ZERO(), VALUE);
    assert_eq!(state.total_supply(), SUPPLY - VALUE);
    assert_eq!(state.balance_of(OWNER()), SUPPLY - VALUE);
}

#[test]
#[should_panic(expected: ('ERC20: burn from 0',))]
fn test_burn_from_zero() {
    let mut state = setup();
    state.burn(ZERO(), VALUE);
}
