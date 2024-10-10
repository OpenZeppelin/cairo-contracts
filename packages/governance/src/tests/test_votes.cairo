use crate::votes::utils::Delegation;
use crate::votes::votes::TokenVotesTrait;
use crate::votes::votes::VotesComponent::{
    DelegateChanged, DelegateVotesChanged, VotesImpl, InternalImpl,
};
use crate::votes::votes::VotesComponent;
use openzeppelin_test_common::mocks::votes::ERC721VotesMock::SNIP12MetadataImpl;
use openzeppelin_test_common::mocks::votes::{ERC721VotesMock, ERC20VotesMock};
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{SUPPLY, ZERO, DELEGATOR, DELEGATEE, OTHER};
use openzeppelin_testing::events::EventSpyExt;
use openzeppelin_token::erc20::ERC20Component::InternalTrait;
use openzeppelin_token::erc721::ERC721Component::{
    ERC721MetadataImpl, InternalImpl as ERC721InternalImpl,
};
use openzeppelin_token::erc721::ERC721Component::{ERC721Impl, ERC721CamelOnlyImpl};
use openzeppelin_utils::cryptography::snip12::OffchainMessageHash;
use openzeppelin_utils::structs::checkpoint::TraceTrait;
use snforge_std::signature::stark_curve::{StarkCurveKeyPairImpl, StarkCurveSignerImpl};
use snforge_std::{
    start_cheat_block_timestamp_global, start_cheat_caller_address, spy_events, test_address
};
use snforge_std::{EventSpy};
use starknet::ContractAddress;
use starknet::storage::StoragePathEntry;

const ERC_721_INITIAL_MINT: u256 = 10;

//
// Setup
//

type ComponentState = VotesComponent::ComponentState<ERC721VotesMock::ContractState>;
type ERC20ComponentState = VotesComponent::ComponentState<ERC20VotesMock::ContractState>;

fn COMPONENT_STATE() -> ComponentState {
    VotesComponent::component_state_for_testing()
}

fn ERC20_COMPONENT_STATE() -> ERC20ComponentState {
    VotesComponent::component_state_for_testing()
}

fn ERC721VOTES_CONTRACT_STATE() -> ERC721VotesMock::ContractState {
    ERC721VotesMock::contract_state_for_testing()
}

fn ERC20VOTES_CONTRACT_STATE() -> ERC20VotesMock::ContractState {
    ERC20VotesMock::contract_state_for_testing()
}

fn setup_erc721_votes() -> ComponentState {
    let mut state = COMPONENT_STATE();
    let mut mock_state = ERC721VOTES_CONTRACT_STATE();
    // Mint ERC_721_INITIAL_MINT NFTs to DELEGATOR
    let mut i: u256 = 0;
    while i < ERC_721_INITIAL_MINT {
        mock_state.erc721.mint(DELEGATOR(), i);
        i += 1;
    };
    state
}

fn setup_erc20_votes() -> ERC20ComponentState {
    let mut state = ERC20_COMPONENT_STATE();
    let mut mock_state = ERC20VOTES_CONTRACT_STATE();

    // Mint SUPPLY tokens to DELEGATOR
    mock_state.erc20.mint(DELEGATOR(), SUPPLY);
    state
}

fn setup_account(public_key: felt252) -> ContractAddress {
    let mut calldata = array![public_key];
    utils::declare_and_deploy("SnakeAccountMock", calldata)
}

//
// Common tests for Votes
//

#[test]
fn test_get_votes() {
    let mut state = setup_erc721_votes();
    start_cheat_caller_address(test_address(), DELEGATOR());
    // Before delegating, the DELEGATOR has 0 votes
    assert_eq!(state.get_votes(DELEGATOR()), 0);
    state.delegate(DELEGATOR());

    assert_eq!(state.get_votes(DELEGATOR()), ERC_721_INITIAL_MINT);
}

#[test]
fn test_get_past_votes() {
    let mut state = setup_erc721_votes();
    let mut trace = state.Votes_delegate_checkpoints.entry(DELEGATOR());

    start_cheat_block_timestamp_global('ts10');

    trace.push('ts1', 3);
    trace.push('ts2', 5);
    trace.push('ts3', 7);

    assert_eq!(state.get_past_votes(DELEGATOR(), 'ts2'), 5);
    assert_eq!(state.get_past_votes(DELEGATOR(), 'ts5'), 7);
}

