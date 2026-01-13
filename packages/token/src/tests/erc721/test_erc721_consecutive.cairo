use openzeppelin_test_common::erc721::ERC721SpyHelpers;
use openzeppelin_test_common::mocks::erc721::ERC721ConsecutiveMock;
use openzeppelin_testing::constants::{BASE_URI, NAME, OTHER, RECIPIENT, SYMBOL, ZERO};
use openzeppelin_testing::spy_events;
use openzeppelin_utils::structs::checkpoint::TraceTrait;
use snforge_std::{start_cheat_caller_address, test_address};
use starknet::ContractAddress;
use crate::erc721::ERC721Component;
use crate::erc721::ERC721Component::{
    ConsecutiveERC721OwnerOfTraitImpl, ERC721Impl, InternalImpl as ERC721InternalImpl,
};
use crate::erc721::extensions::ERC721ConsecutiveComponent::{
    HasComponent, InternalImpl as ERC721ConsecutiveInternalImpl,
};
use crate::erc721::extensions::{DefaultConfig, ERC721ConsecutiveComponent};

//
// Setup
//

type ComponentState = ERC721Component::ComponentState<ERC721ConsecutiveMock::ContractState>;
type ConsecutiveState =
    ERC721ConsecutiveComponent::ComponentState<ERC721ConsecutiveMock::ContractState>;

fn COMPONENT_STATE() -> ComponentState {
    ERC721Component::component_state_for_testing()
}

fn CONSECUTIVE_STATE() -> ConsecutiveState {
    ERC721ConsecutiveComponent::component_state_for_testing()
}

fn mint_consecutive_for_testing(
    ref erc721_state: ComponentState,
    ref consecutive_state: ConsecutiveState,
    recipient: ContractAddress,
    batch_size: u64,
) {
    if batch_size == 0 {
        return;
    }

    let first_token_id = consecutive_state.first_consecutive_id();
    let last_token_id = first_token_id + batch_size - 1;

    let recipient_felt: felt252 = recipient.into();
    let recipient_u256: u256 = recipient_felt.into();
    let mut ownership = consecutive_state.ERC721Consecutive_sequential_ownership.deref();
    ownership.push(last_token_id, recipient_u256);

    let batch_size_u128: u128 = batch_size.into();
    erc721_state.increase_balance(recipient, batch_size_u128);

    consecutive_state
        .emit(
            ERC721ConsecutiveComponent::ConsecutiveTransfer {
                from_token_id: first_token_id.into(),
                to_token_id: last_token_id.into(),
                from_address: ZERO,
                to_address: recipient,
            },
        );
}

fn setup(recipient: ContractAddress, batch_size: u64) -> (ComponentState, ContractAddress) {
    let contract_address = test_address();
    let mut erc721_state = COMPONENT_STATE();
    let mut consecutive_state = CONSECUTIVE_STATE();

    erc721_state.initializer(NAME(), SYMBOL(), BASE_URI());
    mint_consecutive_for_testing(ref erc721_state, ref consecutive_state, recipient, batch_size);

    (erc721_state, contract_address)
}

fn owner_of(token: @ComponentState, token_id: u256) -> ContractAddress {
    ERC721InternalImpl::_require_owned(token, token_id)
}

#[test]
fn test_balance_after_constructor_batch_mint() {
    let batch_size = 100;
    let (token, _) = setup(RECIPIENT, batch_size);

    assert_eq!(token.balance_of(RECIPIENT), batch_size.into());
}

#[test]
fn test_balance_after_transfers_and_burns() {
    let batch_size = 100;
    let (mut token, contract_address) = setup(RECIPIENT, batch_size);

    start_cheat_caller_address(contract_address, RECIPIENT);

    // Move two tokens out and burn two tokens in-range.
    token.transfer_from(RECIPIENT, OTHER, 10.into());
    token.transfer_from(RECIPIENT, OTHER, 20.into());
    token.burn(30.into());
    token.burn(40.into());

    assert_eq!(token.balance_of(RECIPIENT), (batch_size - 4).into());
    assert_eq!(token.balance_of(OTHER), 2);
}

#[test]
fn test_owner_of_first_middle_last() {
    let batch_size = 100;
    let (token, _) = setup(RECIPIENT, batch_size);

    // Covers the start, middle, and end of the consecutive range.
    let first_token_id: u256 = 0;
    assert_eq!(owner_of(@token, first_token_id), RECIPIENT);

    let middle_token_id: u256 = 50;
    assert_eq!(owner_of(@token, middle_token_id), RECIPIENT);

    let last_token_id: u256 = (batch_size - 1).into();
    assert_eq!(owner_of(@token, last_token_id), RECIPIENT);
}

#[test]
#[should_panic(expected: 'ERC721: invalid token ID')]
fn test_owner_of_out_of_range_panics() {
    let batch_size = 100;
    let (token, _) = setup(RECIPIENT, batch_size);

    // The first out-of-range id should revert.
    let invalid_token_id: u256 = batch_size.into();
    owner_of(@token, invalid_token_id);
}

#[test]
#[should_panic(expected: 'ERC721: invalid token ID')]
fn test_owner_of_zero_batch_size_panics() {
    let batch_size = 0;
    let (token, _) = setup(RECIPIENT, batch_size);

    // No tokens exist, so querying token 0 must revert.
    owner_of(@token, 0);
}

#[test]
fn test_zero_batch_size_balance_is_zero() {
    let batch_size = 0;
    let (token, _) = setup(RECIPIENT, batch_size);

    // Constructor should mint nothing when batch size is zero.
    assert_eq!(token.balance_of(RECIPIENT), 0);
}

