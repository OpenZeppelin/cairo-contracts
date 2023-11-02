use integer::BoundedInt;
use openzeppelin::tests::mocks::erc20_mocks::DualCaseERC20;
use openzeppelin::tests::utils::constants::{
    ZERO, OWNER, SPENDER, RECIPIENT, NAME, SYMBOL, DECIMALS, SUPPLY, VALUE
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::ERC20Component::{Approval, Transfer};
use openzeppelin::token::erc20::ERC20Component::{ERC20CamelOnlyImpl, ERC20Impl};
use openzeppelin::token::erc20::ERC20Component::{ERC20MetadataImpl, InternalImpl};
use openzeppelin::token::erc20::ERC20Component::{SafeAllowanceImpl, SafeAllowanceCamelImpl};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;
use starknet::testing;

//
// Setup
//

fn STATE() -> DualCaseERC20::ContractState {
    DualCaseERC20::contract_state_for_testing()
}

fn setup() -> DualCaseERC20::ContractState {
    let mut state = STATE();
    state.erc20.initializer(NAME, SYMBOL);
    state.erc20._mint(OWNER(), SUPPLY);
    utils::drop_event(ZERO());
    state
}

//
// initializer & constructor
//

#[test]
#[available_gas(2000000)]
fn test_initializer() {
    let mut state = STATE();
    state.erc20.initializer(NAME, SYMBOL);

    assert(state.erc20.name() == NAME, 'Name should be NAME');
    assert(state.erc20.symbol() == SYMBOL, 'Symbol should be SYMBOL');
    assert(state.erc20.decimals() == DECIMALS, 'Decimals should be 18');
    assert(state.erc20.total_supply() == 0, 'Supply should eq 0');
}

//
// Getters
//

#[test]
#[available_gas(2000000)]
fn test_total_supply() {
    let mut state = STATE();
    state.erc20._mint(OWNER(), SUPPLY);
    assert(state.erc20.total_supply() == SUPPLY, 'Should eq SUPPLY');
}

#[test]
#[available_gas(2000000)]
fn test_totalSupply() {
    let mut state = STATE();
    state.erc20._mint(OWNER(), SUPPLY);
    assert(state.erc20.totalSupply() == SUPPLY, 'Should eq SUPPLY');
}

#[test]
#[available_gas(2000000)]
fn test_balance_of() {
    let mut state = STATE();
    state.erc20._mint(OWNER(), SUPPLY);
    assert(state.erc20.balance_of(OWNER()) == SUPPLY, 'Should eq SUPPLY');
}

#[test]
#[available_gas(2000000)]
fn test_balanceOf() {
    let mut state = STATE();
    state.erc20._mint(OWNER(), SUPPLY);
    assert(state.erc20.balanceOf(OWNER()) == SUPPLY, 'Should eq SUPPLY');
}

#[test]
#[available_gas(2000000)]
fn test_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc20.approve(SPENDER(), VALUE);

    assert(state.erc20.allowance(OWNER(), SPENDER()) == VALUE, 'Should eq VALUE');
}

//
// approve & _approve
//

#[test]
#[available_gas(2000000)]
fn test_approve() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    assert(state.erc20.approve(SPENDER(), VALUE), 'Should return true');

    assert_only_event_approval(OWNER(), SPENDER(), VALUE);
    assert(state.erc20.allowance(OWNER(), SPENDER()) == VALUE, 'Spender not approved correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve from 0',))]
fn test_approve_from_zero() {
    let mut state = setup();
    state.erc20.approve(SPENDER(), VALUE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve to 0',))]
fn test_approve_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc20.approve(Zeroable::zero(), VALUE);
}

#[test]
#[available_gas(2000000)]
fn test__approve() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc20._approve(OWNER(), SPENDER(), VALUE);

    assert_only_event_approval(OWNER(), SPENDER(), VALUE);
    assert(state.erc20.allowance(OWNER(), SPENDER()) == VALUE, 'Spender not approved correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve from 0',))]