#[test]
#[should_panic(expected: ('Votes: future Lookup',))]
fn test_get_past_votes_future_lookup() {
    let state = setup_erc721_votes();

    start_cheat_block_timestamp_global('ts1');
    state.get_past_votes(DELEGATOR(), 'ts2');
}

#[test]
fn test_get_past_total_supply() {
    let mut state = setup_erc721_votes();
    let mut trace = state.Votes_total_checkpoints.deref();

    start_cheat_block_timestamp_global('ts10');
    trace.push('ts1', 3);
    trace.push('ts2', 5);
    trace.push('ts3', 7);

    assert_eq!(state.get_past_total_supply('ts2'), 5);
    assert_eq!(state.get_past_total_supply('ts5'), 7);
}

#[test]
#[should_panic(expected: ('Votes: future Lookup',))]
fn test_get_past_total_supply_future_lookup() {
    let state = setup_erc721_votes();
    start_cheat_block_timestamp_global('ts1');
    state.get_past_total_supply('ts2');
}

#[test]
fn test_self_delegate() {
    let mut state = setup_erc721_votes();
    let contract_address = test_address();
    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, DELEGATOR());

    state.delegate(DELEGATOR());
    spy.assert_event_delegate_changed(contract_address, DELEGATOR(), ZERO(), DELEGATOR());
    spy
        .assert_only_event_delegate_votes_changed(
            contract_address, DELEGATOR(), 0, ERC_721_INITIAL_MINT
        );
    assert_eq!(state.get_votes(DELEGATOR()), ERC_721_INITIAL_MINT);
}

#[test]
fn test_delegate_to_recipient_updates_votes() {
    let mut state = setup_erc721_votes();
    let contract_address = test_address();
    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, DELEGATOR());

    state.delegate(DELEGATEE());
    spy.assert_event_delegate_changed(contract_address, DELEGATOR(), ZERO(), DELEGATEE());
    spy
        .assert_only_event_delegate_votes_changed(
            contract_address, DELEGATEE(), 0, ERC_721_INITIAL_MINT
        );
    assert_eq!(state.get_votes(DELEGATEE()), ERC_721_INITIAL_MINT);
    assert_eq!(state.get_votes(DELEGATOR()), 0);
}

#[test]
fn test_delegate_to_recipient_updates_delegates() {
    let mut state = setup_erc721_votes();
    start_cheat_caller_address(test_address(), DELEGATOR());
    state.delegate(DELEGATOR());
    assert_eq!(state.delegates(DELEGATOR()), DELEGATOR());
    state.delegate(DELEGATEE());
    assert_eq!(state.delegates(DELEGATOR()), DELEGATEE());
}

#[test]
fn test_delegate_by_sig() {
    // Set up the state
    // start_cheat_chain_id_global('SN_TEST');
    let mut state = setup_erc721_votes();
    let contract_address = test_address();
    start_cheat_block_timestamp_global('ts1');

    // Generate a key pair and set up an account
    let key_pair = StarkCurveKeyPairImpl::generate();
    let account = setup_account(key_pair.public_key);

    // Set up delegation parameters
    let nonce = 0;
    let expiry = 'ts2';
    let delegator = account;
    let delegatee = DELEGATEE();

    // Create and sign the delegation message
    let delegation = Delegation { delegatee, nonce, expiry };
    let msg_hash = delegation.get_message_hash(delegator);
    let (r, s) = key_pair.sign(msg_hash).unwrap();

    // Set up event spy and execute delegation
    let mut spy = spy_events();
    state.delegate_by_sig(delegator, delegatee, nonce, expiry, array![r, s]);

    spy.assert_only_event_delegate_changed(contract_address, delegator, ZERO(), delegatee);
    assert_eq!(state.delegates(account), delegatee);
}

