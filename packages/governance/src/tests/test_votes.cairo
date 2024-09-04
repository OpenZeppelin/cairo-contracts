use openzeppelin_governance::tests::mocks::votes_mocks::ERC721VotesMock::SNIP12MetadataImpl;
use openzeppelin_governance::tests::mocks::votes_mocks::{ERC721VotesMock, ERC20VotesMock};
use openzeppelin_governance::votes::interface::TokenVotesTrait;
use openzeppelin_governance::votes::votes::VotesComponent::{
    DelegateChanged, DelegateVotesChanged, VotesImpl, InternalImpl,
};
use openzeppelin_governance::votes::votes::VotesComponent;
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{SUPPLY, ZERO, OWNER, RECIPIENT};
use openzeppelin_testing::events::EventSpyExt;
use openzeppelin_token::erc20::ERC20Component::InternalTrait;
use openzeppelin_token::erc721::ERC721Component::{
    ERC721MetadataImpl, InternalImpl as ERC721InternalImpl,
};
use openzeppelin_token::erc721::ERC721Component::{ERC721Impl, ERC721CamelOnlyImpl};
use openzeppelin_utils::structs::checkpoint::TraceTrait;
use snforge_std::signature::stark_curve::{StarkCurveKeyPairImpl, StarkCurveSignerImpl};
use snforge_std::{
    cheat_block_timestamp_global, start_cheat_caller_address, spy_events, test_address
};
use snforge_std::{EventSpy};
use starknet::ContractAddress;


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
    // Mint 10 NFTs to OWNER
    let mut i: u256 = 0;
    loop {
        if i >= 10 {
            break;
        }
        mock_state.erc721.mint(OWNER(), i);
        // We manually transfer voting units here, since this is usually implemented in the hook
        state.transfer_voting_units(ZERO(), OWNER(), 1);
        i += 1;
    };
    state
}

fn setup_erc20_votes() -> ERC20ComponentState {
    let mut state = ERC20_COMPONENT_STATE();
    let mut mock_state = ERC20VOTES_CONTRACT_STATE();

    // Mint SUPPLY tokens to owner
    mock_state.erc20.mint(OWNER(), SUPPLY);
    // We manually transfer voting units here, since this is usually implemented in the hook
    state.transfer_voting_units(ZERO(), OWNER(), 1);

    state
}

fn setup_account(public_key: felt252) -> ContractAddress {
    let mut calldata = array![public_key];
    utils::declare_and_deploy("DualCaseAccountMock", calldata)
}

//
// Common tests for Votes
//

#[test]
fn test_get_votes() {
    let mut state = setup_erc721_votes();
    start_cheat_caller_address(test_address(), OWNER());
    // Before delegating, the owner has 0 votes
    assert_eq!(state.get_votes(OWNER()), 0);
    state.delegate(OWNER());

    assert_eq!(state.get_votes(OWNER()), 10);
}

// This test can be improved by using the api of the component
// to add checkpoints and thus verify the internal state of the component
// instead of using the trace directly.
#[test]
fn test_get_past_votes() {
    let mut state = setup_erc721_votes();
    let mut trace = state.Votes_delegate_checkpoints.read(OWNER());

    cheat_block_timestamp_global('ts10');

    trace.push('ts1', 3);
    trace.push('ts2', 5);
    trace.push('ts3', 7);

    assert_eq!(state.get_past_votes(OWNER(), 'ts2'), 5);
    assert_eq!(state.get_past_votes(OWNER(), 'ts5'), 7);
}

#[test]
#[should_panic(expected: ('Votes: future Lookup',))]
fn test_get_past_votes_future_lookup() {
    let state = setup_erc721_votes();
    cheat_block_timestamp_global('ts1');
    state.get_past_votes(OWNER(), 'ts2');
}

#[test]
fn test_get_past_total_supply() {
    let mut state = setup_erc721_votes();
    let mut trace = state.Votes_total_checkpoints.read();

    cheat_block_timestamp_global('ts10');
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
    cheat_block_timestamp_global('ts1');
    state.get_past_total_supply('ts2');
}

