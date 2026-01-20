use core::num::traits::Zero;
use openzeppelin_test_common::erc1155::{
    deploy_another_account_at, get_ids_and_values, setup_account,
};
use openzeppelin_test_common::mocks::erc1155::ERC1155SupplyMock;
use openzeppelin_testing::constants::{
    EMPTY_DATA, RECIPIENT, TOKEN_ID, TOKEN_ID_2, TOKEN_VALUE, TOKEN_VALUE_2,
};
use snforge_std::{start_cheat_caller_address, test_address};
use starknet::ContractAddress;
use crate::erc1155::ERC1155Component::{ERC1155Impl, InternalImpl as ERC1155InternalImpl};
use crate::erc1155::extensions::erc1155_supply::ERC1155SupplyComponent::ERC1155SupplyImpl;

//
// Setup
//

fn CONTRACT_STATE() -> ERC1155SupplyMock::ContractState {
    ERC1155SupplyMock::contract_state_for_testing()
}

fn setup() -> (ERC1155SupplyMock::ContractState, ContractAddress) {
    let mut contract_state = CONTRACT_STATE();
    contract_state.erc1155.initializer("URI");
    let owner = setup_account();
    let token_ids = array![TOKEN_ID, TOKEN_ID_2].span();
    let values = array![TOKEN_VALUE, TOKEN_VALUE_2].span();

    contract_state.erc1155.batch_mint_with_acceptance_check(owner, token_ids, values, EMPTY_DATA());

    (contract_state, owner)
}

//
// total_supply
//

#[test]
fn test_total_supply_initially_zero() {
    let mut contract_state = CONTRACT_STATE();
    contract_state.erc1155.initializer("URI");

    assert!(contract_state.erc1155_supply.total_supply(TOKEN_ID).is_zero());
    assert!(contract_state.erc1155_supply.total_supply_all().is_zero());
    assert!(!contract_state.erc1155_supply.exists(TOKEN_ID));
}

#[test]
fn test_total_supply_after_single_mint() {
    let mut contract_state = CONTRACT_STATE();
    contract_state.erc1155.initializer("URI");
    let owner = setup_account();

    contract_state.erc1155.mint_with_acceptance_check(owner, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());

    assert_eq!(contract_state.erc1155_supply.total_supply(TOKEN_ID), TOKEN_VALUE);
    assert_eq!(contract_state.erc1155_supply.total_supply_all(), TOKEN_VALUE);
    assert!(contract_state.erc1155_supply.exists(TOKEN_ID));
}

#[test]
fn test_total_supply_after_batch_mint() {
    let mut contract_state = CONTRACT_STATE();
    contract_state.erc1155.initializer("URI");
    let owner = setup_account();
    let (token_ids, values) = get_ids_and_values();

    contract_state.erc1155.batch_mint_with_acceptance_check(owner, token_ids, values, EMPTY_DATA());

    assert_eq!(contract_state.erc1155_supply.total_supply(TOKEN_ID), TOKEN_VALUE);
    assert_eq!(contract_state.erc1155_supply.total_supply(TOKEN_ID_2), TOKEN_VALUE_2);
    assert_eq!(contract_state.erc1155_supply.total_supply_all(), TOKEN_VALUE + TOKEN_VALUE_2);
}

#[test]
fn test_total_supply_unchanged_on_transfer() {
    let (mut contract_state, owner) = setup();
    let contract_address = test_address();
    let recipient = RECIPIENT;
    deploy_another_account_at(owner, recipient);

    start_cheat_caller_address(contract_address, owner);

    contract_state
        .erc1155
        .safe_transfer_from(owner, recipient, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());

    assert_eq!(contract_state.erc1155_supply.total_supply(TOKEN_ID), TOKEN_VALUE);
    assert_eq!(contract_state.erc1155_supply.total_supply(TOKEN_ID_2), TOKEN_VALUE_2);
    assert_eq!(contract_state.erc1155_supply.total_supply_all(), TOKEN_VALUE + TOKEN_VALUE_2);
}

