use core::integer::BoundedInt;
use core::num::traits::Zero;
use openzeppelin::tests::mocks::account_mocks::DualCaseAccountMock;
use openzeppelin::tests::mocks::erc20_votes_mocks::DualCaseERC20VotesMock::SNIP12MetadataImpl;
use openzeppelin::tests::mocks::erc20_votes_mocks::DualCaseERC20VotesMock;
use openzeppelin::tests::utils::constants::{SUPPLY, ZERO, OWNER, PUBKEY, RECIPIENT};
use openzeppelin::tests::utils;
use openzeppelin_token::erc20::ERC20Component::InternalImpl as ERC20Impl;
use openzeppelin_token::erc20::extensions::ERC20VotesComponent::{
    DelegateChanged, DelegateVotesChanged
};
use openzeppelin_token::erc20::extensions::ERC20VotesComponent::{ERC20VotesImpl, InternalImpl};
use openzeppelin_token::erc20::extensions::ERC20VotesComponent;
use openzeppelin_token::erc20::extensions::erc20_votes::Delegation;
use openzeppelin_utils::cryptography::snip12::OffchainMessageHash;
use openzeppelin_utils::serde::SerializedAppend;
use openzeppelin_utils::structs::checkpoint::{Checkpoint, Trace, TraceTrait};
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::storage::{StorageMapMemberAccessTrait, StorageMemberAccessTrait};
use starknet::testing;

use super::common::{assert_event_approval, assert_only_event_approval, assert_only_event_transfer};

//
// Setup
//

type ComponentState = ERC20VotesComponent::ComponentState<DualCaseERC20VotesMock::ContractState>;

fn CONTRACT_STATE() -> DualCaseERC20VotesMock::ContractState {
    DualCaseERC20VotesMock::contract_state_for_testing()
}
fn COMPONENT_STATE() -> ComponentState {
    ERC20VotesComponent::component_state_for_testing()
}

fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    let mut mock_state = CONTRACT_STATE();

    mock_state.erc20.mint(OWNER(), SUPPLY);
    state.transfer_voting_units(ZERO(), OWNER(), SUPPLY);
    utils::drop_event(ZERO());
    state
}

fn setup_account() -> ContractAddress {
    let mut calldata = array![0x26da8d11938b76025862be14fdb8b28438827f73e75e86f7bfa38b196951fa7];
    utils::deploy(DualCaseAccountMock::TEST_CLASS_HASH, calldata)
}

// Checkpoints unordered insertion

#[test]
#[should_panic(expected: ('Unordered insertion',))]
fn test__delegate_checkpoints_unordered_insertion() {
    let mut state = setup();
    let mut trace = state.ERC20Votes_delegate_checkpoints.read(OWNER());

    testing::set_block_timestamp('ts10');
    trace.push('ts2', 0x222);
    trace.push('ts1', 0x111);
}

#[test]
#[should_panic(expected: ('Unordered insertion',))]
fn test__total_checkpoints_unordered_insertion() {
    let mut state = setup();
    let mut trace = state.ERC20Votes_total_checkpoints.read();

    testing::set_block_timestamp('ts10');
    trace.push('ts2', 0x222);
    trace.push('ts1', 0x111);
}

//
// get_votes && get_past_votes
//

#[test]
fn test_get_votes() {
    let mut state = setup();

    testing::set_caller_address(OWNER());
    state.delegate(OWNER());

    assert_eq!(state.get_votes(OWNER()), SUPPLY);
}

#[test]
fn test_get_past_votes() {
    let mut state = setup();
    let mut trace = state.ERC20Votes_delegate_checkpoints.read(OWNER());

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

    assert_eq!(state.get_past_votes(OWNER(), 'ts2'), 0x222, "Should eq ts2");
    assert_eq!(state.get_past_votes(OWNER(), 'ts5'), big1, "Should eq ts4");
    assert_eq!(state.get_past_votes(OWNER(), 'ts8'), big3, "Should eq ts8");
}

#[test]
#[should_panic(expected: ('Votes: future Lookup',))]
fn test_get_past_votes_future_lookup() {
    let state = setup();

    // Past timestamp.
    testing::set_block_timestamp('ts1');
    state.get_past_votes(OWNER(), 'ts2');
}

#[test]
fn test_get_past_total_supply() {
    let mut state = setup();
    let mut trace = state.ERC20Votes_total_checkpoints.read();

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

    assert_eq!(state.get_past_total_supply('ts2'), 0x222, "Should eq ts2");
    assert_eq!(state.get_past_total_supply('ts5'), big1, "Should eq ts4");
    assert_eq!(state.get_past_total_supply('ts8'), big3, "Should eq ts8");
}