#[test]
fn test_self_delegate() {
    let mut state = setup_erc721_votes();
    let contract_address = test_address();
    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, OWNER());

    state.delegate(OWNER());
    spy.assert_event_delegate_changed(contract_address, OWNER(), ZERO(), OWNER());
    spy.assert_only_event_delegate_votes_changed(contract_address, OWNER(), 0, 10);
    assert_eq!(state.get_votes(OWNER()), 10);
}

#[test]
fn test_delegate_to_recipient_updates_votes() {
    let mut state = setup_erc721_votes();
    let contract_address = test_address();
    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, OWNER());

    state.delegate(RECIPIENT());
    spy.assert_event_delegate_changed(contract_address, OWNER(), ZERO(), RECIPIENT());
    spy.assert_only_event_delegate_votes_changed(contract_address, RECIPIENT(), 0, 10);
    assert_eq!(state.get_votes(RECIPIENT()), 10);
    assert_eq!(state.get_votes(OWNER()), 0);
}

#[test]
fn test_delegate_to_recipient_updates_delegates() {
    let mut state = setup_erc721_votes();
    start_cheat_caller_address(test_address(), OWNER());
    state.delegate(OWNER());
    assert_eq!(state.delegates(OWNER()), OWNER());
    state.delegate(RECIPIENT());
    assert_eq!(state.delegates(OWNER()), RECIPIENT());
}

// #[test]
// fn test_delegate_by_sig() {
//     cheat_chain_id_global('SN_TEST');
//     cheat_block_timestamp_global('ts1');
//     let mut state = setup_erc721_votes();
//     let contract_address = test_address();
//     let key_pair = KeyPairTrait::generate();
//     let account = setup_account(key_pair.public_key);
//     let nonce = 0;
//     let expiry = 'ts2';
//     let delegator = account;
//     let delegatee = RECIPIENT();
//     let delegation = Delegation { delegatee, nonce, expiry };
//     let msg_hash = delegation.get_message_hash(delegator);
//     let (r, s) = key_pair.sign(msg_hash).unwrap();
//     let mut spy = spy_events();
//     state.delegate_by_sig(delegator, delegatee, nonce, expiry, array![r, s]);
//     spy.assert_only_event_delegate_changed(contract_address, delegator, ZERO(), delegatee);
//     assert_eq!(state.delegates(account), delegatee);
// }

#[test]
#[should_panic(expected: ('Votes: expired signature',))]
fn test_delegate_by_sig_past_expiry() {
    cheat_block_timestamp_global('ts5');

    let mut state = setup_erc721_votes();
    let expiry = 'ts4';
    let signature = array![0, 0];

    state.delegate_by_sig(OWNER(), RECIPIENT(), 0, expiry, signature);
}

#[test]
#[should_panic(expected: ('Nonces: invalid nonce',))]
fn test_delegate_by_sig_invalid_nonce() {
    let mut state = setup_erc721_votes();
    let signature = array![0, 0];

    state.delegate_by_sig(OWNER(), RECIPIENT(), 1, 0, signature);
}

// #[test]
// #[should_panic(expected: ('Votes: invalid signature',))]
// fn test_delegate_by_sig_invalid_signature() {
//     let mut state = setup_erc721_votes();
//     // For some reason this is panicking before we get to delegate_by_sig
//     let account = setup_account(0x123);
//     let signature = array![0, 0];

//     state.delegate_by_sig(account, RECIPIENT(), 0, 0, signature);
// }

//
// Tests specific to ERC721Votes and
//

#[test]
fn test_erc721_get_voting_units() {
    let state = setup_erc721_votes();

    assert_eq!(state.get_voting_units(OWNER()), 10);
    assert_eq!(state.get_voting_units(RECIPIENT()), 0);
}

#[test]
fn test_erc20_get_voting_units() {
    let mut state = setup_erc20_votes();

    assert_eq!(state.get_voting_units(OWNER()), SUPPLY);
    assert_eq!(state.get_voting_units(RECIPIENT()), 0);
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