#[test]
fn test_total_supply_after_burn() {
    let (mut contract_state, owner) = setup();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, owner);
    contract_state.erc1155.burn(owner, TOKEN_ID, TOKEN_VALUE);

    assert!(contract_state.erc1155_supply.total_supply(TOKEN_ID).is_zero());
    assert_eq!(contract_state.erc1155_supply.total_supply(TOKEN_ID_2), TOKEN_VALUE_2);
    assert_eq!(contract_state.erc1155_supply.total_supply_all(), TOKEN_VALUE_2);
    assert!(!contract_state.erc1155_supply.exists(TOKEN_ID));
}

#[test]
fn test_total_supply_after_batch_burn() {
    let (mut contract_state, owner) = setup();
    let (token_ids, values) = get_ids_and_values();
    let contract_address = test_address();

    start_cheat_caller_address(contract_address, owner);
    contract_state.erc1155.batch_burn(owner, token_ids, values);

    assert!(contract_state.erc1155_supply.total_supply(TOKEN_ID).is_zero());
    assert!(contract_state.erc1155_supply.total_supply(TOKEN_ID_2).is_zero());
    assert!(contract_state.erc1155_supply.total_supply_all().is_zero());
    assert!(!contract_state.erc1155_supply.exists(TOKEN_ID_2));
}

#[test]
fn test_total_supply_after_partial_batch_burn() {
    let (mut contract_state, owner) = setup();
    let contract_address = test_address();
    let token_ids = array![TOKEN_ID, TOKEN_ID_2].span();
    let partial_burn_value = TOKEN_VALUE / 2;
    let values = array![partial_burn_value, TOKEN_VALUE_2].span();

    start_cheat_caller_address(contract_address, owner);
    contract_state.erc1155.batch_burn(owner, token_ids, values);

    assert_eq!(
        contract_state.erc1155_supply.total_supply(TOKEN_ID), TOKEN_VALUE - partial_burn_value,
    );
    assert!(contract_state.erc1155_supply.total_supply(TOKEN_ID_2).is_zero());
    assert_eq!(contract_state.erc1155_supply.total_supply_all(), TOKEN_VALUE - partial_burn_value);
    assert!(contract_state.erc1155_supply.exists(TOKEN_ID));
    assert!(!contract_state.erc1155_supply.exists(TOKEN_ID_2));
}

#[test]
fn test_total_supply_unchanged_on_batch_transfer() {
    let (mut contract_state, owner) = setup();
    let contract_address = test_address();
    let recipient = RECIPIENT;
    let (token_ids, values) = get_ids_and_values();
    deploy_another_account_at(owner, recipient);

    start_cheat_caller_address(contract_address, owner);

    contract_state
        .erc1155
        .safe_batch_transfer_from(owner, recipient, token_ids, values, EMPTY_DATA());

    assert_eq!(contract_state.erc1155_supply.total_supply(TOKEN_ID), TOKEN_VALUE);
    assert_eq!(contract_state.erc1155_supply.total_supply(TOKEN_ID_2), TOKEN_VALUE_2);
    assert_eq!(contract_state.erc1155_supply.total_supply_all(), TOKEN_VALUE + TOKEN_VALUE_2);
}

