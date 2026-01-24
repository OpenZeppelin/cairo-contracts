use openzeppelin_interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait};
use openzeppelin_test_common::erc721::ERC721SpyHelpers;
use openzeppelin_test_common::mocks::erc721::{
    IERC721BurnableDispatcher, IERC721BurnableDispatcherTrait, IERC721ConsecutiveMintableDispatcher,
    IERC721ConsecutiveMintableDispatcherTrait,
};
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{BASE_URI, NAME, OTHER, RECIPIENT, SYMBOL, ZERO};
use openzeppelin_testing::spy_events;
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::start_cheat_caller_address;
use starknet::ContractAddress;

fn deploy_consecutive_mock(recipient: ContractAddress, batch_size: u64) -> IERC721Dispatcher {
    let mut calldata: Array<felt252> = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(recipient);
    calldata.append_serde(batch_size);

    let contract_address = utils::declare_and_deploy("ERC721ConsecutiveMock", calldata);
    IERC721Dispatcher { contract_address }
}

fn deploy_consecutive_multi_batch_mock(
    first_recipient: ContractAddress,
    first_batch_size: u64,
    second_recipient: ContractAddress,
    second_batch_size: u64,
) -> IERC721Dispatcher {
    let mut calldata: Array<felt252> = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(first_recipient);
    calldata.append_serde(first_batch_size);
    calldata.append_serde(second_recipient);
    calldata.append_serde(second_batch_size);

    let contract_address = utils::declare_and_deploy("ERC721ConsecutiveMultiBatchMock", calldata);
    IERC721Dispatcher { contract_address }
}

fn consecutive_minter(address: ContractAddress) -> IERC721ConsecutiveMintableDispatcher {
    IERC721ConsecutiveMintableDispatcher { contract_address: address }
}

fn consecutive_burner(address: ContractAddress) -> IERC721BurnableDispatcher {
    IERC721BurnableDispatcher { contract_address: address }
}

#[test]
fn test_constructor_mints_consecutive_tokens() {
    let batch_size = 100;
    let token = deploy_consecutive_mock(RECIPIENT, batch_size);

    assert_eq!(token.balance_of(RECIPIENT), batch_size.into());
    assert_eq!(token.owner_of(0), RECIPIENT);
    let last_token_id: u256 = (batch_size - 1).into();
    assert_eq!(token.owner_of(last_token_id), RECIPIENT);
}

#[test]
fn test_constructor_mints_multiple_batches() {
    let first_batch_size: u64 = 3;
    let second_batch_size: u64 = 2;
    let token = deploy_consecutive_multi_batch_mock(
        RECIPIENT, first_batch_size, OTHER, second_batch_size,
    );

    assert_eq!(token.balance_of(RECIPIENT), first_batch_size.into());
    assert_eq!(token.balance_of(OTHER), second_batch_size.into());

    assert_eq!(token.owner_of(0), RECIPIENT);
    let first_last: u256 = (first_batch_size - 1).into();
    assert_eq!(token.owner_of(first_last), RECIPIENT);

    let second_first: u256 = first_batch_size.into();
    assert_eq!(token.owner_of(second_first), OTHER);
    let second_last: u256 = (first_batch_size + second_batch_size - 1).into();
    assert_eq!(token.owner_of(second_last), OTHER);
}

#[test]
#[should_panic(expected: 'ERC721: forbidden batch mint')]
fn test_mint_consecutive_outside_constructor_panics() {
    let token = deploy_consecutive_mock(RECIPIENT, 1);
    let minter = consecutive_minter(token.contract_address);
    minter.mint_consecutive(RECIPIENT, 1);
}

#[test]
fn test_balance_after_constructor_batch_mint() {
    let batch_size = 100;
    let token = deploy_consecutive_mock(RECIPIENT, batch_size);

    assert_eq!(token.balance_of(RECIPIENT), batch_size.into());
}

#[test]
fn test_balance_after_transfers_and_burns() {
    let batch_size = 100;
    let token = deploy_consecutive_mock(RECIPIENT, batch_size);
    let contract_address = token.contract_address;
    let burner = consecutive_burner(contract_address);

    start_cheat_caller_address(contract_address, RECIPIENT);

    // Move two tokens out and burn two tokens in-range.
    token.transfer_from(RECIPIENT, OTHER, 10);
    token.transfer_from(RECIPIENT, OTHER, 20);
    burner.burn(30);
    burner.burn(40);

    assert_eq!(token.balance_of(RECIPIENT), (batch_size - 4).into());
    assert_eq!(token.balance_of(OTHER), 2);
}

