use openzeppelin::tests::utils::constants::{SUPPLY, ZERO, OWNER, RECIPIENT};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::ERC20;
use openzeppelin::token::erc20::extensions::ERC20Votes;
use openzeppelin::token::erc20::extensions::ERC20Votes::Checkpoint;
use openzeppelin::token::erc20::extensions::ERC20Votes::DelegateChanged;
use openzeppelin::token::erc20::extensions::ERC20Votes::DelegateVotesChanged;
use openzeppelin::token::erc20::extensions::ERC20Votes::InternalImpl;
use openzeppelin::token::erc20::extensions::ERC20Votes::VotesImpl;
use openzeppelin::utils::structs::checkpoints::{Trace, TraceTrait};
use option::OptionTrait;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing;
use traits::Into;

use ERC20Votes::_delegate_checkpoints::InternalContractStateTrait as DelegateCheckpointsTrait;
use ERC20Votes::_total_checkpoints::InternalContractStateTrait as TotalCheckpointsTrait;

//
// Setup
//

fn STATE() -> ERC20Votes::ContractState {
    ERC20Votes::contract_state_for_testing()
}

fn setup() -> ERC20Votes::ContractState {
    let mut state = STATE();

    // Mint to track voting units.
    let mut erc20_state = ERC20::contract_state_for_testing();
    ERC20::InternalImpl::_mint(ref erc20_state, OWNER(), SUPPLY);

    InternalImpl::transfer_voting_units(ref state, ZERO(), OWNER(), SUPPLY);
    utils::drop_event(ZERO());
    state
}

//
// Checkpoints unordered insertion
//

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Unordered insertion', ))]
fn test__delegate_checkpoints_unordered_insertion() {
    let mut state = setup();
    let mut trace = state._delegate_checkpoints.read(OWNER());

    testing::set_block_timestamp('ts10');
    trace.push('ts2', 0x222);
    trace.push('ts1', 0x111);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Unordered insertion', ))]
fn test__total_checkpoints_unordered_insertion() {
    let mut state = setup();
    let mut trace = state._total_checkpoints.read();

    testing::set_block_timestamp('ts10');
    trace.push('ts2', 0x222);
    trace.push('ts1', 0x111);
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
    let mut trace = state._delegate_checkpoints.read(OWNER());

    // Future timestamp.
    testing::set_block_timestamp('ts10');
    trace.push('ts1', 0x111);
    trace.push('ts2', 0x222);
    trace.push('ts3', 0x333);
    trace.push('ts4', 0x444);
    trace.push('ts6', 0x666);
    trace.push('ts8', 0x888);

    assert(VotesImpl::get_past_votes(@state, OWNER(), 'ts2') == 0x222, 'Should eq ts2');
    assert(VotesImpl::get_past_votes(@state, OWNER(), 'ts5') == 0x444, 'Should eq ts4');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC5805: Future Lookup', ))]
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
    let mut trace = state._total_checkpoints.read();

    // Future timestamp.
    testing::set_block_timestamp('ts10');
    trace.push('ts1', 0x111);
    trace.push('ts2', 0x222);
    trace.push('ts3', 0x333);
    trace.push('ts4', 0x444);
    trace.push('ts6', 0x666);
    trace.push('ts8', 0x888);

    assert(VotesImpl::get_past_total_supply(@state, 'ts2') == 0x222, 'Should eq ts2');
    assert(VotesImpl::get_past_total_supply(@state, 'ts5') == 0x444, 'Should eq ts4');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC5805: Future Lookup', ))]
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
// _num_checkpoints & _checkpoints
//

#[test]
#[available_gas(20000000)]
fn test__num_checkpoints() {
    let mut state = setup();
    let mut trace = state._delegate_checkpoints.read(OWNER());

    trace.push('ts1', 0x111);
    trace.push('ts2', 0x222);
    trace.push('ts3', 0x333);
    trace.push('ts4', 0x444);
    assert(InternalImpl::_num_checkpoints(@state, OWNER()) == 4, 'Should eq 4');

    trace.push('ts5', 0x555);
    trace.push('ts6', 0x666);
    assert(InternalImpl::_num_checkpoints(@state, OWNER()) == 6, 'Should eq 6');

    assert(InternalImpl::_num_checkpoints(@state, RECIPIENT()) == 0, 'Should eq zero');
}

#[test]
#[available_gas(20000000)]
fn test__checkpoints() {
    let mut state = setup();
    let mut trace = state._delegate_checkpoints.read(OWNER());

    trace.push('ts1', 0x111);
    trace.push('ts2', 0x222);
    trace.push('ts3', 0x333);
    trace.push('ts4', 0x444);

    let checkpoint: Checkpoint = InternalImpl::_checkpoints(@state, OWNER(), 2);
    assert(checkpoint.key == 'ts3', 'Invalid key');
    assert(checkpoint.value == 0x333, 'Invalid value');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Array overflow', ))]
fn test__checkpoints_array_overflow() {
    let mut state = setup();
    let mut trace = state._delegate_checkpoints.read(OWNER());

    InternalImpl::_checkpoints(@state, OWNER(), 1);
}

//
// _get_voting_units
//

#[test]
#[available_gas(20000000)]
fn test__get_voting_units() {
    let mut state = setup();
    assert(InternalImpl::_get_voting_units(@state, OWNER()) == SUPPLY, 'Should eq SUPPLY');
}

//
// Helpers
//

fn assert_event_delegate_changed(
    delegator: ContractAddress, from_delegate: ContractAddress, to_delegate: ContractAddress
) {
    let event = utils::pop_log::<DelegateChanged>(ZERO()).unwrap();
    assert(event.delegator == delegator, 'Invalid `delegator`');
    assert(event.from_delegate == from_delegate, 'Invalid `from_delegate`');
    assert(event.to_delegate == to_delegate, 'Invalid `to_delegate`');
}

fn assert_only_event_delegate_changed(
    delegator: ContractAddress, from_delegate: ContractAddress, to_delegate: ContractAddress
) {
    assert_event_delegate_changed(delegator, from_delegate, to_delegate);
    utils::assert_no_events_left(ZERO());
}

fn assert_event_delegate_votes_changed(
    delegate: ContractAddress, previous_votes: u256, new_votes: u256
) {
    let event = utils::pop_log::<DelegateVotesChanged>(ZERO()).unwrap();
    assert(event.delegate == delegate, 'Invalid `delegate`');
    assert(event.previous_votes == previous_votes, 'Invalid `previous_votes`');
    assert(event.new_votes == new_votes, 'Invalid `new_votes`');
}

fn assert_only_event_delegate_votes_changed(
    delegate: ContractAddress, previous_votes: u256, new_votes: u256
) {
    assert_event_delegate_votes_changed(delegate, previous_votes, new_votes);
    utils::assert_no_events_left(ZERO());
}
