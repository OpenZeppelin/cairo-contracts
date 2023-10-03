use integer::BoundedInt;
use openzeppelin::account::Account::TRANSACTION_VERSION;
use openzeppelin::account::Account;
use openzeppelin::tests::utils::constants::{
    SUPPLY, ZERO, OWNER, PUBLIC_KEY, RECIPIENT, DAPP_NAME, DAPP_VERSION
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::ERC20;
use openzeppelin::token::erc20::extensions::ERC20Votes;
use openzeppelin::token::erc20::extensions::ERC20Votes::Checkpoint;
use openzeppelin::token::erc20::extensions::ERC20Votes::DelegateChanged;
use openzeppelin::token::erc20::extensions::ERC20Votes::DelegateVotesChanged;
use openzeppelin::token::erc20::extensions::ERC20Votes::InternalImpl;
use openzeppelin::token::erc20::extensions::ERC20Votes::VotesImpl;
use openzeppelin::token::erc20::extensions::erc20votes::{Delegation, IOffchainMessageHash};
use openzeppelin::utils::cryptography::eip712_draft::EIP712;
use openzeppelin::utils::structs::checkpoints::{Trace, TraceTrait};
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::testing;

use ERC20Votes::_delegate_checkpoints::InternalContractMemberStateTrait as DelegateCheckpointsTrait;
use ERC20Votes::_total_checkpoints::InternalContractMemberStateTrait as TotalCheckpointsTrait;

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

fn deploy_account() -> ContractAddress {
    testing::set_version(TRANSACTION_VERSION);

    let mut calldata = array![PUBLIC_KEY];

    utils::deploy(Account::TEST_CLASS_HASH, calldata)
}

//
// Checkpoints unordered insertion
//

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Unordered insertion',))]
fn test__delegate_checkpoints_unordered_insertion() {
    let mut state = setup();
    let mut trace = state._delegate_checkpoints.read(OWNER());

    testing::set_block_timestamp('ts10');
    trace.push('ts2', 0x222);
    trace.push('ts1', 0x111);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Unordered insertion',))]
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

    // Big numbers (high different from 0x0)
    let big1: u256 = BoundedInt::<u128>::max().into() + 0x444;
    let big2: u256 = BoundedInt::<u128>::max().into() + 0x666;
    let big3: u256 = BoundedInt::<u128>::max().into() + 0x888;
    trace.push('ts4', big1);
    trace.push('ts6', big2);
    trace.push('ts8', big3);

    assert(VotesImpl::get_past_votes(@state, OWNER(), 'ts2') == 0x222, 'Should eq ts2');
    assert(VotesImpl::get_past_votes(@state, OWNER(), 'ts5') == big1, 'Should eq ts4');
    assert(VotesImpl::get_past_votes(@state, OWNER(), 'ts8') == big3, 'Should eq ts8');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Votes: future Lookup',))]
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

    // Big numbers (high different from 0x0)
    let big1: u256 = BoundedInt::<u128>::max().into() + 0x444;
    let big2: u256 = BoundedInt::<u128>::max().into() + 0x666;
    let big3: u256 = BoundedInt::<u128>::max().into() + 0x888;
    trace.push('ts4', big1);
    trace.push('ts6', big2);
    trace.push('ts8', big3);

    assert(VotesImpl::get_past_total_supply(@state, 'ts2') == 0x222, 'Should eq ts2');
    assert(VotesImpl::get_past_total_supply(@state, 'ts5') == big1, 'Should eq ts4');
    assert(VotesImpl::get_past_total_supply(@state, 'ts8') == big3, 'Should eq ts8');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Votes: future Lookup',))]
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
// delegate_by_sig
//

#[test]
#[available_gas(20000000)]
fn test_delegate_by_sig_hash_generation() {
    let mut state = setup();
    let account = deploy_account();
    testing::set_chain_id('SN_TEST');

    let nonce = 0;
    let expiry = 'ts2';
    let delegator = account;
    let delegatee = RECIPIENT();
    let delegation = Delegation { delegatee, nonce, expiry };

    let hash = delegation.get_message_hash('OZ-DAPP', '2.0.0', delegator);
    // This hash was computed using starknet js sdk from the following values:
    // - name: 'OZ-DAPP'
    // - version: '2.0.0'
    // - chainId: 'SN_TEST'
    // - account: 0x1
    // - delegatee: 'RECIPIENT'
    // - nonce: 0
    // - expiry: 'ts2'
    let expected_hash = 0x204adc4d076dc4298323e6920e1bf9ce6278df42824a07f49eb3c1f9cd19ef7;
    assert(hash == expected_hash, 'Invalid hash');
}


#[test]
#[available_gas(20000000)]
fn test_delegate_by_sig() {
    let mut state = setup();
    let account = deploy_account();
    testing::set_chain_id('SN_TEST');

    let nonce = 0;
    let expiry = 'ts2';
    let delegator = account;
    let delegatee = RECIPIENT();
    let delegation = Delegation { delegatee, nonce, expiry };

    // Simulate construction time EIP712 initializer.
    let mut eip712_state = EIP712::unsafe_new_contract_state();
    EIP712::InternalImpl::initializer(ref eip712_state, DAPP_NAME, DAPP_VERSION);

    // This signature was computed using starknet js sdk from the following values:
    // - private_key: 1234
    // - public_key: 0x26da8d11938b76025862be14fdb8b28438827f73e75e86f7bfa38b196951fa7
    // - msg_hash: 0x204adc4d076dc4298323e6920e1bf9ce6278df42824a07f49eb3c1f9cd19ef7
    let signature = array![
        0x4bc155529014b501c42ba0a862de476d5cab3ce412f6de9066a89e757687918,
        0x2fd7e5261a70805cd526844f0eff2c71483185dc13d00ac0578cf72a94c5266
    ];

    testing::set_block_timestamp('ts1');
    VotesImpl::delegate_by_sig(ref state, delegator, delegatee, nonce, expiry, signature);

    assert_only_event_delegate_changed(delegator, ZERO(), delegatee);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Votes: expired signature',))]
fn test_delegate_by_sig_past_expiry() {
    let mut state = setup();
    let expiry = 'ts4';
    let signature = array![0, 0];

    testing::set_block_timestamp('ts5');
    VotesImpl::delegate_by_sig(ref state, OWNER(), RECIPIENT(), 0, expiry, signature);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Nonces: invalid nonce',))]
fn test_delegate_by_sig_invalid_nonce() {
    let mut state = setup();
    let signature = array![0, 0];

    VotesImpl::delegate_by_sig(ref state, OWNER(), RECIPIENT(), 1, 0, signature);
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Votes: invalid signature',))]
fn test_delegate_by_sig_invalid_signature() {
    let mut state = setup();
    let account = deploy_account();
    let signature = array![0, 0];

    VotesImpl::delegate_by_sig(ref state, account, RECIPIENT(), 0, 0, signature);
}

//
// num_checkpoints & checkpoints
//

#[test]
#[available_gas(20000000)]
fn test_num_checkpoints() {
    let mut state = setup();
    let mut trace = state._delegate_checkpoints.read(OWNER());

    trace.push('ts1', 0x111);
    trace.push('ts2', 0x222);
    trace.push('ts3', 0x333);
    trace.push('ts4', 0x444);
    assert(InternalImpl::num_checkpoints(@state, OWNER()) == 4, 'Should eq 4');

    trace.push('ts5', 0x555);
    trace.push('ts6', 0x666);
    assert(InternalImpl::num_checkpoints(@state, OWNER()) == 6, 'Should eq 6');

    assert(InternalImpl::num_checkpoints(@state, RECIPIENT()) == 0, 'Should eq zero');
}

#[test]
#[available_gas(20000000)]
fn test_checkpoints() {
    let mut state = setup();
    let mut trace = state._delegate_checkpoints.read(OWNER());

    trace.push('ts1', 0x111);
    trace.push('ts2', 0x222);
    trace.push('ts3', 0x333);
    trace.push('ts4', 0x444);

    let checkpoint: Checkpoint = InternalImpl::checkpoints(@state, OWNER(), 2);
    assert(checkpoint.key == 'ts3', 'Invalid key');
    assert(checkpoint.value == 0x333, 'Invalid value');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Array overflow',))]
fn test__checkpoints_array_overflow() {
    let mut state = setup();
    let mut trace = state._delegate_checkpoints.read(OWNER());

    InternalImpl::checkpoints(@state, OWNER(), 1);
}

//
// get_voting_units
//

#[test]
#[available_gas(20000000)]
fn test_get_voting_units() {
    let mut state = setup();
    assert(InternalImpl::get_voting_units(@state, OWNER()) == SUPPLY, 'Should eq SUPPLY');
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