#[test]
fn test_owner_of_first_middle_last() {
    let batch_size = 100;
    let token = deploy_consecutive_mock(RECIPIENT, batch_size);

    // Covers the start, middle, and end of the consecutive range.
    let first_token_id: u256 = 0;
    assert_eq!(token.owner_of(first_token_id), RECIPIENT);

    let middle_token_id: u256 = 50;
    assert_eq!(token.owner_of(middle_token_id), RECIPIENT);

    let last_token_id: u256 = (batch_size - 1).into();
    assert_eq!(token.owner_of(last_token_id), RECIPIENT);
}

#[test]
#[should_panic(expected: 'ERC721: invalid token ID')]
fn test_owner_of_out_of_range_panics() {
    let batch_size = 100;
    let token = deploy_consecutive_mock(RECIPIENT, batch_size);

    // The first out-of-range id should revert.
    let invalid_token_id: u256 = batch_size.into();
    token.owner_of(invalid_token_id);
}

#[test]
#[should_panic(expected: 'ERC721: invalid token ID')]
fn test_owner_of_zero_batch_size_panics() {
    let batch_size = 0;
    let token = deploy_consecutive_mock(RECIPIENT, batch_size);

    // No tokens exist, so querying token 0 must revert.
    token.owner_of(0);
}

#[test]
fn test_zero_batch_size_balance_is_zero() {
    let batch_size = 0;
    let token = deploy_consecutive_mock(RECIPIENT, batch_size);

    // Constructor should mint nothing when batch size is zero.
    assert_eq!(token.balance_of(RECIPIENT), 0);
}

#[test]
fn test_burn_emits_transfer_and_updates_balance() {
    let batch_size = 100;
    let token = deploy_consecutive_mock(RECIPIENT, batch_size);
    let contract_address = token.contract_address;
    let burner = consecutive_burner(contract_address);

    let token_id: u256 = 50;

    // Initial state sanity check.
    assert_eq!(token.owner_of(token_id), RECIPIENT);
    assert_eq!(token.balance_of(RECIPIENT), batch_size.into());

    // Burn the token and capture the transfer-to-zero event.
    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, RECIPIENT);
    burner.burn(token_id);

    assert_eq!(token.balance_of(RECIPIENT), (batch_size - 1).into());
    spy.assert_event_transfer(contract_address, RECIPIENT, ZERO, token_id.into());
}

#[test]
#[should_panic(expected: 'ERC721: invalid token ID')]
fn test_burn_out_of_range_panics() {
    let batch_size = 100;
    let token = deploy_consecutive_mock(RECIPIENT, batch_size);
    let contract_address = token.contract_address;
    let burner = consecutive_burner(contract_address);

    let invalid_token_id: u256 = batch_size.into();
    start_cheat_caller_address(contract_address, RECIPIENT);
    burner.burn(invalid_token_id);
}

#[test]
#[should_panic(expected: 'ERC721: invalid token ID')]
fn test_owner_of_after_burn_panics() {
    let batch_size = 100;
    let token = deploy_consecutive_mock(RECIPIENT, batch_size);
    let contract_address = token.contract_address;
    let burner = consecutive_burner(contract_address);

    let token_id: u256 = 10;
    start_cheat_caller_address(contract_address, RECIPIENT);

    burner.burn(token_id);
    token.owner_of(token_id);
}

#[test]
fn test_transfer_updates_owner_balance_and_emits_event() {
    let batch_size = 100;
    let token = deploy_consecutive_mock(RECIPIENT, batch_size);
    let contract_address = token.contract_address;

    let token_id: u256 = 50;

    // Initial state sanity check.
    assert_eq!(token.owner_of(token_id), RECIPIENT);
    assert_eq!(token.balance_of(RECIPIENT), batch_size.into());
    assert_eq!(token.balance_of(OTHER), 0);

    // Transfer token and verify event.
    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, RECIPIENT);
    token.transfer_from(RECIPIENT, OTHER, token_id);

    assert_eq!(token.owner_of(token_id), OTHER);
    assert_eq!(token.balance_of(RECIPIENT), (batch_size - 1).into());
    assert_eq!(token.balance_of(OTHER), 1);

    spy.assert_event_transfer(contract_address, RECIPIENT, OTHER, token_id.into());
}

