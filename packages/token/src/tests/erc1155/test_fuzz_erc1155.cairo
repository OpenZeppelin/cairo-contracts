use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin_test_common::common::repeat;
use openzeppelin_test_common::erc1155::{
    ERC1155SpyHelpers, deploy_another_account_at, setup_account, setup_receiver,
};
use openzeppelin_test_common::mocks::erc1155::DualCaseERC1155Mock;
use openzeppelin_testing::constants::{BASE_URI, EMPTY_DATA, OPERATOR, RECIPIENT};
use openzeppelin_testing::spy_events;
use snforge_std::cheatcodes::generate_arg::generate_arg;
use snforge_std::fuzzable::Fuzzable;
use snforge_std::{start_cheat_caller_address, test_address};
use starknet::ContractAddress;
use crate::erc1155::ERC1155Component;
use crate::erc1155::ERC1155Component::{
    ERC1155CamelImpl, ERC1155Impl, ERC1155MetadataURIImpl, InternalImpl,
};

//
// Setup
//

type ComponentState = ERC1155Component::ComponentState<DualCaseERC1155Mock::ContractState>;

fn COMPONENT_STATE() -> ComponentState {
    ERC1155Component::component_state_for_testing()
}

const MIN_IDS_LEN: u32 = 2;
const MAX_IDS_LEN: u32 = 10;

const MIN_VALUE_MULT: u32 = 1;
const MAX_VALUE_MULT: u32 = 1_000_000;

#[derive(Copy, Drop, Debug)]
struct TokenList {
    ids: Span<u256>,
    values: Span<u256>,
}

impl TokenListFuzzable of Fuzzable<TokenList> {
    fn blank() -> TokenList {
        TokenList { ids: array![].span(), values: array![].span() }
    }

    fn generate() -> TokenList {
        let total_ids_len = generate_arg(MIN_IDS_LEN, MAX_IDS_LEN);
        let value_multiplier = generate_arg(MIN_VALUE_MULT, MAX_VALUE_MULT);
        let mut token_ids: Array<u256> = array![];
        let mut values: Array<u256> = array![];
        for i in 0..total_ids_len {
            let index = i + 1; // Starts from 1
            let id = 'TOKEN'.into() + index.into();
            let value = (index * value_multiplier).into();
            token_ids.append(id);
            values.append(value);
        }
        TokenList { ids: token_ids.span(), values: values.span() }
    }
}

fn resolve_single_transfer_info(
    tokens: TokenList, transfer_id_seed: u32, transfer_value_seed: u32,
) -> (u256, u256) {
    let transfer_index = generate_arg(0, tokens.ids.len() - 1);
    let transfer_id = *tokens.ids.at(transfer_index);
    let token_value: u32 = (*tokens.values.at(transfer_index)).try_into().unwrap();
    let transfer_value = generate_arg(0, token_value).into();
    (transfer_id, transfer_value)
}

fn resolve_batch_transfer_info(
    tokens: TokenList, batch_len_seed: u32, transfer_value_seed: u32,
) -> TokenList {
    let mut ids = array![];
    let mut values = array![];
    let min_batch_len = 2;
    let batch_len = generate_arg(min_batch_len, tokens.ids.len());
    for i in 0..batch_len {
        let token_id = *tokens.ids.at(i);
        let balance_value: u32 = (*tokens.values.at(i)).try_into().unwrap();
        let transfer_value = generate_arg(0, balance_value).into();
        ids.append(token_id);
        values.append(transfer_value);
    }
    TokenList { ids: ids.span(), values: values.span() }
}

fn calculate_expected_balances(
    initial_tokens: TokenList, transfers: TokenList,
) -> (TokenList, TokenList) {
    let mut owner_balances = array![];
    let mut recipient_balances = array![];
    for i in 0..initial_tokens.ids.len() {
        let initial_balance = *initial_tokens.values.at(i);
        let transferred = if transfers.ids.len() > i {
            *transfers.values.at(i)
        } else {
            0
        };
        owner_balances.append(initial_balance - transferred);
        recipient_balances.append(transferred);
    }
    let owner_tokens = TokenList { ids: initial_tokens.ids, values: owner_balances.span() };
    let recipient_tokens = TokenList { ids: initial_tokens.ids, values: recipient_balances.span() };
    (owner_tokens, recipient_tokens)
}

fn setup(tokens: TokenList) -> (ComponentState, ContractAddress) {
    let mut state = COMPONENT_STATE();
    state.initializer(BASE_URI());

    let owner = setup_account();
    state.batch_mint_with_acceptance_check(owner, tokens.ids, tokens.values, array![].span());

    (state, owner)
}