#[test]
fn test_total_supply_accumulates_on_multiple_mints() {
    let mut contract_state = CONTRACT_STATE();
    contract_state.erc1155.initializer("URI");
    let owner = setup_account();

    contract_state.erc1155.mint_with_acceptance_check(owner, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
    assert_eq!(contract_state.erc1155_supply.total_supply(TOKEN_ID), TOKEN_VALUE);

    contract_state.erc1155.mint_with_acceptance_check(owner, TOKEN_ID, TOKEN_VALUE_2, EMPTY_DATA());
    assert_eq!(contract_state.erc1155_supply.total_supply(TOKEN_ID), TOKEN_VALUE + TOKEN_VALUE_2);
    assert_eq!(contract_state.erc1155_supply.total_supply_all(), TOKEN_VALUE + TOKEN_VALUE_2);
}

#[test]
fn test_total_supply_after_partial_burn() {
    let (mut contract_state, owner) = setup();
    let contract_address = test_address();
    let partial_burn_value = TOKEN_VALUE / 2;

    start_cheat_caller_address(contract_address, owner);
    contract_state.erc1155.burn(owner, TOKEN_ID, partial_burn_value);

    assert_eq!(
        contract_state.erc1155_supply.total_supply(TOKEN_ID), TOKEN_VALUE - partial_burn_value,
    );
    assert_eq!(contract_state.erc1155_supply.total_supply(TOKEN_ID_2), TOKEN_VALUE_2);
    assert_eq!(
        contract_state.erc1155_supply.total_supply_all(),
        TOKEN_VALUE - partial_burn_value + TOKEN_VALUE_2,
    );
    assert!(contract_state.erc1155_supply.exists(TOKEN_ID));
}

#[test]
fn test_total_supply_after_mixed_operations() {
    let mut contract_state = CONTRACT_STATE();
    contract_state.erc1155.initializer("URI");
    let owner = setup_account();
    let recipient = RECIPIENT;
    let contract_address = test_address();
    deploy_another_account_at(owner, recipient);

    // Mint token
    contract_state.erc1155.mint_with_acceptance_check(owner, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
    assert_eq!(contract_state.erc1155_supply.total_supply(TOKEN_ID), TOKEN_VALUE);
    assert_eq!(contract_state.erc1155_supply.total_supply_all(), TOKEN_VALUE);

    // Transfer (should not change supply)
    start_cheat_caller_address(contract_address, owner);
    contract_state
        .erc1155
        .safe_transfer_from(owner, recipient, TOKEN_ID, TOKEN_VALUE / 2, EMPTY_DATA());
    assert_eq!(contract_state.erc1155_supply.total_supply(TOKEN_ID), TOKEN_VALUE);
    assert_eq!(contract_state.erc1155_supply.total_supply_all(), TOKEN_VALUE);

    // Burn from recipient
    start_cheat_caller_address(contract_address, recipient);
    contract_state.erc1155.burn(recipient, TOKEN_ID, TOKEN_VALUE / 2);
    assert_eq!(contract_state.erc1155_supply.total_supply(TOKEN_ID), TOKEN_VALUE / 2);
    assert_eq!(contract_state.erc1155_supply.total_supply_all(), TOKEN_VALUE / 2);
}

#[test]
fn test_exists_returns_false_for_never_minted_token() {
    let mut contract_state = CONTRACT_STATE();
    contract_state.erc1155.initializer("URI");
    let never_minted_token_id = TOKEN_ID + 1000;

    assert!(!contract_state.erc1155_supply.exists(never_minted_token_id));
    assert!(contract_state.erc1155_supply.total_supply(never_minted_token_id).is_zero());
}

#[test]
fn test_total_supply_all_with_multiple_tokens() {
    let mut contract_state = CONTRACT_STATE();
    contract_state.erc1155.initializer("URI");
    let owner = setup_account();
    let token_id_3 = TOKEN_ID_2 + 1;
    let value_3 = TOKEN_VALUE + TOKEN_VALUE_2;

    contract_state.erc1155.mint_with_acceptance_check(owner, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
    contract_state
        .erc1155
        .mint_with_acceptance_check(owner, TOKEN_ID_2, TOKEN_VALUE_2, EMPTY_DATA());
    contract_state.erc1155.mint_with_acceptance_check(owner, token_id_3, value_3, EMPTY_DATA());

    assert_eq!(contract_state.erc1155_supply.total_supply(TOKEN_ID), TOKEN_VALUE);
    assert_eq!(contract_state.erc1155_supply.total_supply(TOKEN_ID_2), TOKEN_VALUE_2);
    assert_eq!(contract_state.erc1155_supply.total_supply(token_id_3), value_3);
    assert_eq!(
        contract_state.erc1155_supply.total_supply_all(), TOKEN_VALUE + TOKEN_VALUE_2 + value_3,
    );
}

#[test]
fn test_exists_after_complete_burn() {
    let mut contract_state = CONTRACT_STATE();
    contract_state.erc1155.initializer("URI");
    let owner = setup_account();
    let contract_address = test_address();

    contract_state.erc1155.mint_with_acceptance_check(owner, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
    assert!(contract_state.erc1155_supply.exists(TOKEN_ID));

    start_cheat_caller_address(contract_address, owner);
    contract_state.erc1155.burn(owner, TOKEN_ID, TOKEN_VALUE);

    assert!(!contract_state.erc1155_supply.exists(TOKEN_ID));
    assert!(contract_state.erc1155_supply.total_supply(TOKEN_ID).is_zero());
    assert!(contract_state.erc1155_supply.total_supply_all().is_zero());
}