#[test]
#[should_panic(expected: ('Votes: future Lookup',))]
fn test_get_past_total_supply_future_lookup() {
    let state = setup();

    // Past timestamp.
    testing::set_block_timestamp('ts1');
    state.get_past_total_supply('ts2');
}

//
// delegate & delegates
//

#[test]
fn test_delegate() {
    let mut state = setup();
    testing::set_caller_address(OWNER());

    // Delegate from zero
    state.delegate(OWNER());

    assert_event_delegate_changed(ZERO(), OWNER(), ZERO(), OWNER());
    assert_only_event_delegate_votes_changed(ZERO(), OWNER(), 0, SUPPLY);
    assert_eq!(state.get_votes(OWNER()), SUPPLY);

    // Delegate from non-zero to non-zero
    state.delegate(RECIPIENT());

    assert_event_delegate_changed(ZERO(), OWNER(), OWNER(), RECIPIENT());
    assert_event_delegate_votes_changed(ZERO(), OWNER(), SUPPLY, 0);
    assert_only_event_delegate_votes_changed(ZERO(), RECIPIENT(), 0, SUPPLY);
    assert!(state.get_votes(OWNER()).is_zero());
    assert_eq!(state.get_votes(RECIPIENT()), SUPPLY);

    // Delegate to zero
    state.delegate(ZERO());

    assert_event_delegate_changed(ZERO(), OWNER(), RECIPIENT(), ZERO());
    assert_event_delegate_votes_changed(ZERO(), RECIPIENT(), SUPPLY, 0);
    assert!(state.get_votes(RECIPIENT()).is_zero());

    // Delegate from zero to zero
    state.delegate(ZERO());

    assert_only_event_delegate_changed(ZERO(), OWNER(), ZERO(), ZERO());
}

#[test]
fn test_delegates() {
    let mut state = setup();
    testing::set_caller_address(OWNER());

    state.delegate(OWNER());
    assert_eq!(state.delegates(OWNER()), OWNER());

    state.delegate(RECIPIENT());
    assert_eq!(state.delegates(OWNER()), RECIPIENT());
}

// delegate_by_sig

#[test]
fn test_delegate_by_sig_hash_generation() {
    testing::set_chain_id('SN_TEST');

    let nonce = 0;
    let expiry = 'ts2';
    let delegator = contract_address_const::<
        0x19dcd9e412145354a3328fb68b5975bded85972893eb42eed11355d4cfbb58a
    >();
    let delegatee = RECIPIENT();
    let delegation = Delegation { delegatee, nonce, expiry };

    let hash = delegation.get_message_hash(delegator);

    // This hash was computed using starknet js sdk from the following values:
    // - name: 'DAPP_NAME'
    // - version: 'DAPP_VERSION'
    // - chainId: 'SN_TEST'
    // - account: 0x19dcd9e412145354a3328fb68b5975bded85972893eb42eed11355d4cfbb58a
    // - delegatee: 'RECIPIENT'
    // - nonce: 0
    // - expiry: 'ts2'
    // - revision: '1'
    let expected_hash = 0x5b9e8190392425e06024b1eedfbbe9dd3631ddd07a84154185d39ec1d657511;
    assert_eq!(hash, expected_hash);
}

#[test]
fn test_delegate_by_sig() {
    let mut state = setup();
    let account = setup_account();
    testing::set_chain_id('SN_TEST');

    let nonce = 0;
    let expiry = 'ts2';
    let delegator = account;
    let delegatee = RECIPIENT();

    // This signature was computed using starknet js sdk from the following values:
    // - private_key: '1234'
    // - public_key: 0x26da8d11938b76025862be14fdb8b28438827f73e75e86f7bfa38b196951fa7
    // - msg_hash: 0x5b9e8190392425e06024b1eedfbbe9dd3631ddd07a84154185d39ec1d657511
    let signature = array![
        0x4b2ca5c3cb47eafc1263db0fb7a1c4ee54eb9cc6605607a072894c0a9ae3b08,
        0x313dc5b5f05ab680db7d51b391fadd52e679c971551f0017a8ceba37bacc5c6
    ];

    testing::set_block_timestamp('ts1');
    state.delegate_by_sig(delegator, delegatee, nonce, expiry, signature);

    assert_only_event_delegate_changed(ZERO(), delegator, ZERO(), delegatee);
    assert_eq!(state.delegates(account), delegatee);
}

