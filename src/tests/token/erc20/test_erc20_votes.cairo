use core::integer::BoundedInt;
use core::num::traits::Zero;
use openzeppelin::tests::mocks::erc20_votes_mocks::DualCaseERC20VotesMock::SNIP12MetadataImpl;
use openzeppelin::tests::mocks::erc20_votes_mocks::DualCaseERC20VotesMock;
use openzeppelin::tests::utils::constants::{SUPPLY, ZERO, OWNER, RECIPIENT};
use openzeppelin::tests::utils::events::EventSpyExt;
use openzeppelin::tests::utils;
use openzeppelin::token::erc20::ERC20Component::InternalImpl as ERC20Impl;
use openzeppelin::token::erc20::extensions::ERC20VotesComponent::{
    DelegateChanged, DelegateVotesChanged
};
use openzeppelin::token::erc20::extensions::ERC20VotesComponent::{ERC20VotesImpl, InternalImpl};
use openzeppelin::token::erc20::extensions::ERC20VotesComponent;
use openzeppelin::token::erc20::extensions::erc20_votes::Delegation;
use openzeppelin::utils::cryptography::snip12::OffchainMessageHash;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::utils::structs::checkpoint::{Checkpoint, TraceTrait};
use snforge_std::signature::KeyPairTrait;
use snforge_std::signature::stark_curve::{StarkCurveKeyPairImpl, StarkCurveSignerImpl};
use snforge_std::{
    cheat_block_timestamp_global, start_cheat_caller_address, cheat_chain_id_global, test_address
};
use snforge_std::{EventSpy, EventAssertions};
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::storage::{StorageMapMemberAccessTrait, StorageMemberAccessTrait};

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
    state
}

fn setup_account(public_key: felt252) -> ContractAddress {
    let mut calldata = array![public_key];
    utils::declare_and_deploy("DualCaseAccountMock", calldata)
}

// Checkpoints unordered insertion

#[test]
#[should_panic(expected: ('Unordered insertion',))]
fn test__delegate_checkpoints_unordered_insertion() {
    let mut state = setup();
    let mut trace = state.ERC20Votes_delegate_checkpoints.read(OWNER());

    cheat_block_timestamp_global('ts10');
    trace.push('ts2', 0x222);
    trace.push('ts1', 0x111);
}

#[test]
#[should_panic(expected: ('Unordered insertion',))]
fn test__total_checkpoints_unordered_insertion() {
    let mut state = setup();
    let mut trace = state.ERC20Votes_total_checkpoints.read();

    cheat_block_timestamp_global('ts10');
    trace.push('ts2', 0x222);
    trace.push('ts1', 0x111);
}

//
// get_votes && get_past_votes
//

#[test]
fn test_get_votes() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OWNER());
    state.delegate(OWNER());

    assert_eq!(state.get_votes(OWNER()), SUPPLY);
}

#[test]
fn test_get_past_votes() {
    let mut state = setup();
    let mut trace = state.ERC20Votes_delegate_checkpoints.read(OWNER());

    // Future timestamp.
    cheat_block_timestamp_global('ts10');
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
    cheat_block_timestamp_global('ts1');
    state.get_past_votes(OWNER(), 'ts2');
}

#[test]
fn test_get_past_total_supply() {
    let mut state = setup();
    let mut trace = state.ERC20Votes_total_checkpoints.read();

    // Future timestamp.
    cheat_block_timestamp_global('ts10');
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
    cheat_block_timestamp_global('ts1');
    state.get_past_total_supply('ts2');
}

//
// delegate & delegates
//

#[test]
fn test_delegate() {
    let mut state = setup();
    let contract_address = test_address();
    let mut spy = utils::spy_on(contract_address);

    start_cheat_caller_address(contract_address, OWNER());

    // Delegate from zero
    state.delegate(OWNER());

    spy.assert_event_delegate_changed(contract_address, OWNER(), ZERO(), OWNER());
    spy.assert_only_event_delegate_votes_changed(contract_address, OWNER(), 0, SUPPLY);
    assert_eq!(state.get_votes(OWNER()), SUPPLY);

    // Delegate from non-zero to non-zero
    state.delegate(RECIPIENT());

    spy.assert_event_delegate_changed(contract_address, OWNER(), OWNER(), RECIPIENT());
    spy.assert_event_delegate_votes_changed(contract_address, OWNER(), SUPPLY, 0);
    spy.assert_only_event_delegate_votes_changed(contract_address, RECIPIENT(), 0, SUPPLY);
    assert!(state.get_votes(OWNER()).is_zero());
    assert_eq!(state.get_votes(RECIPIENT()), SUPPLY);

    // Delegate to zero
    state.delegate(ZERO());

    spy.assert_event_delegate_changed(contract_address, OWNER(), RECIPIENT(), ZERO());
    spy.assert_event_delegate_votes_changed(contract_address, RECIPIENT(), SUPPLY, 0);
    assert!(state.get_votes(RECIPIENT()).is_zero());

    // Delegate from zero to zero
    state.delegate(ZERO());

    spy.assert_only_event_delegate_changed(contract_address, OWNER(), ZERO(), ZERO());
}

