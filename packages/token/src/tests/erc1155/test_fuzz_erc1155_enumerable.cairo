use crate::erc1155::ERC1155Component;
use crate::erc1155::ERC1155Component::ERC1155CamelImpl;
use crate::erc1155::ERC1155Component::{ERC1155Impl, ERC1155MetadataURIImpl, InternalImpl};
use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin_test_common::erc1155::ERC1155SpyHelpers;
use openzeppelin_test_common::erc1155::{deploy_another_account_at, setup_account, setup_receiver};
use openzeppelin_test_common::mocks::erc1155::{DualCaseERC1155Mock, SnakeERC1155MockWithHooks};
use openzeppelin_testing::constants::{EMPTY_DATA, BASE_URI, RECIPIENT, OPERATOR};
use openzeppelin_testing::common::repeat;

use snforge_std::{spy_events, start_cheat_caller_address, test_address};
use starknet::ContractAddress;

//
// Setup
//

type ComponentState = ERC1155Component::ComponentState<DualCaseERC1155Mock::ContractState>;
type ComponentStateWithHooks =
    ERC1155Component::ComponentState<SnakeERC1155MockWithHooks::ContractState>;

fn CONTRACT_STATE() -> DualCaseERC1155Mock::ContractState {
    DualCaseERC1155Mock::contract_state_for_testing()
}
fn COMPONENT_STATE() -> ComponentState {
    ERC1155Component::component_state_for_testing()
}
fn COMPONENT_STATE_WITH_HOOKS() -> ComponentStateWithHooks {
    ERC1155Component::component_state_for_testing()
}

const MIN_IDS_LEN: u32 = 1;
const MAX_IDS_LEN: u32 = 10;

const MIN_VALUE_MULT: u32 = 1;
const MAX_VALUE_MULT: u32 = 1_000_000;

#[derive(Copy, Drop)]
struct Tokens {
    ids: Span<u256>,
    values: Span<u256>
}

fn prepare_tokens(ids_len_seed: u32, value_mult_seed: u32) -> Tokens {
    let total_ids_len = MIN_IDS_LEN + ids_len_seed % (MAX_IDS_LEN - MIN_IDS_LEN + 1);
    let value_multiplier = MIN_VALUE_MULT + value_mult_seed % (MAX_VALUE_MULT - MIN_VALUE_MULT + 1);
    let mut token_ids = array![];
    let mut values = array![];
    for i in 0..total_ids_len {
        let index = i + 1; // Starts from 1
        let id = 'TOKEN'.into() + index.into();
        let value = (index * value_multiplier).into();
        token_ids.append(id);
        values.append(value);
    };
    Tokens { ids: token_ids.span(), values: values.span() }
}

fn resolve_transfer_info(tokens: Tokens, transfer_id_seed: u32, transfer_value_seed: u32) -> (u256, u256) {
    let transfer_index = transfer_id_seed % tokens.ids.len();
    let transfer_id = *tokens.ids.at(transfer_index);
    let token_value = *tokens.values.at(transfer_index);
    let transfer_value = transfer_value_seed.into() % token_value;
    (transfer_id, transfer_value)
}

fn setup(ids_len_seed: u32, value_mult_seed: u32) -> (ComponentState, ContractAddress, Tokens) {
    let mut state = COMPONENT_STATE();
    state.initializer(BASE_URI());

    let owner = setup_account();
    let tokens = prepare_tokens(ids_len_seed, value_mult_seed);
    state.batch_mint_with_acceptance_check(owner, tokens.ids, tokens.values, array![].span());

    (state, owner, tokens)
}

fn setup_with_hooks(ids_len_seed: u32, value_mult_seed: u32) -> (ComponentStateWithHooks, ContractAddress, Tokens) {
    let mut state = COMPONENT_STATE_WITH_HOOKS();
    state.initializer(BASE_URI());

    let owner = setup_account();
    let tokens = prepare_tokens(ids_len_seed, value_mult_seed);
    state.batch_mint_with_acceptance_check(owner, tokens.ids, tokens.values, array![].span());

    (state, owner, tokens)
}