#[test]
#[should_panic(expected: ('Votes: expired signature',))]
fn test_delegate_by_sig_past_expiry() {
    let mut state = setup();
    let expiry = 'ts4';
    let signature = array![0, 0];

    testing::set_block_timestamp('ts5');
    state.delegate_by_sig(OWNER(), RECIPIENT(), 0, expiry, signature);
}

#[test]
#[should_panic(expected: ('Nonces: invalid nonce',))]
fn test_delegate_by_sig_invalid_nonce() {
    let mut state = setup();
    let signature = array![0, 0];

    state.delegate_by_sig(OWNER(), RECIPIENT(), 1, 0, signature);
}

#[test]
#[should_panic(expected: ('Votes: invalid signature',))]
fn test_delegate_by_sig_invalid_signature() {
    let mut state = setup();
    let account = setup_account();
    let signature = array![0, 0];

    state.delegate_by_sig(account, RECIPIENT(), 0, 0, signature);
}

//
// num_checkpoints & checkpoints
//

#[test]
fn test_num_checkpoints() {
    let state = setup();
    let mut trace = state.ERC20Votes_delegate_checkpoints.read(OWNER());

    trace.push('ts1', 0x111);
    trace.push('ts2', 0x222);
    trace.push('ts3', 0x333);
    trace.push('ts4', 0x444);
    assert_eq!(state.num_checkpoints(OWNER()), 4);

    trace.push('ts5', 0x555);
    trace.push('ts6', 0x666);
    assert_eq!(state.num_checkpoints(OWNER()), 6);

    assert!(state.num_checkpoints(RECIPIENT()).is_zero());
}

#[test]
fn test_checkpoints() {
    let state = setup();
    let mut trace = state.ERC20Votes_delegate_checkpoints.read(OWNER());

    trace.push('ts1', 0x111);
    trace.push('ts2', 0x222);
    trace.push('ts3', 0x333);
    trace.push('ts4', 0x444);

    let checkpoint: Checkpoint = state.checkpoints(OWNER(), 2);
    assert_eq!(checkpoint.key, 'ts3');
    assert_eq!(checkpoint.value, 0x333);
}

#[test]
#[should_panic(expected: ('Array overflow',))]
fn test__checkpoints_array_overflow() {
    let state = setup();
    state.checkpoints(OWNER(), 1);
}

//
// get_voting_units
//

#[test]
fn test_get_voting_units() {
    let state = setup();
    assert_eq!(state.get_voting_units(OWNER()), SUPPLY);
}

//
// Helpers
//

fn assert_event_delegate_changed(
    contract: ContractAddress,
    delegator: ContractAddress,
    from_delegate: ContractAddress,
    to_delegate: ContractAddress
) {
    let event = utils::pop_log::<ERC20VotesComponent::Event>(contract).unwrap();
    let expected = ERC20VotesComponent::Event::DelegateChanged(
        DelegateChanged { delegator, from_delegate, to_delegate }
    );
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("DelegateChanged"));
    indexed_keys.append_serde(delegator);
    indexed_keys.append_serde(from_delegate);
    indexed_keys.append_serde(to_delegate);
    utils::assert_indexed_keys(event, indexed_keys.span())
}

fn assert_only_event_delegate_changed(
    contract: ContractAddress,
    delegator: ContractAddress,
    from_delegate: ContractAddress,
    to_delegate: ContractAddress
) {
    assert_event_delegate_changed(contract, delegator, from_delegate, to_delegate);
    utils::assert_no_events_left(contract);
}

fn assert_event_delegate_votes_changed(
    contract: ContractAddress, delegate: ContractAddress, previous_votes: u256, new_votes: u256
) {
    let event = utils::pop_log::<ERC20VotesComponent::Event>(contract).unwrap();
    let expected = ERC20VotesComponent::Event::DelegateVotesChanged(
        DelegateVotesChanged { delegate, previous_votes, new_votes }
    );
    assert!(event == expected);

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(selector!("DelegateVotesChanged"));
    indexed_keys.append_serde(delegate);
    utils::assert_indexed_keys(event, indexed_keys.span())
}

fn assert_only_event_delegate_votes_changed(
    contract: ContractAddress, delegate: ContractAddress, previous_votes: u256, new_votes: u256
) {
    assert_event_delegate_votes_changed(contract, delegate, previous_votes, new_votes);
    utils::assert_no_events_left(contract);
}