#[test]
fn test_delegates() {
    let mut state = setup();
    start_cheat_caller_address(test_address(), OWNER());

    state.delegate(OWNER());
    assert_eq!(state.delegates(OWNER()), OWNER());

    state.delegate(RECIPIENT());
    assert_eq!(state.delegates(OWNER()), RECIPIENT());
}

// delegate_by_sig

#[test]
fn test_delegate_by_sig_hash_generation() {
    cheat_chain_id_global('SN_TEST');

    let nonce = 0;
    let expiry = 'ts2';
    let delegator = contract_address_const::<
        0x70b0526a4bfbc9ca717c96aeb5a8afac85181f4585662273668928585a0d628
    >();
    let delegatee = RECIPIENT();
    let delegation = Delegation { delegatee, nonce, expiry };

    let hash = delegation.get_message_hash(delegator);

    // This hash was computed using starknet js sdk from the following values:
    // - name: 'DAPP_NAME'
    // - version: 'DAPP_VERSION'
    // - chainId: 'SN_TEST'
    // - account: 0x70b0526a4bfbc9ca717c96aeb5a8afac85181f4585662273668928585a0d628
    // - delegatee: 'RECIPIENT'
    // - nonce: 0
    // - expiry: 'ts2'
    // - revision: '1'
    let expected_hash = 0x314bd38b22b62d576691d8dafd9f8ea0601329ebe686bc64ca28e4d8821d5a0;
    assert_eq!(hash, expected_hash);
}

#[test]
fn test_delegate_by_sig() {
    cheat_chain_id_global('SN_TEST');
    cheat_block_timestamp_global('ts1');

    let mut state = setup();
    let contract_address = test_address();
    let key_pair = KeyPairTrait::<felt252, felt252>::generate();
    let account = setup_account(key_pair.public_key);

    let nonce = 0;
    let expiry = 'ts2';
    let delegator = account;
    let delegatee = RECIPIENT();

    let delegation = Delegation { delegatee, nonce, expiry };
    let msg_hash = delegation.get_message_hash(delegator);
    let (r, s) = key_pair.sign(msg_hash).unwrap();

    let mut spy = utils::spy_on(contract_address);

    state.delegate_by_sig(delegator, delegatee, nonce, expiry, array![r, s]);

    spy.assert_only_event_delegate_changed(contract_address, delegator, ZERO(), delegatee);
    assert_eq!(state.delegates(account), delegatee);
}

#[test]
#[should_panic(expected: ('Votes: expired signature',))]
fn test_delegate_by_sig_past_expiry() {
    cheat_block_timestamp_global('ts5');

    let mut state = setup();
    let expiry = 'ts4';
    let signature = array![0, 0];

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
    let account = setup_account(0x123);
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

#[generate_trait]
impl VotesSpyHelpersImpl of VotesSpyHelpers {
    fn assert_event_delegate_changed(
        ref self: EventSpy,
        contract: ContractAddress,
        delegator: ContractAddress,
        from_delegate: ContractAddress,
        to_delegate: ContractAddress
    ) {
        let expected = ERC20VotesComponent::Event::DelegateChanged(
            DelegateChanged { delegator, from_delegate, to_delegate }
        );
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_delegate_changed(
        ref self: EventSpy,
        contract: ContractAddress,
        delegator: ContractAddress,
        from_delegate: ContractAddress,
        to_delegate: ContractAddress
    ) {
        self.assert_event_delegate_changed(contract, delegator, from_delegate, to_delegate);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_delegate_votes_changed(
        ref self: EventSpy,
        contract: ContractAddress,
        delegate: ContractAddress,
        previous_votes: u256,
        new_votes: u256
    ) {
        let expected = ERC20VotesComponent::Event::DelegateVotesChanged(
            DelegateVotesChanged { delegate, previous_votes, new_votes }
        );
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_delegate_votes_changed(
        ref self: EventSpy,
        contract: ContractAddress,
        delegate: ContractAddress,
        previous_votes: u256,
        new_votes: u256
    ) {
        self.assert_event_delegate_votes_changed(contract, delegate, previous_votes, new_votes);
        self.assert_no_events_left_from(contract);
    }
}