fn test__approve_from_zero() {
    let mut state = setup();
    state.erc20._approve(Zeroable::zero(), SPENDER(), VALUE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve to 0',))]
fn test__approve_to_zero() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc20._approve(OWNER(), Zeroable::zero(), VALUE);
}

//
// transfer & _transfer
//

#[test]
#[available_gas(2000000)]
fn test_transfer() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    assert(state.erc20.transfer(RECIPIENT(), VALUE), 'Should return true');

    assert_only_event_transfer(OWNER(), RECIPIENT(), VALUE);
    assert(state.erc20.balance_of(RECIPIENT()) == VALUE, 'Balance should eq VALUE');
    assert(state.erc20.balance_of(OWNER()) == SUPPLY - VALUE, 'Should eq supply - VALUE');
    assert(state.erc20.total_supply() == SUPPLY, 'Total supply should not change');
}

#[test]
#[available_gas(2000000)]
fn test__transfer() {
    let mut state = setup();

    state.erc20._transfer(OWNER(), RECIPIENT(), VALUE);

    assert_only_event_transfer(OWNER(), RECIPIENT(), VALUE);
    assert(state.erc20.balance_of(RECIPIENT()) == VALUE, 'Balance should eq amount');
    assert(state.erc20.balance_of(OWNER()) == SUPPLY - VALUE, 'Should eq supply - amount');
    assert(state.erc20.total_supply() == SUPPLY, 'Total supply should not change');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow',))]
fn test__transfer_not_enough_balance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());

    let balance_plus_one = SUPPLY + 1;
    state.erc20._transfer(OWNER(), RECIPIENT(), balance_plus_one);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: transfer from 0',))]