//
// balance_of & balanceOf
//

#[test]
#[fuzzer]
fn test_balance_of(tokens: TokenList) {
    let (state, owner) = setup(tokens);
    for i in 0..tokens.ids.len() {
        let id = *tokens.ids.at(i);
        let value = *tokens.values.at(i);
        let balance = state.balance_of(owner, id);
        assert_eq!(balance, value);
    };
}

#[test]
#[fuzzer]
fn test_balanceOf(tokens: TokenList) {
    let (state, owner) = setup(tokens);
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
#[fuzzer]
fn test_balance_of_batch(tokens: TokenList) {
    let (state, owner) = setup(tokens);
    let accounts = repeat(owner, tokens.ids.len()).span();
    let balances = state.balance_of_batch(accounts, tokens.ids);
    for i in 0..tokens.ids.len() {
        let balance = *balances.at(i);
        let value = *tokens.values.at(i);
        assert_eq!(balance, value);
    };
}

#[test]
#[fuzzer]
fn test_balanceOfBatch(tokens: TokenList) {
    let (state, owner) = setup(tokens);
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
#[fuzzer]
fn test_safe_transfer_from_owner_to_receiver(
    tokens: TokenList, transfer_id_seed: u32, transfer_value_seed: u32,
) {
    let (mut state, owner) = setup(tokens);
    let (transfer_id, transfer_value) = resolve_single_transfer_info(
        tokens, transfer_id_seed, transfer_value_seed,
    );
    let recipient = setup_receiver();
    let contract_address = test_address();
    let mut spy = spy_events();

    assert_balance(recipient, transfer_id, 0);
    start_cheat_caller_address(contract_address, owner);
    state.safe_transfer_from(owner, recipient, transfer_id, transfer_value, EMPTY_DATA());
    spy
        .assert_only_event_transfer_single(
            contract_address, owner, owner, recipient, transfer_id, transfer_value,
        );

    assert_balance(recipient, transfer_id, transfer_value);
}

#[test]
#[fuzzer]
fn test_safeTransferFrom_owner_to_receiver(
    tokens: TokenList, transfer_id_seed: u32, transfer_value_seed: u32,
) {
    let (mut state, owner) = setup(tokens);
    let (transfer_id, transfer_value) = resolve_single_transfer_info(
        tokens, transfer_id_seed, transfer_value_seed,
    );
    let recipient = setup_receiver();
    let contract_address = test_address();
    let mut spy = spy_events();

    assert_balance(recipient, transfer_id, 0);
    start_cheat_caller_address(contract_address, owner);
    state.safeTransferFrom(owner, recipient, transfer_id, transfer_value, EMPTY_DATA());
    spy
        .assert_only_event_transfer_single(
            contract_address, owner, owner, recipient, transfer_id, transfer_value,
        );

    assert_balance(recipient, transfer_id, transfer_value);
}

#[test]
#[fuzzer]
fn test_safe_transfer_from_owner_to_account(
    tokens: TokenList, transfer_id_seed: u32, transfer_value_seed: u32,
) {
    let (mut state, owner) = setup(tokens);
    let (transfer_id, transfer_value) = resolve_single_transfer_info(
        tokens, transfer_id_seed, transfer_value_seed,
    );
    let contract_address = test_address();
    deploy_another_account_at(owner, RECIPIENT);
    let mut spy = spy_events();

    assert_balance(RECIPIENT, transfer_id, 0);
    start_cheat_caller_address(contract_address, owner);
    state.safe_transfer_from(owner, RECIPIENT, transfer_id, transfer_value, EMPTY_DATA());
    spy
        .assert_only_event_transfer_single(
            contract_address, owner, owner, RECIPIENT, transfer_id, transfer_value,
        );

    assert_balance(RECIPIENT, transfer_id, transfer_value);
}

#[test]
#[fuzzer]
fn test_safeTransferFrom_owner_to_account(
    tokens: TokenList, transfer_id_seed: u32, transfer_value_seed: u32,
) {
    let (mut state, owner) = setup(tokens);
    let (transfer_id, transfer_value) = resolve_single_transfer_info(
        tokens, transfer_id_seed, transfer_value_seed,
    );
    deploy_another_account_at(owner, RECIPIENT);
    let mut spy = spy_events();
    let contract_address = test_address();

    assert_balance(RECIPIENT, transfer_id, 0);
    start_cheat_caller_address(contract_address, owner);
    state.safeTransferFrom(owner, RECIPIENT, transfer_id, transfer_value, EMPTY_DATA());
    spy
        .assert_only_event_transfer_single(
            contract_address, owner, owner, RECIPIENT, transfer_id, transfer_value,
        );

    assert_balance(RECIPIENT, transfer_id, transfer_value);
}

#[test]
#[fuzzer]
fn test_safe_transfer_from_approved_operator(
    tokens: TokenList, transfer_id_seed: u32, transfer_value_seed: u32,
) {
    let (mut state, owner) = setup(tokens);
    let (transfer_id, transfer_value) = resolve_single_transfer_info(
        tokens, transfer_id_seed, transfer_value_seed,
    );
    deploy_another_account_at(owner, RECIPIENT);
    let mut spy = spy_events();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, owner);
    state.set_approval_for_all(OPERATOR, true);
    spy.assert_only_event_approval_for_all(contract_address, owner, OPERATOR, true);

    assert_balance(RECIPIENT, transfer_id, 0);

    start_cheat_caller_address(contract_address, OPERATOR);
    state.safe_transfer_from(owner, RECIPIENT, transfer_id, transfer_value, EMPTY_DATA());
    spy
        .assert_only_event_transfer_single(
            contract_address, OPERATOR, owner, RECIPIENT, transfer_id, transfer_value,
        );

    assert_balance(RECIPIENT, transfer_id, transfer_value);
}

#[test]
#[fuzzer]
fn test_safeTransferFrom_approved_operator(
    tokens: TokenList, transfer_id_seed: u32, transfer_value_seed: u32,
) {
    let (mut state, owner) = setup(tokens);
    let (transfer_id, transfer_value) = resolve_single_transfer_info(
        tokens, transfer_id_seed, transfer_value_seed,
    );
    deploy_another_account_at(owner, RECIPIENT);
    let contract_address = test_address();
    let mut spy = spy_events();

    start_cheat_caller_address(contract_address, owner);
    state.set_approval_for_all(OPERATOR, true);
    spy.assert_only_event_approval_for_all(contract_address, owner, OPERATOR, true);

    assert_balance(RECIPIENT, transfer_id, 0);

    start_cheat_caller_address(contract_address, OPERATOR);
    state.safeTransferFrom(owner, RECIPIENT, transfer_id, transfer_value, EMPTY_DATA());
    spy
        .assert_only_event_transfer_single(
            contract_address, OPERATOR, owner, RECIPIENT, transfer_id, transfer_value,
        );

    assert_balance(RECIPIENT, transfer_id, transfer_value);
}

//
// safe_batch_transfer_from & safeBatchTransferFrom
//

#[test]
#[fuzzer]
fn test_safe_batch_transfer_from_owner_to_receiver(
    tokens: TokenList, batch_len_seed: u32, transfer_value_seed: u32,
) {
    let (mut state, owner) = setup(tokens);
    let transfers = resolve_batch_transfer_info(tokens, batch_len_seed, transfer_value_seed);
    let recipient = setup_receiver();
    let contract_address = test_address();
    let mut spy = spy_events();

    start_cheat_caller_address(contract_address, owner);
    state.safe_batch_transfer_from(owner, recipient, transfers.ids, transfers.values, EMPTY_DATA());
    spy
        .assert_only_event_transfer_batch(
            contract_address, owner, owner, recipient, transfers.ids, transfers.values,
        );

    let (owner_balances, recipient_balances) = calculate_expected_balances(tokens, transfers);
    assert_balance_of_batch(owner, owner_balances);
    assert_balance_of_batch(recipient, recipient_balances);
}

#[test]
#[fuzzer]
fn test_safeBatchTransferFrom_owner_to_receiver(
    tokens: TokenList, batch_len_seed: u32, transfer_value_seed: u32,
) {
    let (mut state, owner) = setup(tokens);
    let transfers = resolve_batch_transfer_info(tokens, batch_len_seed, transfer_value_seed);
    let recipient = setup_receiver();
    let contract_address = test_address();
    let mut spy = spy_events();

    start_cheat_caller_address(contract_address, owner);
    state.safeBatchTransferFrom(owner, recipient, transfers.ids, transfers.values, EMPTY_DATA());
    spy
        .assert_only_event_transfer_batch(
            contract_address, owner, owner, recipient, transfers.ids, transfers.values,
        );

    let (owner_balances, recipient_balances) = calculate_expected_balances(tokens, transfers);
    assert_balance_of_batch(owner, owner_balances);
    assert_balance_of_batch(recipient, recipient_balances);
}

#[test]
#[fuzzer]
fn test_safe_batch_transfer_from_owner_to_account(
    tokens: TokenList, batch_len_seed: u32, transfer_value_seed: u32,
) {
    let (mut state, owner) = setup(tokens);
    let transfers = resolve_batch_transfer_info(tokens, batch_len_seed, transfer_value_seed);
    deploy_another_account_at(owner, RECIPIENT);
    let contract_address = test_address();
    let mut spy = spy_events();

    start_cheat_caller_address(contract_address, owner);
    state.safe_batch_transfer_from(owner, RECIPIENT, transfers.ids, transfers.values, EMPTY_DATA());
    spy
        .assert_only_event_transfer_batch(
            contract_address, owner, owner, RECIPIENT, transfers.ids, transfers.values,
        );

    let (owner_balances, recipient_balances) = calculate_expected_balances(tokens, transfers);
    assert_balance_of_batch(owner, owner_balances);
    assert_balance_of_batch(RECIPIENT, recipient_balances);
}

#[test]
#[fuzzer]
fn test_safeBatchTransferFrom_owner_to_account(
    tokens: TokenList, batch_len_seed: u32, transfer_value_seed: u32,
) {
    let (mut state, owner) = setup(tokens);
    let transfers = resolve_batch_transfer_info(tokens, batch_len_seed, transfer_value_seed);
    deploy_another_account_at(owner, RECIPIENT);
    let contract_address = test_address();
    let mut spy = spy_events();

    start_cheat_caller_address(contract_address, owner);
    state.safeBatchTransferFrom(owner, RECIPIENT, transfers.ids, transfers.values, EMPTY_DATA());
    spy
        .assert_only_event_transfer_batch(
            contract_address, owner, owner, RECIPIENT, transfers.ids, transfers.values,
        );

    let (owner_balances, recipient_balances) = calculate_expected_balances(tokens, transfers);
    assert_balance_of_batch(owner, owner_balances);
    assert_balance_of_batch(RECIPIENT, recipient_balances);
}

#[test]
#[fuzzer]
fn test_safe_batch_transfer_from_approved_operator(
    tokens: TokenList, batch_len_seed: u32, transfer_value_seed: u32,
) {
    let (mut state, owner) = setup(tokens);
    let transfers = resolve_batch_transfer_info(tokens, batch_len_seed, transfer_value_seed);
    deploy_another_account_at(owner, RECIPIENT);
    let contract_address = test_address();
    let mut spy = spy_events();

    start_cheat_caller_address(contract_address, owner);
    state.set_approval_for_all(OPERATOR, true);
    spy.assert_only_event_approval_for_all(contract_address, owner, OPERATOR, true);

    start_cheat_caller_address(contract_address, OPERATOR);
    state.safe_batch_transfer_from(owner, RECIPIENT, transfers.ids, transfers.values, EMPTY_DATA());
    spy
        .assert_only_event_transfer_batch(
            contract_address, OPERATOR, owner, RECIPIENT, transfers.ids, transfers.values,
        );

    let (owner_balances, recipient_balances) = calculate_expected_balances(tokens, transfers);
    assert_balance_of_batch(owner, owner_balances);
    assert_balance_of_batch(RECIPIENT, recipient_balances);
}

#[test]
#[fuzzer]
fn test_safeBatchTransferFrom_approved_operator(
    tokens: TokenList, batch_len_seed: u32, transfer_value_seed: u32,
) {
    let (mut state, owner) = setup(tokens);
    let transfers = resolve_batch_transfer_info(tokens, batch_len_seed, transfer_value_seed);
    deploy_another_account_at(owner, RECIPIENT);
    let contract_address = test_address();
    let mut spy = spy_events();

    start_cheat_caller_address(contract_address, owner);
    state.set_approval_for_all(OPERATOR, true);
    spy.assert_only_event_approval_for_all(contract_address, owner, OPERATOR, true);

    start_cheat_caller_address(contract_address, OPERATOR);
    state.safeBatchTransferFrom(owner, RECIPIENT, transfers.ids, transfers.values, EMPTY_DATA());
    spy
        .assert_only_event_transfer_batch(
            contract_address, OPERATOR, owner, RECIPIENT, transfers.ids, transfers.values,
        );

    let (owner_balances, recipient_balances) = calculate_expected_balances(tokens, transfers);
    assert_balance_of_batch(owner, owner_balances);
    assert_balance_of_batch(RECIPIENT, recipient_balances);
}

//
// Helpers
//

fn assert_balance(account: ContractAddress, token_id: u256, expected_balance: u256) {
    let state = COMPONENT_STATE();
    assert_eq!(state.balance_of(account, token_id), expected_balance);
}

fn assert_balance_of_batch(account: ContractAddress, tokens: TokenList) {
    let state = COMPONENT_STATE();
    let balances = state.balance_of_batch(repeat(account, tokens.ids.len()).span(), tokens.ids);
    assert_eq!(balances, tokens.values);
}