#[test]
fn test_burn_emits_transfer_and_updates_balance() {
    let batch_size = 100;
    let (mut token, contract_address) = setup(RECIPIENT, batch_size);

    let token_id: u256 = 50;

    // Initial state sanity check.
    assert_eq!(owner_of(@token, token_id), RECIPIENT);
    assert_eq!(token.balance_of(RECIPIENT), batch_size.into());

    // Burn the token and capture the transfer-to-zero event.
    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, RECIPIENT);
    token.burn(token_id);

    assert_eq!(token.balance_of(RECIPIENT), (batch_size - 1).into());
    spy.assert_event_transfer(contract_address, RECIPIENT, ZERO, token_id.into());
}

#[test]
#[should_panic(expected: 'ERC721: invalid token ID')]
fn test_burn_out_of_range_panics() {
    let batch_size = 100;
    let (mut token, contract_address) = setup(RECIPIENT, batch_size);

    let invalid_token_id: u256 = batch_size.into();
    start_cheat_caller_address(contract_address, RECIPIENT);
    token.burn(invalid_token_id);
}

#[test]
#[should_panic(expected: 'ERC721: invalid token ID')]
fn test_owner_of_after_burn_panics() {
    let batch_size = 100;
    let (mut token, contract_address) = setup(RECIPIENT, batch_size);

    let token_id: u256 = 10;
    start_cheat_caller_address(contract_address, RECIPIENT);

    token.burn(token_id);
    owner_of(@token, token_id);
}

#[test]
fn test_transfer_updates_owner_balance_and_emits_event() {
    let batch_size = 100;
    let (mut token, contract_address) = setup(RECIPIENT, batch_size);

    let token_id: u256 = 50;

    // Initial state sanity check.
    assert_eq!(owner_of(@token, token_id), RECIPIENT);
    assert_eq!(token.balance_of(RECIPIENT), batch_size.into());
    assert_eq!(token.balance_of(OTHER), 0);

    // Transfer token and verify event.
    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, RECIPIENT);
    token.transfer_from(RECIPIENT, OTHER, token_id);

    assert_eq!(owner_of(@token, token_id), OTHER);
    assert_eq!(token.balance_of(RECIPIENT), (batch_size - 1).into());
    assert_eq!(token.balance_of(OTHER), 1);

    spy.assert_event_transfer(contract_address, RECIPIENT, OTHER, token_id.into());
}

#[test]
fn test_transfer_keeps_other_tokens_in_consecutive_range() {
    let batch_size = 100;
    let (mut token, contract_address) = setup(RECIPIENT, batch_size);

    let token_id: u256 = 10;
    let untouched_token_id: u256 = 11;

    start_cheat_caller_address(contract_address, RECIPIENT);

    token.transfer_from(RECIPIENT, OTHER, token_id);

    assert_eq!(owner_of(@token, token_id), OTHER);
    assert_eq!(owner_of(@token, untouched_token_id), RECIPIENT);
}

#[test]
fn test_transfer_back_and_forth() {
    let batch_size = 100;
    let (mut token, contract_address) = setup(RECIPIENT, batch_size);

    let token_id: u256 = 50;

    start_cheat_caller_address(contract_address, RECIPIENT);

    token.transfer_from(RECIPIENT, OTHER, token_id);
    assert_eq!(owner_of(@token, token_id), OTHER);
    assert_eq!(token.balance_of(RECIPIENT), (batch_size - 1).into());
    assert_eq!(token.balance_of(OTHER), 1);

    start_cheat_caller_address(contract_address, OTHER);
    token.transfer_from(OTHER, RECIPIENT, token_id);
    assert_eq!(owner_of(@token, token_id), RECIPIENT);
    assert_eq!(token.balance_of(RECIPIENT), batch_size.into());
    assert_eq!(token.balance_of(OTHER), 0);
}

#[test]
fn test_consecutive_transfer_event() {
    let batch_size = 100;
    let mut spy = spy_events();

    let (_, contract_address) = setup(RECIPIENT, batch_size);

    // Constructor should emit the consecutive transfer event.
    spy
        .assert_event_consecutive_transfer(
            contract_address, 0, (batch_size - 1).into(), ZERO, RECIPIENT,
        );
}

#[test]
fn test_consecutive_transfer_event_single_token() {
    let batch_size = 1;
    let mut spy = spy_events();

    let (_, contract_address) = setup(RECIPIENT, batch_size);

    // Single-token batch should have from_token_id == to_token_id.
    spy.assert_event_consecutive_transfer(contract_address, 0, 0, ZERO, RECIPIENT);
}

#[test]
fn test_large_batch_size() {
    let batch_size = 5000;
    let (token, _) = setup(RECIPIENT, batch_size);

    assert_eq!(token.balance_of(RECIPIENT), batch_size.into());

    // Boundary tokens in a max-size batch should resolve to the recipient.
    assert_eq!(owner_of(@token, 0), RECIPIENT);
    let last_token_id: u256 = (batch_size - 1).into();
    assert_eq!(owner_of(@token, last_token_id), RECIPIENT);
}

#[test]
#[should_panic(expected: 'ERC721: invalid token ID')]
fn test_transfer_from_burned_token_panics() {
    let batch_size = 100;
    let (mut token, contract_address) = setup(RECIPIENT, batch_size);

    let token_id: u256 = 50;

    start_cheat_caller_address(contract_address, RECIPIENT);
    token.burn(token_id);

    token.transfer_from(RECIPIENT, OTHER, token_id);
}