fn test__transfer_from_zero() {
    let mut state = setup();
    state.erc20._transfer(Zeroable::zero(), RECIPIENT(), VALUE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: transfer to 0',))]
fn test__transfer_to_zero() {
    let mut state = setup();
    state.erc20._transfer(OWNER(), Zeroable::zero(), VALUE);
}

//
// transfer_from & transferFrom
//

#[test]
#[available_gas(2000000)]
fn test_transfer_from() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc20.approve(SPENDER(), VALUE);
    utils::drop_event(ZERO());

    testing::set_caller_address(SPENDER());
    assert(state.erc20.transfer_from(OWNER(), RECIPIENT(), VALUE), 'Should return true');

    assert_event_approval(OWNER(), SPENDER(), 0);
    assert_only_event_transfer(OWNER(), RECIPIENT(), VALUE);

    assert(state.erc20.balance_of(RECIPIENT()) == VALUE, 'Should eq amount');
    assert(state.erc20.balance_of(OWNER()) == SUPPLY - VALUE, 'Should eq supply - amount');
    assert(state.erc20.allowance(OWNER(), SPENDER()) == 0, 'Should eq 0');
    assert(state.erc20.total_supply() == SUPPLY, 'Total supply should not change');
}

#[test]
#[available_gas(2000000)]
fn test_transfer_from_doesnt_consume_infinite_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc20.approve(SPENDER(), BoundedInt::max());

    testing::set_caller_address(SPENDER());
    state.erc20.transfer_from(OWNER(), RECIPIENT(), VALUE);

    assert(
        state.erc20.allowance(OWNER(), SPENDER()) == BoundedInt::max(),
        'Allowance should not change'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow',))]
fn test_transfer_from_greater_than_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc20.approve(SPENDER(), VALUE);

    testing::set_caller_address(SPENDER());
    let allowance_plus_one = VALUE + 1;
    state.erc20.transfer_from(OWNER(), RECIPIENT(), allowance_plus_one);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: transfer to 0',))]
fn test_transfer_from_to_zero_address() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc20.approve(SPENDER(), VALUE);

    testing::set_caller_address(SPENDER());
    state.erc20.transfer_from(OWNER(), Zeroable::zero(), VALUE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow',))]
fn test_transfer_from_from_zero_address() {
    let mut state = setup();
    state.erc20.transfer_from(Zeroable::zero(), RECIPIENT(), VALUE);
}

#[test]
#[available_gas(2000000)]
fn test_transferFrom() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc20.approve(SPENDER(), VALUE);
    utils::drop_event(ZERO());

    testing::set_caller_address(SPENDER());
    assert(state.erc20.transferFrom(OWNER(), RECIPIENT(), VALUE), 'Should return true');

    assert_event_approval(OWNER(), SPENDER(), 0);
    assert_only_event_transfer(OWNER(), RECIPIENT(), VALUE);

    assert(state.erc20.balanceOf(RECIPIENT()) == VALUE, 'Should eq amount');
    assert(state.erc20.balanceOf(OWNER()) == SUPPLY - VALUE, 'Should eq supply - amount');
    assert(state.erc20.allowance(OWNER(), SPENDER()) == 0, 'Should eq 0');
    assert(state.erc20.totalSupply() == SUPPLY, 'Total supply should not change');
}

#[test]
#[available_gas(2000000)]
fn test_transferFrom_doesnt_consume_infinite_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc20.approve(SPENDER(), BoundedInt::max());

    testing::set_caller_address(SPENDER());
    state.erc20.transferFrom(OWNER(), RECIPIENT(), VALUE);

    assert(
        state.erc20.allowance(OWNER(), SPENDER()) == BoundedInt::max(),
        'Allowance should not change'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow',))]
fn test_transferFrom_greater_than_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc20.approve(SPENDER(), VALUE);

    testing::set_caller_address(SPENDER());
    let allowance_plus_one = VALUE + 1;
    state.erc20.transferFrom(OWNER(), RECIPIENT(), allowance_plus_one);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: transfer to 0',))]
fn test_transferFrom_to_zero_address() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc20.approve(SPENDER(), VALUE);

    testing::set_caller_address(SPENDER());
    state.erc20.transferFrom(OWNER(), Zeroable::zero(), VALUE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow',))]
fn test_transferFrom_from_zero_address() {
    let mut state = setup();
    state.erc20.transferFrom(Zeroable::zero(), RECIPIENT(), VALUE);
}

//
// increase_allowance & increaseAllowance
//

#[test]
#[available_gas(2000000)]
fn test_increase_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc20.approve(SPENDER(), VALUE);
    utils::drop_event(ZERO());

    assert(state.erc20.increase_allowance(SPENDER(), VALUE), 'Should return true');

    assert_only_event_approval(OWNER(), SPENDER(), VALUE * 2);
    assert(state.erc20.allowance(OWNER(), SPENDER()) == VALUE * 2, 'Should be amount * 2');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve to 0',))]
fn test_increase_allowance_to_zero_address() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc20.increase_allowance(Zeroable::zero(), VALUE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve from 0',))]
fn test_increase_allowance_from_zero_address() {
    let mut state = setup();
    state.erc20.increase_allowance(SPENDER(), VALUE);
}

#[test]
#[available_gas(2000000)]
fn test_increaseAllowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc20.approve(SPENDER(), VALUE);
    utils::drop_event(ZERO());

    assert(state.erc20.increaseAllowance(SPENDER(), VALUE), 'Should return true');

    assert_only_event_approval(OWNER(), SPENDER(), 2 * VALUE);
    assert(state.erc20.allowance(OWNER(), SPENDER()) == VALUE * 2, 'Should be amount * 2');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve to 0',))]
fn test_increaseAllowance_to_zero_address() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc20.increaseAllowance(Zeroable::zero(), VALUE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: approve from 0',))]
fn test_increaseAllowance_from_zero_address() {
    let mut state = setup();
    state.erc20.increaseAllowance(SPENDER(), VALUE);
}

//
// decrease_allowance & decreaseAllowance
//

#[test]
#[available_gas(2000000)]
fn test_decrease_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc20.approve(SPENDER(), VALUE);
    utils::drop_event(ZERO());

    assert(state.erc20.decrease_allowance(SPENDER(), VALUE), 'Should return true');

    assert_only_event_approval(OWNER(), SPENDER(), 0);
    assert(state.erc20.allowance(OWNER(), SPENDER()) == VALUE - VALUE, 'Should be 0');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow',))]
fn test_decrease_allowance_to_zero_address() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc20.decrease_allowance(Zeroable::zero(), VALUE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow',))]
fn test_decrease_allowance_from_zero_address() {
    let mut state = setup();
    state.erc20.decrease_allowance(SPENDER(), VALUE);
}

#[test]
#[available_gas(2000000)]
fn test_decreaseAllowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc20.approve(SPENDER(), VALUE);
    utils::drop_event(ZERO());

    assert(state.erc20.decreaseAllowance(SPENDER(), VALUE), 'Should return true');

    assert_only_event_approval(OWNER(), SPENDER(), 0);
    assert(state.erc20.allowance(OWNER(), SPENDER()) == VALUE - VALUE, 'Should be 0');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow',))]
fn test_decreaseAllowance_to_zero_address() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    state.erc20.decreaseAllowance(Zeroable::zero(), VALUE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow',))]
fn test_decreaseAllowance_from_zero_address() {
    let mut state = setup();
    state.erc20.decreaseAllowance(SPENDER(), VALUE);
}

//
// _spend_allowance
//

#[test]
#[available_gas(2000000)]
fn test__spend_allowance_not_unlimited() {
    let mut state = setup();

    state.erc20._approve(OWNER(), SPENDER(), SUPPLY);
    utils::drop_event(ZERO());

    state.erc20._spend_allowance(OWNER(), SPENDER(), VALUE);

    assert_only_event_approval(OWNER(), SPENDER(), SUPPLY - VALUE);
    assert(
        state.erc20.allowance(OWNER(), SPENDER()) == SUPPLY - VALUE, 'Should eq supply - amount'
    );
}

#[test]
#[available_gas(2000000)]
fn test__spend_allowance_unlimited() {
    let mut state = setup();
    state.erc20._approve(OWNER(), SPENDER(), BoundedInt::max());

    let max_minus_one: u256 = BoundedInt::max() - 1;
    state.erc20._spend_allowance(OWNER(), SPENDER(), max_minus_one);

    assert(
        state.erc20.allowance(OWNER(), SPENDER()) == BoundedInt::max(),
        'Allowance should not change'
    );
}

//
// _mint
//

#[test]
#[available_gas(2000000)]
fn test__mint() {
    let mut state = STATE();
    state.erc20._mint(OWNER(), VALUE);

    assert_only_event_transfer(ZERO(), OWNER(), VALUE);
    assert(state.erc20.balance_of(OWNER()) == VALUE, 'Should eq amount');
    assert(state.erc20.total_supply() == VALUE, 'Should eq total supply');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: mint to 0',))]
fn test__mint_to_zero() {
    let mut state = STATE();
    state.erc20._mint(Zeroable::zero(), VALUE);
}

//
// _burn
//

#[test]
#[available_gas(2000000)]
fn test__burn() {
    let mut state = setup();
    state.erc20._burn(OWNER(), VALUE);

    assert_only_event_transfer(OWNER(), ZERO(), VALUE);
    assert(state.erc20.total_supply() == SUPPLY - VALUE, 'Should eq supply - amount');
    assert(state.erc20.balance_of(OWNER()) == SUPPLY - VALUE, 'Should eq supply - amount');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ERC20: burn from 0',))]
fn test__burn_from_zero() {
    let mut state = setup();
    state.erc20._burn(Zeroable::zero(), VALUE);
}

//
// Helpers
//

fn assert_event_approval(owner: ContractAddress, spender: ContractAddress, value: u256) {
    let event = utils::pop_log::<Approval>(ZERO()).unwrap();
    assert(event.owner == owner, 'Invalid `owner`');
    assert(event.spender == spender, 'Invalid `spender`');
    assert(event.value == value, 'Invalid `value`');

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(owner);
    indexed_keys.append_serde(spender);
    utils::assert_indexed_keys(event, indexed_keys.span())
}

fn assert_only_event_approval(owner: ContractAddress, spender: ContractAddress, value: u256) {
    assert_event_approval(owner, spender, value);
    utils::assert_no_events_left(ZERO());
}

fn assert_event_transfer(from: ContractAddress, to: ContractAddress, value: u256) {
    let event = utils::pop_log::<Transfer>(ZERO()).unwrap();
    assert(event.from == from, 'Invalid `from`');
    assert(event.to == to, 'Invalid `to`');
    assert(event.value == value, 'Invalid `value`');

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(from);
    indexed_keys.append_serde(to);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_only_event_transfer(from: ContractAddress, to: ContractAddress, value: u256) {
    assert_event_transfer(from, to, value);
    utils::assert_no_events_left(ZERO());
}
