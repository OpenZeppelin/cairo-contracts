use integer::BoundedInt;
use openzeppelin::tests::extensions::test_erc20votes::{
    assert_event_delegate_changed, assert_only_event_delegate_changed,
    assert_event_delegate_votes_changed, assert_only_event_delegate_votes_changed
};
use openzeppelin::tests::token::test_erc20::{
    assert_only_event_transfer, assert_only_event_approval, assert_event_approval
};
use openzeppelin::tests::utils::constants::{
    DAPP_NAME, DAPP_VERSION, NAME, SYMBOL, DECIMALS, SUPPLY, VALUE, ZERO, OWNER, SPENDER, RECIPIENT
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::presets::ERC20VotesPreset;
use openzeppelin::token::erc20::presets::ERC20VotesPreset::ERC20Impl;
use openzeppelin::token::erc20::presets::ERC20VotesPreset::VotesImpl;
use openzeppelin::utils::structs::checkpoints::Checkpoint;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing;
use traits::Into;
use zeroable::Zeroable;

//
// Setup
//

fn STATE() -> ERC20VotesPreset::ContractState {
    ERC20VotesPreset::contract_state_for_testing()
}

fn setup() -> ERC20VotesPreset::ContractState {
    let mut state = STATE();
    testing::set_block_timestamp('ts0');
    ERC20VotesPreset::constructor(
        ref state, NAME, SYMBOL, SUPPLY, OWNER(), DAPP_NAME, DAPP_VERSION
    );
    utils::drop_events(ZERO(), 2);
    state
}

//
// constructor
//

#[test]
#[available_gas(2000000)]
fn test_constructor() {
    let mut state = STATE();
    ERC20VotesPreset::constructor(
        ref state, NAME, SYMBOL, SUPPLY, OWNER(), DAPP_NAME, DAPP_VERSION
    );

    assert_only_event_transfer(ZERO(), OWNER(), SUPPLY);

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
#[available_gas(20000000)]
fn test_approve() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    assert(ERC20Impl::approve(ref state, SPENDER(), VALUE), 'Should return true');
    assert_only_event_approval(OWNER(), SPENDER(), VALUE);

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
    assert_only_event_transfer(OWNER(), RECIPIENT(), VALUE);

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
    utils::drop_event(ZERO());

    testing::set_caller_address(SPENDER());
    assert(ERC20Impl::transfer_from(ref state, OWNER(), RECIPIENT(), VALUE), 'Should return true');

    assert_event_approval(OWNER(), SPENDER(), 0);
    assert_only_event_transfer(OWNER(), RECIPIENT(), VALUE);

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
#[available_gas(20000000)]
fn test_increase_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    ERC20Impl::approve(ref state, SPENDER(), VALUE);
    utils::drop_event(ZERO());

    assert(ERC20VotesPreset::increase_allowance(ref state, SPENDER(), VALUE), 'Should return true');
    assert_only_event_approval(OWNER(), SPENDER(), VALUE * 2);

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
#[available_gas(20000000)]
fn test_decrease_allowance() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    ERC20Impl::approve(ref state, SPENDER(), VALUE);
    utils::drop_event(ZERO());

    assert(ERC20VotesPreset::decrease_allowance(ref state, SPENDER(), VALUE), 'Should return true');
    assert_only_event_approval(OWNER(), SPENDER(), 0);

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
// get_votes && get_past_votes
//

#[test]
#[available_gas(20000000)]
fn test_get_votes() {
    let mut state = setup();

    testing::set_caller_address(OWNER());
    VotesImpl::delegate(ref state, OWNER());

    assert(VotesImpl::get_votes(@state, OWNER()) == SUPPLY, 'Should eq SUPPLY');
}

#[test]
#[available_gas(20000000)]
fn test_get_past_votes() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    VotesImpl::delegate(ref state, OWNER());
    let amount = 100;

    testing::set_block_timestamp('ts1');
    ERC20Impl::transfer(ref state, RECIPIENT(), amount);
    testing::set_block_timestamp('ts2');
    ERC20Impl::transfer(ref state, RECIPIENT(), amount);
    testing::set_block_timestamp('ts4');
    ERC20Impl::transfer(ref state, RECIPIENT(), amount);

    assert(VotesImpl::get_past_votes(@state, OWNER(), 'ts1') == SUPPLY - amount, 'Should eq ts1');
    assert(
        VotesImpl::get_past_votes(@state, OWNER(), 'ts3') == SUPPLY - 2 * amount, 'Should eq ts2'
    );
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Votes: future Lookup', ))]
fn test_get_past_votes_future_lookup() {
    let mut state = setup();

    // Past timestamp.
    testing::set_block_timestamp('ts1');
    VotesImpl::get_past_votes(@state, OWNER(), 'ts2');
}

#[test]
#[available_gas(20000000)]
fn test_get_past_total_supply() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    VotesImpl::delegate(ref state, OWNER());
    let amount = 100;

    // This should not affect total_supply checkpoints
    testing::set_block_timestamp('ts1');
    ERC20Impl::transfer(ref state, RECIPIENT(), amount);
    testing::set_block_timestamp('ts4');

    // ts0 is the timestamp at construction time, when the tokens were minted
    assert(VotesImpl::get_past_total_supply(@state, 'ts3') == SUPPLY, 'Should eq ts0');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Votes: future Lookup', ))]
fn test_get_past_total_supply_future_lookup() {
    let mut state = setup();

    // Past timestamp.
    testing::set_block_timestamp('ts1');
    VotesImpl::get_past_total_supply(@state, 'ts2');
}

//
// delegate & delegates
//

#[test]
#[available_gas(20000000)]
fn test_delegate() {
    let mut state = setup();
    testing::set_caller_address(OWNER());

    // Delegate from zero
    VotesImpl::delegate(ref state, OWNER());

    assert_event_delegate_changed(OWNER(), ZERO(), OWNER());
    assert_only_event_delegate_votes_changed(OWNER(), 0, SUPPLY);
    assert(VotesImpl::get_votes(@state, OWNER()) == SUPPLY, 'Should eq SUPPLY');

    // Delegate from non-zero to non-zero
    VotesImpl::delegate(ref state, RECIPIENT());

    assert_event_delegate_changed(OWNER(), OWNER(), RECIPIENT());
    assert_event_delegate_votes_changed(OWNER(), SUPPLY, 0);
    assert_only_event_delegate_votes_changed(RECIPIENT(), 0, SUPPLY);
    assert(VotesImpl::get_votes(@state, OWNER()) == 0, 'Should eq zero');
    assert(VotesImpl::get_votes(@state, RECIPIENT()) == SUPPLY, 'Should eq SUPPLY');

    // Delegate to zero
    VotesImpl::delegate(ref state, ZERO());

    assert_event_delegate_changed(OWNER(), RECIPIENT(), ZERO());
    assert_event_delegate_votes_changed(RECIPIENT(), SUPPLY, 0);
    assert(VotesImpl::get_votes(@state, RECIPIENT()) == 0, 'Should eq zero');

    // Delegate from zero to zero
    VotesImpl::delegate(ref state, ZERO());

    assert_only_event_delegate_changed(OWNER(), ZERO(), ZERO());
}

#[test]
#[available_gas(20000000)]
fn test_delegates() {
    let mut state = setup();
    testing::set_caller_address(OWNER());

    VotesImpl::delegate(ref state, OWNER());
    assert(VotesImpl::delegates(@state, OWNER()) == OWNER(), 'Should eq OWNER');

    VotesImpl::delegate(ref state, RECIPIENT());
    assert(VotesImpl::delegates(@state, OWNER()) == RECIPIENT(), 'Should eq RECIPIENT');
}


//
// num_checkpoints & checkpoints
//

#[test]
#[available_gas(20000000)]
fn test_num_checkpoints() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    VotesImpl::delegate(ref state, OWNER());

    let amount = 100;
    testing::set_block_timestamp('ts1');
    ERC20Impl::transfer(ref state, RECIPIENT(), amount);
    testing::set_block_timestamp('ts2');
    ERC20Impl::transfer(ref state, RECIPIENT(), amount);
    testing::set_block_timestamp('ts4');
    ERC20Impl::transfer(ref state, RECIPIENT(), amount);

    // Delagate to self should increase the number of checkpoints
    assert(ERC20VotesPreset::num_checkpoints(@state, OWNER()) == 4, 'Should eq 4');

    testing::set_block_timestamp('ts5');
    ERC20Impl::transfer(ref state, RECIPIENT(), amount);
    testing::set_block_timestamp('ts7');
    ERC20Impl::transfer(ref state, RECIPIENT(), amount);
    assert(ERC20VotesPreset::num_checkpoints(@state, OWNER()) == 6, 'Should eq 6');

    assert(ERC20VotesPreset::num_checkpoints(@state, RECIPIENT()) == 0, 'Should eq zero');
}

#[test]
#[available_gas(20000000)]
fn test_checkpoints() {
    let mut state = setup();
    testing::set_caller_address(OWNER());
    VotesImpl::delegate(ref state, OWNER());

    let amount = 100;
    testing::set_block_timestamp('ts1');
    ERC20Impl::transfer(ref state, RECIPIENT(), amount);
    testing::set_block_timestamp('ts2');
    ERC20Impl::transfer(ref state, RECIPIENT(), amount);
    testing::set_block_timestamp('ts4');
    ERC20Impl::transfer(ref state, RECIPIENT(), amount);

    let checkpoint: Checkpoint = ERC20VotesPreset::checkpoints(@state, OWNER(), 2);
    assert(checkpoint.key == 'ts2', 'Invalid key');
    assert(checkpoint.value == SUPPLY - 2 * amount, 'Invalid value');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Array overflow', ))]
fn test_checkpoints_array_overflow() {
    let mut state = setup();

    ERC20VotesPreset::checkpoints(@state, OWNER(), 1);
}