#[test]
fn test_transfer_keeps_other_tokens_in_consecutive_range() {
    let batch_size = 100;
    let token = deploy_consecutive_mock(RECIPIENT, batch_size);
    let contract_address = token.contract_address;

    let token_id: u256 = 10;
    let untouched_token_id: u256 = 11;

    start_cheat_caller_address(contract_address, RECIPIENT);

    token.transfer_from(RECIPIENT, OTHER, token_id);

    assert_eq!(token.owner_of(token_id), OTHER);
    assert_eq!(token.owner_of(untouched_token_id), RECIPIENT);
}

#[test]
fn test_transfer_back_and_forth() {
    let batch_size = 100;
    let token = deploy_consecutive_mock(RECIPIENT, batch_size);
    let contract_address = token.contract_address;

    let token_id: u256 = 50;

    start_cheat_caller_address(contract_address, RECIPIENT);

    token.transfer_from(RECIPIENT, OTHER, token_id);
    assert_eq!(token.owner_of(token_id), OTHER);
    assert_eq!(token.balance_of(RECIPIENT), (batch_size - 1).into());
    assert_eq!(token.balance_of(OTHER), 1);

    start_cheat_caller_address(contract_address, OTHER);
    token.transfer_from(OTHER, RECIPIENT, token_id);
    assert_eq!(token.owner_of(token_id), RECIPIENT);
    assert_eq!(token.balance_of(RECIPIENT), batch_size.into());
    assert_eq!(token.balance_of(OTHER), 0);
}

#[test]
fn test_consecutive_transfer_event() {
    let batch_size = 100;
    let mut spy = spy_events();

    let token = deploy_consecutive_mock(RECIPIENT, batch_size);
    let contract_address = token.contract_address;

    // Constructor should emit the consecutive transfer event.
    spy
        .assert_event_consecutive_transfer(
            contract_address, 0, (batch_size - 1).into(), ZERO, RECIPIENT,
        );
}

#[test]
fn test_consecutive_transfer_event_multiple_batches() {
    let first_batch_size: u64 = 3;
    let second_batch_size: u64 = 2;
    let mut spy = spy_events();

    let token = deploy_consecutive_multi_batch_mock(
        RECIPIENT, first_batch_size, OTHER, second_batch_size,
    );
    let contract_address = token.contract_address;

    let first_last: u256 = (first_batch_size - 1).into();
    spy.assert_event_consecutive_transfer(contract_address, 0, first_last, ZERO, RECIPIENT);

    let second_first: u256 = first_batch_size.into();
    let second_last: u256 = (first_batch_size + second_batch_size - 1).into();
    spy.assert_event_consecutive_transfer(contract_address, second_first, second_last, ZERO, OTHER);
}

#[test]
fn test_consecutive_transfer_event_single_token() {
    let batch_size = 1;
    let mut spy = spy_events();

    let token = deploy_consecutive_mock(RECIPIENT, batch_size);
    let contract_address = token.contract_address;

    // Single-token batch should have from_token_id == to_token_id.
    spy.assert_event_consecutive_transfer(contract_address, 0, 0, ZERO, RECIPIENT);
}

#[test]
fn test_large_batch_size() {
    let batch_size = 5000;
    let token = deploy_consecutive_mock(RECIPIENT, batch_size);

    assert_eq!(token.balance_of(RECIPIENT), batch_size.into());

    // Boundary tokens in a max-size batch should resolve to the recipient.
    assert_eq!(token.owner_of(0), RECIPIENT);
    let last_token_id: u256 = (batch_size - 1).into();
    assert_eq!(token.owner_of(last_token_id), RECIPIENT);
}

#[test]
#[should_panic(expected: 'ERC721: invalid token ID')]
fn test_transfer_from_burned_token_panics() {
    let batch_size = 100;
    let token = deploy_consecutive_mock(RECIPIENT, batch_size);
    let contract_address = token.contract_address;
    let burner = consecutive_burner(contract_address);

    let token_id: u256 = 50;

    start_cheat_caller_address(contract_address, RECIPIENT);
    burner.burn(token_id);

    token.transfer_from(RECIPIENT, OTHER, token_id);
}