#[test]
#[should_panic(expected: ('Votes: expired signature',))]
fn test_delegate_by_sig_past_expiry() {
    start_cheat_block_timestamp_global('ts5');

    let mut state = setup_erc721_votes();
    let expiry = 'ts4';
    let signature = array![0, 0];

    state.delegate_by_sig(DELEGATOR(), DELEGATEE(), 0, expiry, signature);
}

#[test]
#[should_panic(expected: ('Nonces: invalid nonce',))]
fn test_delegate_by_sig_invalid_nonce() {
    let mut state = setup_erc721_votes();
    let signature = array![0, 0];

    state.delegate_by_sig(DELEGATOR(), DELEGATEE(), 1, 0, signature);
}

#[test]
#[should_panic(expected: ('Votes: invalid signature',))]
fn test_delegate_by_sig_invalid_signature() {
    let mut state = setup_erc721_votes();
    let key_pair = StarkCurveKeyPairImpl::generate();
    let account = setup_account(key_pair.public_key);

    let nonce = 0;
    let expiry = 'ts2';
    let delegator = account;
    let delegatee = DELEGATEE();
    let delegation = Delegation { delegatee, nonce, expiry };
    let msg_hash = delegation.get_message_hash(delegator);
    let (r, s) = key_pair.sign(msg_hash).unwrap();

    start_cheat_block_timestamp_global('ts1');
    // Use an invalid signature
    state.delegate_by_sig(delegator, delegatee, nonce, expiry, array![r + 1, s]);
}

//
// Tests specific to ERC721Votes and ERC20Votes
//

#[test]
fn test_erc721_get_voting_units() {
    let state = setup_erc721_votes();

    assert_eq!(state.get_voting_units(DELEGATOR()), ERC_721_INITIAL_MINT);
    assert_eq!(state.get_voting_units(OTHER()), 0);
}

#[test]
fn test_erc20_get_voting_units() {
    let mut state = setup_erc20_votes();

    assert_eq!(state.get_voting_units(DELEGATOR()), SUPPLY);
    assert_eq!(state.get_voting_units(OTHER()), 0);
}

#[test]
fn test_erc20_burn_updates_votes() {
    let mut state = setup_erc20_votes();
    let mut mock_state = ERC20VOTES_CONTRACT_STATE();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, DELEGATOR());
    start_cheat_block_timestamp_global('ts1');

    state.delegate(DELEGATOR());

    // Burn some tokens
    let burn_amount = 1000;
    mock_state.erc20.burn(DELEGATOR(), burn_amount);

    // We need to move the timestamp forward to be able to call get_past_total_supply
    start_cheat_block_timestamp_global('ts2');
    assert_eq!(state.get_votes(DELEGATOR()), SUPPLY - burn_amount);
    assert_eq!(state.get_past_total_supply('ts1'), SUPPLY - burn_amount);
}

#[test]
fn test_erc721_burn_updates_votes() {
    let mut state = setup_erc721_votes();
    let mut mock_state = ERC721VOTES_CONTRACT_STATE();
    let contract_address = test_address();
    start_cheat_caller_address(contract_address, DELEGATOR());
    start_cheat_block_timestamp_global('ts1');

    state.delegate(DELEGATOR());

    // Burn some tokens
    let burn_amount = 3;
    let mut i: u256 = 0;
    while i < burn_amount {
        mock_state.erc721.burn(i);
        i += 1;
    };

    // We need to move the timestamp forward to be able to call get_past_total_supply
    start_cheat_block_timestamp_global('ts2');
    assert_eq!(state.get_votes(DELEGATOR()), ERC_721_INITIAL_MINT - burn_amount);
    assert_eq!(state.get_past_total_supply('ts1'), ERC_721_INITIAL_MINT - burn_amount);
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
        let expected = VotesComponent::Event::DelegateChanged(
            DelegateChanged { delegator, from_delegate, to_delegate }
        );
        self.assert_emitted_single(contract, expected);
    }

    fn assert_event_delegate_votes_changed(
        ref self: EventSpy,
        contract: ContractAddress,
        delegate: ContractAddress,
        previous_votes: u256,
        new_votes: u256
    ) {
        let expected = VotesComponent::Event::DelegateVotesChanged(
            DelegateVotesChanged { delegate, previous_votes, new_votes }
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