//
// balance_of & balanceOf
//

#[test]
fn test_balance_of(ids_len_seed: u32, value_mult_seed: u32) {
    let (state, owner, tokens) = setup(ids_len_seed, value_mult_seed);
    for i in 0..tokens.ids.len() {
        let id = *tokens.ids.at(i);
        let value = *tokens.values.at(i);
        let balance = state.balance_of(owner, id);
        assert_eq!(balance, value);
    };
}

#[test]
fn test_balanceOf(ids_len_seed: u32, value_mult_seed: u32) {
    let (state, owner, tokens) = setup(ids_len_seed, value_mult_seed);
    for i in 0..tokens.ids.len() {
        let id = *tokens.ids.at(i);
        let value = *tokens.values.at(i);
        let balance = state.balanceOf(owner, id);
        assert_eq!(balance, value);
    };
}

//
// balance_of_batch & balanceOfBatch
//

#[test]
fn test_balance_of_batch(ids_len_seed: u32, value_mult_seed: u32) {
    let (state, owner, tokens) = setup(ids_len_seed, value_mult_seed);
    let accounts = repeat(owner, tokens.ids.len()).span();
    let balances = state.balance_of_batch(accounts, tokens.ids);
    for i in 0..tokens.ids.len() {
        let balance = *balances.at(i);
        let value = *tokens.values.at(i);
        assert_eq!(balance, value);
    };
}

#[test]
fn test_balanceOfBatch(ids_len_seed: u32, value_mult_seed: u32) {
    let (state, owner, tokens) = setup(ids_len_seed, value_mult_seed);
    let accounts = repeat(owner, tokens.ids.len()).span();
    let balances = state.balanceOfBatch(accounts, tokens.ids);
    for i in 0..tokens.ids.len() {
        let balance = *balances.at(i);
        let value = *tokens.values.at(i);
        assert_eq!(balance, value);
    };
}

//
// safe_transfer_from & safeTransferFrom
//

#[test]
fn test_safe_transfer_from_owner_to_receiver(ids_len_seed: u32, value_mult_seed: u32, transfer_id_seed: u32, transfer_value_seed: u32) {
    let (mut state, owner, tokens) = setup(ids_len_seed, value_mult_seed);
    let (transfer_id, transfer_value) = resolve_transfer_info(tokens, transfer_id_seed, transfer_value_seed);
    let recipient = setup_receiver();
    let contract_address = test_address();
    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, owner);

    assert_balance(recipient, transfer_id, 0);
    state.safe_transfer_from(owner, recipient, transfer_id, transfer_value, EMPTY_DATA());
    spy
        .assert_only_event_transfer_single(
            contract_address, owner, owner, recipient, transfer_id, transfer_value
        );

    assert_balance(recipient, transfer_id, transfer_value);
}

#[test]
fn test_safeTransferFrom_owner_to_receiver(ids_len_seed: u32, value_mult_seed: u32, transfer_id_seed: u32, transfer_value_seed: u32) {
    let (mut state, owner, tokens) = setup(ids_len_seed, value_mult_seed);
    let (transfer_id, transfer_value) = resolve_transfer_info(tokens, transfer_id_seed, transfer_value_seed);
    let recipient = setup_receiver();
    let contract_address = test_address();
    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, owner);

    assert_balance(recipient, transfer_id, 0);
    state.safeTransferFrom(owner, recipient, transfer_id, transfer_value, EMPTY_DATA());
    spy
        .assert_only_event_transfer_single(
            contract_address, owner, owner, recipient, transfer_id, transfer_value
        );

    assert_balance(recipient, transfer_id, transfer_value);
}

