use openzeppelin::token::erc20::ERC20;
use openzeppelin::token::erc20::extensions::ERC20Votes;
use openzeppelin::token::erc20::extensions::ERC20Votes::InternalImpl;
use openzeppelin::token::erc20::extensions::ERC20Votes::VotesImpl;
use openzeppelin::utils::structs::checkpoints::{Trace, TraceTrait};
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing;
use traits::Into;

use ERC20Votes::_delegate_checkpoints::InternalContractStateTrait as DelegateCheckpointsTrait;

//
// Constants
//

const SUPPLY: u256 = 2000;

fn ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

fn OWNER() -> ContractAddress {
    contract_address_const::<1>()
}

fn RECIPIENT() -> ContractAddress {
    contract_address_const::<2>()
}

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
    state
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
#[should_panic(expected: ('Unordered insertion', ))]
fn test_get_past_votes_unordered_insertion() {
    let mut state = setup();
    let mut trace = state._delegate_checkpoints.read(OWNER());

    // Future timestamp.
    testing::set_block_timestamp('ts10');
    trace.push('ts2', 0x222);
    trace.push('ts1', 0x111);
}


#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('ERC5805: Future Lookup', ))]
fn test_get_past_votes_future_lookup() {
    let mut state = setup();
    let mut trace = state._delegate_checkpoints.read(OWNER());

    // Past timestamp.
    testing::set_block_timestamp('ts1');
    VotesImpl::get_past_votes(@state, OWNER(), 'ts2');
}