#[test]
fn test_safe_transfer_from_owner_to_account(ids_len_seed: u32, value_mult_seed: u32, transfer_id_seed: u32, transfer_value_seed: u32) {
    let (mut state, owner, tokens) = setup(ids_len_seed, value_mult_seed);
    let (transfer_id, transfer_value) = resolve_transfer_info(tokens, transfer_id_seed, transfer_value_seed);
    let recipient = RECIPIENT();
    let contract_address = test_address();
    deploy_another_account_at(owner, recipient);
    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, owner);

    assert_balance(recipient, transfer_id, 0);
    state.safe_transfer_from(owner, recipient, transfer_id, transfer_value, EMPTY_DATA());
    spy
        .assert_only_event_transfer_single(
            contract_address, owner, owner, recipient, transfer_id, transfer_value
        );

    assert_balance(recipient, transfer_id, transfer_value);
}

#[test]
fn test_safeTransferFrom_owner_to_account(ids_len_seed: u32, value_mult_seed: u32, transfer_id_seed: u32, transfer_value_seed: u32) {
    let (mut state, owner, tokens) = setup(ids_len_seed, value_mult_seed);
    let (transfer_id, transfer_value) = resolve_transfer_info(tokens, transfer_id_seed, transfer_value_seed);
    let recipient = RECIPIENT();
    deploy_another_account_at(owner, recipient);
    let mut spy = spy_events();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, owner);

    assert_balance(recipient, transfer_id, 0);
    state.safeTransferFrom(owner, recipient, transfer_id, transfer_value, EMPTY_DATA());
    spy
        .assert_only_event_transfer_single(
            contract_address, owner, owner, recipient, transfer_id, transfer_value
        );

    assert_balance(recipient, transfer_id, transfer_value);
}

#[test]
fn test_safe_transfer_from_approved_operator(ids_len_seed: u32, value_mult_seed: u32, transfer_id_seed: u32, transfer_value_seed: u32) {
    let (mut state, owner, tokens) = setup(ids_len_seed, value_mult_seed);
    let (transfer_id, transfer_value) = resolve_transfer_info(tokens, transfer_id_seed, transfer_value_seed);
    let recipient = RECIPIENT();
    deploy_another_account_at(owner, recipient);
    let operator = OPERATOR();
    let mut spy = spy_events();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, owner);
    state.set_approval_for_all(operator, true);
    spy.assert_only_event_approval_for_all(contract_address, owner, operator, true);

    assert_balance(recipient, transfer_id, 0);

    start_cheat_caller_address(contract_address, operator);
    state.safe_transfer_from(owner, recipient, transfer_id, transfer_value, EMPTY_DATA());
    spy
        .assert_only_event_transfer_single(
            contract_address, operator, owner, recipient, transfer_id, transfer_value
        );

    assert_balance(recipient, transfer_id, transfer_value);
}

#[test]
fn test_safeTransferFrom_approved_operator(ids_len_seed: u32, value_mult_seed: u32, transfer_id_seed: u32, transfer_value_seed: u32) {
    let (mut state, owner, tokens) = setup(ids_len_seed, value_mult_seed);
    let (transfer_id, transfer_value) = resolve_transfer_info(tokens, transfer_id_seed, transfer_value_seed);
    let recipient = RECIPIENT();
    deploy_another_account_at(owner, recipient);
    let operator = OPERATOR();
    let contract_address = test_address();
    let mut spy = spy_events();

    start_cheat_caller_address(contract_address, owner);
    state.set_approval_for_all(operator, true);
    spy.assert_only_event_approval_for_all(contract_address, owner, operator, true);

    assert_balance(recipient, transfer_id, 0);

    start_cheat_caller_address(contract_address, operator);
    state.safeTransferFrom(owner, recipient, transfer_id, transfer_value, EMPTY_DATA());
    spy
        .assert_only_event_transfer_single(
            contract_address, operator, owner, recipient, transfer_id, transfer_value
        );

    assert_balance(recipient, transfer_id, transfer_value);
}

//
// Helpers
//

fn assert_balance(
    account: ContractAddress, token_id: u256, expected_balance: u256
) {
    let state = COMPONENT_STATE();
    assert_eq!(state.balance_of(account, token_id), expected_balance);
}
