use core::num::traits::Bounded;
use crate::erc20::ERC20Component::InternalImpl as ERC20InternalImpl;
use crate::erc20::extensions::erc4626::DefaultConfig;
use crate::erc20::extensions::erc4626::ERC4626Component::{
    ERC4626Impl, ERC4626MetadataImpl, InternalImpl
};
use crate::erc20::extensions::erc4626::ERC4626Component::{Deposit, Withdraw};
use crate::erc20::extensions::erc4626::ERC4626Component;
use crate::erc20::extensions::erc4626::interface::{ERC4626ABIDispatcher, ERC4626ABIDispatcherTrait};
use openzeppelin_test_common::erc20::ERC20SpyHelpers;
use openzeppelin_test_common::mocks::erc20::Type;
use openzeppelin_test_common::mocks::erc20::{
    IERC20ReentrantDispatcher, IERC20ReentrantDispatcherTrait
};
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{NAME, SYMBOL, OTHER, RECIPIENT, ZERO, SPENDER};
use openzeppelin_testing::events::EventSpyExt;
use openzeppelin_utils::math;
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{cheat_caller_address, CheatSpan, spy_events, EventSpy};
use starknet::{ContractAddress, contract_address_const};

fn HOLDER() -> ContractAddress {
    contract_address_const::<'HOLDER'>()
}

fn TREASURY() -> ContractAddress {
    contract_address_const::<'TREASURY'>()
}

fn VAULT_NAME() -> ByteArray {
    "VAULT"
}

fn VAULT_SYMBOL() -> ByteArray {
    "V"
}

const DEFAULT_DECIMALS: u8 = 18;
const NO_OFFSET_DECIMALS: u8 = 0;
const OFFSET_DECIMALS: u8 = 1;

fn parse_token(token: u256) -> u256 {
    token * math::power(10, DEFAULT_DECIMALS.into())
}

fn parse_share_offset(share: u256) -> u256 {
    share * math::power(10, DEFAULT_DECIMALS.into() + OFFSET_DECIMALS.into())
}

//
// Setup
//

fn deploy_asset() -> IERC20ReentrantDispatcher {
    let mut asset_calldata: Array<felt252> = array![];
    asset_calldata.append_serde(NAME());
    asset_calldata.append_serde(SYMBOL());

    let contract_address = utils::declare_and_deploy("ERC20ReentrantMock", asset_calldata);
    IERC20ReentrantDispatcher { contract_address }
}

fn deploy_vault(asset_address: ContractAddress) -> ERC4626ABIDispatcher {
    let no_shares = 0_u256;

    let mut vault_calldata: Array<felt252> = array![];
    vault_calldata.append_serde(VAULT_NAME());
    vault_calldata.append_serde(VAULT_SYMBOL());
    vault_calldata.append_serde(asset_address);
    vault_calldata.append_serde(no_shares);
    vault_calldata.append_serde(HOLDER());

    let contract_address = utils::declare_and_deploy("ERC4626Mock", vault_calldata);
    ERC4626ABIDispatcher { contract_address }
}

fn deploy_vault_offset_minted_shares(
    asset_address: ContractAddress, shares: u256, recipient: ContractAddress
) -> ERC4626ABIDispatcher {
    let mut vault_calldata: Array<felt252> = array![];
    vault_calldata.append_serde(VAULT_NAME());
    vault_calldata.append_serde(VAULT_SYMBOL());
    vault_calldata.append_serde(asset_address);
    vault_calldata.append_serde(shares);
    vault_calldata.append_serde(recipient);

    let contract_address = utils::declare_and_deploy("ERC4626OffsetMock", vault_calldata);
    ERC4626ABIDispatcher { contract_address }
}

fn deploy_vault_offset(asset_address: ContractAddress) -> ERC4626ABIDispatcher {
    deploy_vault_offset_minted_shares(asset_address, 0, HOLDER())
}

fn deploy_vault_fees(asset_address: ContractAddress) -> ERC4626ABIDispatcher {
    let no_shares = 0_u256;
    deploy_vault_fees_with_shares(asset_address, no_shares, HOLDER())
}

fn deploy_vault_fees_with_shares(
    asset_address: ContractAddress, shares: u256, recipient: ContractAddress
) -> ERC4626ABIDispatcher {
    let fee_basis_points = 500_u256; // 5%
    let _value_without_fees = 10_000_u256;
    let _fees = (_value_without_fees * fee_basis_points) / 10_000_u256;
    let _value_with_fees = _value_without_fees - _fees;

    let mut vault_calldata: Array<felt252> = array![];
    vault_calldata.append_serde(VAULT_NAME());
    vault_calldata.append_serde(VAULT_SYMBOL());
    vault_calldata.append_serde(asset_address);
    vault_calldata.append_serde(shares);
    vault_calldata.append_serde(recipient);

    // Enter fees
    vault_calldata.append_serde(fee_basis_points);
    vault_calldata.append_serde(TREASURY());
    // No exit fees
    vault_calldata.append_serde(0_u256);
    vault_calldata.append_serde(ZERO());

    let contract_address = utils::declare_and_deploy("ERC4626FeesMock", vault_calldata);
    ERC4626ABIDispatcher { contract_address }
}

fn deploy_vault_exit_fees_with_shares(
    asset_address: ContractAddress, shares: u256, recipient: ContractAddress
) -> ERC4626ABIDispatcher {
    let fee_basis_points = 500_u256; // 5%
    let _value_without_fees = 10_000_u256;
    let _fees = (_value_without_fees * fee_basis_points) / 10_000_u256;
    let _value_with_fees = _value_without_fees - _fees;

    let mut vault_calldata: Array<felt252> = array![];
    vault_calldata.append_serde(VAULT_NAME());
    vault_calldata.append_serde(VAULT_SYMBOL());
    vault_calldata.append_serde(asset_address);
    vault_calldata.append_serde(shares);
    vault_calldata.append_serde(recipient);

    // No enter fees
    vault_calldata.append_serde(0_u256);
    vault_calldata.append_serde(ZERO());
    // Exit fees
    vault_calldata.append_serde(fee_basis_points);
    vault_calldata.append_serde(TREASURY());

    let contract_address = utils::declare_and_deploy("ERC4626FeesMock", vault_calldata);
    ERC4626ABIDispatcher { contract_address }
}

fn deploy_vault_limits(asset_address: ContractAddress) -> ERC4626ABIDispatcher {
    let no_shares = 0_u256;

    let mut vault_calldata: Array<felt252> = array![];
    vault_calldata.append_serde(VAULT_NAME());
    vault_calldata.append_serde(VAULT_SYMBOL());
    vault_calldata.append_serde(asset_address);
    vault_calldata.append_serde(no_shares);
    vault_calldata.append_serde(HOLDER());

    let contract_address = utils::declare_and_deploy("ERC4626LimitsMock", vault_calldata);
    ERC4626ABIDispatcher { contract_address }
}

//
// Metadata
//

#[test]
fn test_metadata() {
    let asset = deploy_asset();
    let vault = deploy_vault(asset.contract_address);

    let name = vault.name();
    assert_eq!(name, VAULT_NAME());

    let symbol = vault.symbol();
    assert_eq!(symbol, VAULT_SYMBOL());

    let decimals = vault.decimals();
    assert_eq!(decimals, DEFAULT_DECIMALS + NO_OFFSET_DECIMALS);

    let asset_address = vault.asset();
    assert_eq!(asset_address, asset.contract_address);
}

#[test]
fn test_decimals_offset() {
    let asset = deploy_asset();
    let vault = deploy_vault_offset(asset.contract_address);

    let decimals = vault.decimals();
    assert_eq!(decimals, DEFAULT_DECIMALS + OFFSET_DECIMALS);
}

//
// Empty vault: no assets, no shares
//

fn setup_empty() -> (IERC20ReentrantDispatcher, ERC4626ABIDispatcher) {
    let mut asset = deploy_asset();
    let mut vault = deploy_vault_offset(asset.contract_address);

    // Mint assets to HOLDER and approve vault
    asset.unsafe_mint(HOLDER(), Bounded::MAX / 2); // 50% of max
    cheat_caller_address(asset.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    asset.approve(vault.contract_address, Bounded::MAX);

    (asset, vault)
}

#[test]
fn test_init_vault_status() {
    let (_, vault) = setup_empty();
    let total_assets = vault.total_assets();

    assert_eq!(total_assets, 0);
}

#[test]
fn test_deposit() {
    let (asset, vault) = setup_empty();
    let amount = parse_token(1);

    // Check max deposit
    let max_deposit = vault.max_deposit(HOLDER());
    assert_eq!(max_deposit, Bounded::MAX);

    // Check preview == expected shares
    let preview_deposit = vault.preview_deposit(amount);
    let exp_shares = parse_share_offset(1);
    assert_eq!(preview_deposit, exp_shares);

    let holder_balance_before = asset.balance_of(HOLDER());
    let mut spy = spy_events();

    // Deposit
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    let shares = vault.deposit(amount, RECIPIENT());

    // Check balances
    let holder_balance_after = asset.balance_of(HOLDER());
    assert_eq!(holder_balance_after, holder_balance_before - amount);

    let recipient_shares = vault.balance_of(RECIPIENT());
    assert_eq!(recipient_shares, exp_shares);

    // Check events
    spy.assert_event_transfer(asset.contract_address, HOLDER(), vault.contract_address, amount);
    spy.assert_event_transfer(vault.contract_address, ZERO(), RECIPIENT(), shares);
    spy.assert_only_event_deposit(vault.contract_address, HOLDER(), RECIPIENT(), amount, shares);
}

#[test]
fn test_mint() {
    let (asset, vault) = setup_empty();

    // Check max mint
    let max_mint = vault.max_mint(HOLDER());
    assert_eq!(max_mint, Bounded::MAX);

    // Check preview mint
    let preview_mint = vault.preview_mint(parse_share_offset(1));
    let exp_assets = parse_token(1);
    assert_eq!(preview_mint, exp_assets);

    let mut spy = spy_events();
    let holder_balance_before = asset.balance_of(HOLDER());

    // Mint
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.mint(parse_share_offset(1), RECIPIENT());

    // Check balances
    let holder_balance_after = asset.balance_of(HOLDER());
    assert_eq!(holder_balance_after, holder_balance_before - parse_token(1));

    let recipient_shares = vault.balance_of(RECIPIENT());
    assert_eq!(recipient_shares, parse_share_offset(1));

    // Check events
    spy
        .assert_event_transfer(
            asset.contract_address, HOLDER(), vault.contract_address, parse_token(1)
        );
    spy.assert_event_transfer(vault.contract_address, ZERO(), RECIPIENT(), parse_share_offset(1));
    spy
        .assert_only_event_deposit(
            vault.contract_address, HOLDER(), RECIPIENT(), parse_token(1), parse_share_offset(1)
        );
}

#[test]
fn test_withdraw() {
    let (asset, vault) = setup_empty();

    // Check max mint
    let max_withdraw = vault.max_withdraw(HOLDER());
    assert_eq!(max_withdraw, 0);

    // Check preview mint
    let preview_withdraw = vault.preview_withdraw(0);
    assert_eq!(preview_withdraw, 0);

    let mut spy = spy_events();

    // Withdraw
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.withdraw(0, RECIPIENT(), HOLDER());

    // Check events
    spy.assert_event_transfer(vault.contract_address, HOLDER(), ZERO(), 0);
    spy.assert_event_transfer(asset.contract_address, vault.contract_address, RECIPIENT(), 0);
    spy.assert_only_event_withdraw(vault.contract_address, HOLDER(), RECIPIENT(), HOLDER(), 0, 0);
}

#[test]
fn test_redeem() {
    let (asset, vault) = setup_empty();

    // Check max redeem
    let max_redeem = vault.max_redeem(HOLDER());
    assert_eq!(max_redeem, 0);

    // Check preview redeem
    let preview_redeem = vault.preview_redeem(0);
    assert_eq!(preview_redeem, 0);

    let mut spy = spy_events();

    // Redeem
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.redeem(0, RECIPIENT(), HOLDER());

    // Check events
    spy.assert_event_transfer(vault.contract_address, HOLDER(), ZERO(), 0);
    spy.assert_event_transfer(asset.contract_address, vault.contract_address, RECIPIENT(), 0);
    spy.assert_only_event_withdraw(vault.contract_address, HOLDER(), RECIPIENT(), HOLDER(), 0, 0);
}

//
// Inflation attack: Offset price by direct deposit of assets
//

fn setup_inflation_attack() -> (IERC20ReentrantDispatcher, ERC4626ABIDispatcher) {
    let mut asset = deploy_asset();
    let mut vault = deploy_vault_offset(asset.contract_address);

    // Mint assets to HOLDER and approve vault
    asset.unsafe_mint(HOLDER(), Bounded::MAX / 2); // 50% of max
    cheat_caller_address(asset.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    asset.approve(vault.contract_address, Bounded::MAX);

    // Donate 1 token to the vault to offset the price
    asset.unsafe_mint(vault.contract_address, parse_token(1));

    (asset, vault)
}

#[test]
fn test_inflation_attack_status() {
    let (_, vault) = setup_inflation_attack();

    let total_supply = vault.total_supply();
    assert_eq!(total_supply, 0);

    let total_assets = vault.total_assets();
    assert_eq!(total_assets, parse_token(1));
}

#[test]
fn test_inflation_attack_deposit() {
    let (asset, vault) = setup_inflation_attack();
    let virtual_assets = 1;
    let offset = 1;
    let virtual_shares = math::power(10, offset);

    let effective_assets = vault.total_assets() + virtual_assets;
    let effective_shares = vault.total_supply() + virtual_shares;

    let deposit_assets = parse_token(1);
    let expected_shares = (deposit_assets * effective_shares) / effective_assets;

    // Check max deposit
    let max_deposit = vault.max_deposit(HOLDER());
    assert_eq!(max_deposit, Bounded::MAX);

    // Check preview deposit
    let preview_deposit = vault.preview_deposit(deposit_assets);
    assert_eq!(preview_deposit, expected_shares);

    // Before deposit
    let holder_balance_before = asset.balance_of(HOLDER());
    let mut spy = spy_events();

    // Deposit
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    let shares = vault.deposit(deposit_assets, RECIPIENT());

    // After deposit
    let holder_balance_after = asset.balance_of(HOLDER());
    assert_eq!(holder_balance_after, holder_balance_before - deposit_assets);

    // Check recipient shares
    let recipient_balance = vault.balance_of(RECIPIENT());
    assert_eq!(recipient_balance, expected_shares);

    // Check events
    spy
        .assert_event_transfer(
            asset.contract_address, HOLDER(), vault.contract_address, deposit_assets
        );
    spy.assert_event_transfer(vault.contract_address, ZERO(), RECIPIENT(), shares);
    spy
        .assert_only_event_deposit(
            vault.contract_address, HOLDER(), RECIPIENT(), deposit_assets, expected_shares
        );
}

#[test]
fn test_inflation_attack_mint() {
    let (asset, vault) = setup_inflation_attack();
    let virtual_assets = 1;
    let offset = 1;
    let virtual_shares = math::power(10, offset);

    let effective_assets = vault.total_assets() + virtual_assets;
    let effective_shares = vault.total_supply() + virtual_shares;

    let mint_shares = parse_share_offset(1);
    let expected_assets = (mint_shares * effective_assets) / effective_shares;

    // Check max mint
    let max_mint = vault.max_mint(HOLDER());
    assert_eq!(max_mint, Bounded::MAX);

    // Check preview mint
    let preview_mint = vault.preview_mint(mint_shares);
    assert_eq!(preview_mint, expected_assets);

    // Capture initial balances
    let holder_balance_before = asset.balance_of(HOLDER());
    let vault_balance_before = asset.balance_of(vault.contract_address);

    // Mint
    let mut spy = spy_events();
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.mint(mint_shares, RECIPIENT());

    // Check balances
    assert_expected_assets(asset, HOLDER(), holder_balance_before - expected_assets);
    assert_expected_assets(asset, vault.contract_address, vault_balance_before + expected_assets);
    assert_expected_shares(vault, RECIPIENT(), parse_share_offset(1));

    // Check events
    spy
        .assert_event_transfer(
            asset.contract_address, HOLDER(), vault.contract_address, expected_assets
        );
    spy.assert_event_transfer(vault.contract_address, ZERO(), RECIPIENT(), mint_shares);
    spy
        .assert_only_event_deposit(
            vault.contract_address, HOLDER(), RECIPIENT(), expected_assets, mint_shares
        );
}

#[test]
fn test_inflation_attack_withdraw() {
    let (asset, vault) = setup_inflation_attack();

    // Check max withdraw
    let max_withdraw = vault.max_withdraw(HOLDER());
    assert_eq!(max_withdraw, 0);

    // Check preview withdraw
    let preview_withdraw = vault.preview_withdraw(0);
    assert_eq!(preview_withdraw, 0);

    // Capture initial balances
    let holder_balance_before = asset.balance_of(HOLDER());
    let vault_balance_before = asset.balance_of(vault.contract_address);

    // Withdraw
    let mut spy = spy_events();
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.withdraw(0, RECIPIENT(), HOLDER());

    // Check balances and events
    assert_expected_assets(asset, HOLDER(), holder_balance_before);
    assert_expected_assets(asset, vault.contract_address, vault_balance_before);

    spy.assert_event_transfer(vault.contract_address, HOLDER(), ZERO(), 0);
    spy.assert_event_transfer(asset.contract_address, vault.contract_address, RECIPIENT(), 0);
    spy.assert_only_event_withdraw(vault.contract_address, HOLDER(), RECIPIENT(), HOLDER(), 0, 0);
}

#[test]
fn test_inflation_attack_redeem() {
    let (asset, vault) = setup_inflation_attack();

    // Check max redeem
    let max_redeem = vault.max_redeem(HOLDER());
    assert_eq!(max_redeem, 0);

    // Check preview redeem
    let preview_redeem = vault.preview_redeem(0);
    assert_eq!(preview_redeem, 0);

    // Redeem
    let mut spy = spy_events();
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.redeem(0, RECIPIENT(), HOLDER());

    // Check events
    spy.assert_event_transfer(vault.contract_address, HOLDER(), ZERO(), 0);
    spy.assert_event_transfer(asset.contract_address, vault.contract_address, RECIPIENT(), 0);
    spy.assert_only_event_withdraw(vault.contract_address, HOLDER(), RECIPIENT(), HOLDER(), 0, 0);
}

//
// Full vault: Assets and shares
//

fn setup_full_vault() -> (IERC20ReentrantDispatcher, ERC4626ABIDispatcher) {
    let mut asset = deploy_asset();

    let shares = parse_share_offset(100);
    let recipient = HOLDER();

    // Add 1 token of underlying asset and 100 shares to the vault
    let mut vault = deploy_vault_offset_minted_shares(asset.contract_address, shares, recipient);
    asset.unsafe_mint(vault.contract_address, parse_token(1));

    // Approve SPENDER
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.approve(SPENDER(), Bounded::MAX);

    // Mint assets to HOLDER, approve vault
    asset.unsafe_mint(HOLDER(), Bounded::MAX / 2); // 50% of max
    cheat_caller_address(asset.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    asset.approve(vault.contract_address, Bounded::MAX);

    (asset, vault)
}

#[test]
fn test_full_vault_status() {
    let (_, vault) = setup_full_vault();

    let total_supply = vault.total_supply();
    assert_eq!(total_supply, parse_share_offset(100));

    let total_assets = vault.total_assets();
    assert_eq!(total_assets, parse_token(1));
}

#[test]
fn test_full_vault_deposit() {
    let (asset, vault) = setup_full_vault();

    let virtual_assets = 1;
    let offset = 1;
    let virtual_shares = math::power(10, offset);

    let effective_assets = vault.total_assets() + virtual_assets;
    let effective_shares = vault.total_supply() + virtual_shares;

    let deposit_assets = parse_token(1);
    let expected_shares = (deposit_assets * effective_shares) / effective_assets;

    // Check max deposit
    let max_deposit = vault.max_deposit(HOLDER());
    assert_eq!(max_deposit, Bounded::MAX);

    // Check preview deposit
    let preview_deposit = vault.preview_deposit(deposit_assets);
    assert_eq!(preview_deposit, expected_shares);

    // Before deposit
    let holder_balance_before = asset.balance_of(HOLDER());

    // Deposit
    let mut spy = spy_events();
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    let shares = vault.deposit(deposit_assets, RECIPIENT());

    // After deposit
    let holder_balance_after = asset.balance_of(HOLDER());
    assert_eq!(holder_balance_after, holder_balance_before - deposit_assets);

    // Check recipient shares
    let recipient_balance = vault.balance_of(RECIPIENT());
    assert_eq!(recipient_balance, expected_shares);

    // Check events
    spy
        .assert_event_transfer(
            asset.contract_address, HOLDER(), vault.contract_address, deposit_assets
        );
    spy.assert_event_transfer(vault.contract_address, ZERO(), RECIPIENT(), shares);
    spy
        .assert_only_event_deposit(
            vault.contract_address, HOLDER(), RECIPIENT(), deposit_assets, expected_shares
        );
}

#[test]
fn test_full_vault_mint() {
    let (asset, vault) = setup_full_vault();

    let virtual_assets = 1;
    let offset = 1;
    let virtual_shares = math::power(10, offset);

    let effective_assets = vault.total_assets() + virtual_assets;
    let effective_shares = vault.total_supply() + virtual_shares;

    let mint_shares = parse_share_offset(1);
    let expected_assets = (mint_shares * effective_assets) / effective_shares
        + 1; // add `1` for the rounding

    // Check max mint
    let max_mint = vault.max_mint(HOLDER());
    assert_eq!(max_mint, Bounded::MAX);

    // Check preview mint
    let preview_mint = vault.preview_mint(mint_shares);
    assert_eq!(preview_mint, expected_assets);

    // Capture initial balances
    let holder_balance_before = asset.balance_of(HOLDER());
    let vault_balance_before = asset.balance_of(vault.contract_address);

    // Mint
    let mut spy = spy_events();
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.mint(mint_shares, RECIPIENT());

    // Check balances
    assert_expected_assets(asset, HOLDER(), holder_balance_before - expected_assets);
    assert_expected_assets(asset, vault.contract_address, vault_balance_before + expected_assets);
    assert_expected_shares(vault, RECIPIENT(), parse_share_offset(1));

    // Check events
    spy
        .assert_event_transfer(
            asset.contract_address, HOLDER(), vault.contract_address, expected_assets
        );
    spy.assert_event_transfer(vault.contract_address, ZERO(), RECIPIENT(), mint_shares);
    spy
        .assert_only_event_deposit(
            vault.contract_address, HOLDER(), RECIPIENT(), expected_assets, mint_shares
        );
}

#[test]
fn test_full_vault_withdraw() {
    let (asset, vault) = setup_full_vault();

    let virtual_assets = 1;
    let offset = 1;
    let virtual_shares = math::power(10, offset);

    let effective_assets = vault.total_assets() + virtual_assets;
    let effective_shares = vault.total_supply() + virtual_shares;

    let withdraw_assets = parse_token(1);
    let expected_shares = (withdraw_assets * effective_shares) / effective_assets
        + 1; // add `1` for the rounding

    // Check max withdraw
    let max_withdraw = vault.max_withdraw(HOLDER());
    assert_eq!(max_withdraw, withdraw_assets);

    // Check preview withdraw
    let preview_withdraw = vault.preview_withdraw(withdraw_assets);
    assert_eq!(preview_withdraw, expected_shares);

    // Capture initial balances
    let holder_balance_before = asset.balance_of(HOLDER());
    let vault_balance_before = asset.balance_of(vault.contract_address);

    // Withdraw
    let mut spy = spy_events();
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.withdraw(withdraw_assets, RECIPIENT(), HOLDER());

    // Check balances and events
    assert_expected_assets(asset, HOLDER(), holder_balance_before);
    assert_expected_assets(asset, RECIPIENT(), withdraw_assets);
    assert_expected_assets(asset, vault.contract_address, vault_balance_before - withdraw_assets);

    spy.assert_event_transfer(vault.contract_address, HOLDER(), ZERO(), expected_shares);
    spy
        .assert_event_transfer(
            asset.contract_address, vault.contract_address, RECIPIENT(), withdraw_assets
        );
    spy
        .assert_only_event_withdraw(
            vault.contract_address,
            HOLDER(),
            RECIPIENT(),
            HOLDER(),
            withdraw_assets,
            expected_shares
        );
}

#[test]
fn test_full_vault_withdraw_with_approval() {
    let (asset, vault) = setup_full_vault();

    let virtual_assets = 1;
    let offset = 1;
    let virtual_shares = math::power(10, offset);

    let effective_assets = vault.total_assets() + virtual_assets;
    let effective_shares = vault.total_supply() + virtual_shares;

    let withdraw_assets = parse_token(1);
    let expected_shares = (withdraw_assets * effective_shares) / effective_assets
        + 1; // add `1` for the rounding

    // Withdraw
    let mut spy = spy_events();
    cheat_caller_address(vault.contract_address, SPENDER(), CheatSpan::TargetCalls(1));
    vault.withdraw(withdraw_assets, RECIPIENT(), HOLDER());

    // Check events
    spy.assert_event_transfer(vault.contract_address, HOLDER(), ZERO(), expected_shares);
    spy
        .assert_event_transfer(
            asset.contract_address, vault.contract_address, RECIPIENT(), withdraw_assets
        );
    spy
        .assert_only_event_withdraw(
            vault.contract_address,
            SPENDER(),
            RECIPIENT(),
            HOLDER(),
            withdraw_assets,
            expected_shares
        );
}

#[test]
#[should_panic(expected: 'ERC20: insufficient allowance')]
fn test_full_vault_withdraw_unauthorized() {
    let (_, vault) = setup_full_vault();
    let withdraw_assets = parse_token(1);

    cheat_caller_address(vault.contract_address, OTHER(), CheatSpan::TargetCalls(1));
    vault.withdraw(withdraw_assets, RECIPIENT(), HOLDER());
}

#[test]
fn test_full_vault_redeem() {
    let (asset, vault) = setup_full_vault();

    let virtual_assets = 1;
    let offset = 1;
    let virtual_shares = math::power(10, offset);

    let effective_assets = vault.total_assets() + virtual_assets;
    let effective_shares = vault.total_supply() + virtual_shares;

    let redeem_shares = parse_share_offset(100);
    let expected_assets = (redeem_shares * effective_assets) / effective_shares;

    // Check max redeem
    let max_redeem = vault.max_redeem(HOLDER());
    assert_eq!(max_redeem, redeem_shares);

    // Check preview redeem
    let preview_redeem = vault.preview_redeem(redeem_shares);
    assert_eq!(preview_redeem, expected_assets);

    // Capture initial balances
    let vault_balance_before = asset.balance_of(vault.contract_address);
    let holder_shares_before = vault.balance_of(HOLDER());

    // Redeem
    let mut spy = spy_events();
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.redeem(redeem_shares, RECIPIENT(), HOLDER());

    // Check balances and events
    assert_expected_assets(asset, RECIPIENT(), expected_assets);
    assert_expected_assets(asset, vault.contract_address, vault_balance_before - expected_assets);
    assert_expected_shares(vault, HOLDER(), holder_shares_before - redeem_shares);

    spy.assert_event_transfer(vault.contract_address, HOLDER(), ZERO(), redeem_shares);
    spy
        .assert_event_transfer(
            asset.contract_address, vault.contract_address, RECIPIENT(), expected_assets
        );
    spy
        .assert_only_event_withdraw(
            vault.contract_address, HOLDER(), RECIPIENT(), HOLDER(), expected_assets, redeem_shares
        );
}

#[test]
fn test_full_vault_redeem_with_approval() {
    let (asset, vault) = setup_full_vault();

    let virtual_assets = 1;
    let offset = 1;
    let virtual_shares = math::power(10, offset);

    let effective_assets = vault.total_assets() + virtual_assets;
    let effective_shares = vault.total_supply() + virtual_shares;

    let redeem_shares = parse_share_offset(100);
    let expected_assets = (redeem_shares * effective_assets) / effective_shares;

    // Check max redeem
    let max_redeem = vault.max_redeem(HOLDER());
    assert_eq!(max_redeem, redeem_shares);

    // Check preview redeem
    let preview_redeem = vault.preview_redeem(redeem_shares);
    assert_eq!(preview_redeem, expected_assets);

    // Capture initial balances
    let vault_balance_before = asset.balance_of(vault.contract_address);
    let holder_shares_before = vault.balance_of(HOLDER());

    // Redeem from SPENDER
    let mut spy = spy_events();
    cheat_caller_address(vault.contract_address, SPENDER(), CheatSpan::TargetCalls(1));
    vault.redeem(redeem_shares, RECIPIENT(), HOLDER());

    // Check balances and events
    assert_expected_assets(asset, RECIPIENT(), expected_assets);
    assert_expected_assets(asset, vault.contract_address, vault_balance_before - expected_assets);
    assert_expected_shares(vault, HOLDER(), holder_shares_before - redeem_shares);

    spy.assert_event_transfer(vault.contract_address, HOLDER(), ZERO(), redeem_shares);
    spy
        .assert_event_transfer(
            asset.contract_address, vault.contract_address, RECIPIENT(), expected_assets
        );
    spy
        .assert_only_event_withdraw(
            vault.contract_address, SPENDER(), RECIPIENT(), HOLDER(), expected_assets, redeem_shares
        );
}

#[test]
#[should_panic(expected: 'ERC20: insufficient allowance')]
fn test_full_vault_redeem_unauthorized() {
    let (_, vault) = setup_full_vault();
    let redeem_shares = parse_share_offset(100);

    // Unauthorized redeem
    cheat_caller_address(vault.contract_address, OTHER(), CheatSpan::TargetCalls(1));
    vault.redeem(redeem_shares, RECIPIENT(), HOLDER());
}

//
// Reentrancy
//

fn setup_reentrancy() -> (IERC20ReentrantDispatcher, ERC4626ABIDispatcher) {
    let mut asset = deploy_asset();
    let mut vault = deploy_vault_offset(asset.contract_address);

    let value: u256 = 1_000_000_000_000_000_000;
    asset.unsafe_mint(HOLDER(), value);
    asset.unsafe_mint(OTHER(), value);

    // Set infinite approvals from HOLDER, OTHER, and asset to vault
    let approvers: Span<ContractAddress> = array![HOLDER(), OTHER(), asset.contract_address].span();
    for addr in approvers {
        cheat_caller_address(asset.contract_address, *addr, CheatSpan::TargetCalls(1));
        asset.approve(vault.contract_address, Bounded::MAX);
    };

    (asset, vault)
}

#[test]
fn test_share_price_with_reentrancy_before_deposit() {
    let (asset, vault) = setup_reentrancy();

    let value = 1_000_000_000_000_000_000;
    let reenter_value = 1_000_000_000;

    asset.unsafe_mint(asset.contract_address, reenter_value);

    // Schedule reentrancy
    let mut calldata: Array<felt252> = array![];
    calldata.append_serde(reenter_value);
    calldata.append_serde(HOLDER());
    asset
        .schedule_reenter(
            Type::Before, vault.contract_address, selector!("deposit"), calldata.span()
        );

    let shares_for_deposit = vault.preview_deposit(value);
    let shares_for_reenter = vault.preview_deposit(reenter_value);

    // Deposit
    let mut spy = spy_events();
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.deposit(value, HOLDER());

    // Check price is kept
    let after_deposit = vault.preview_deposit(value);
    assert_eq!(shares_for_deposit, after_deposit);

    // Check events
    // Reentered events come first because they're called in mock ERC20 `before_update` hook
    spy
        .assert_event_transfer(
            asset.contract_address, asset.contract_address, vault.contract_address, reenter_value
        );
    spy.assert_event_transfer(vault.contract_address, ZERO(), HOLDER(), shares_for_reenter);
    spy
        .assert_event_deposit(
            vault.contract_address,
            asset.contract_address,
            HOLDER(),
            reenter_value,
            shares_for_reenter
        );

    spy.assert_event_transfer(asset.contract_address, HOLDER(), vault.contract_address, value);
    spy.assert_event_transfer(vault.contract_address, ZERO(), HOLDER(), shares_for_deposit);
    spy
        .assert_only_event_deposit(
            vault.contract_address, HOLDER(), HOLDER(), value, shares_for_deposit
        );
}

#[test]
fn test_share_price_with_reentrancy_after_withdraw() {
    let (asset, vault) = setup_reentrancy();

    let value = 1_000_000_000_000_000_000;
    let reenter_value = 1_000_000_000;

    // Deposit from HOLDER and OTHER
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.deposit(value, HOLDER());

    cheat_caller_address(vault.contract_address, OTHER(), CheatSpan::TargetCalls(1));
    vault.deposit(reenter_value, asset.contract_address);

    // Schedule reentrancy
    let mut calldata: Array<felt252> = array![];
    calldata.append_serde(reenter_value);
    calldata.append_serde(HOLDER());
    calldata.append_serde(asset.contract_address);
    asset
        .schedule_reenter(
            Type::After, vault.contract_address, selector!("withdraw"), calldata.span()
        );

    let shares_for_withdraw = vault.preview_withdraw(value);
    let shares_for_reenter = vault.preview_withdraw(reenter_value);

    // Withdraw
    let mut spy = spy_events();
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.withdraw(value, HOLDER(), HOLDER());

    // Check price is kept
    let after_withdraw = vault.preview_withdraw(value);
    assert_eq!(shares_for_withdraw, after_withdraw);

    // Main withdraw event
    spy
        .assert_event_withdraw(
            vault.contract_address, HOLDER(), HOLDER(), HOLDER(), value, shares_for_withdraw
        );
    // Reentrant withdraw event → uses same price
    spy
        .assert_event_withdraw(
            vault.contract_address,
            asset.contract_address,
            HOLDER(),
            asset.contract_address,
            reenter_value,
            shares_for_reenter
        );
}

#[test]
fn test_price_change_during_reentrancy_doesnt_affect_deposit() {
    let (asset, vault) = setup_reentrancy();

    let value: u256 = 1_000_000_000_000_000_000;
    let reenter_value: u256 = 1_000_000_000;

    // Schedules a reentrancy from the token contract that messes up the share price
    let mut calldata: Array<felt252> = array![];
    calldata.append_serde(vault.contract_address);
    calldata.append_serde(reenter_value);
    asset
        .schedule_reenter(
            Type::Before, asset.contract_address, selector!("unsafe_mint"), calldata.span()
        );

    let shares_before = vault.preview_deposit(value);

    // Deposit
    let mut spy = spy_events();
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.deposit(value, HOLDER());

    // Check main event to ensure price is as previewed
    spy.assert_event_deposit(vault.contract_address, HOLDER(), HOLDER(), value, shares_before);

    // Check that price is modified after reentrant tx
    let shares_after = vault.preview_deposit(value);
    assert(shares_after < shares_before, 'Mint should change share price');
}

#[test]
fn test_price_change_during_reentrancy_doesnt_affect_withdraw() {
    let (asset, vault) = setup_reentrancy();

    let value: u256 = 1_000_000_000_000_000_000;
    let reenter_value: u256 = 1_000_000_000;

    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.deposit(value, HOLDER());
    cheat_caller_address(vault.contract_address, OTHER(), CheatSpan::TargetCalls(1));
    vault.deposit(value, OTHER());

    // Schedules a reentrancy from the token contract that messes up the share price
    let mut calldata: Array<felt252> = array![];
    calldata.append_serde(vault.contract_address);
    calldata.append_serde(reenter_value);
    asset
        .schedule_reenter(
            Type::After, asset.contract_address, selector!("unsafe_burn"), calldata.span()
        );

    let shares_before = vault.preview_withdraw(value);

    // Withdraw, triggering ERC20 `after_update` hook
    let mut spy = spy_events();
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.withdraw(value, HOLDER(), HOLDER());

    // Check main event to ensure price is as previewed
    spy
        .assert_event_withdraw(
            vault.contract_address, HOLDER(), HOLDER(), HOLDER(), value, shares_before
        );

    // Check that price is modified after reentrant tx
    let shares_after = vault.preview_withdraw(value);
    assert(shares_after > shares_before, 'Burn should change share price');
}

//
// Limits
//

fn setup_limits() -> (IERC20ReentrantDispatcher, ERC4626ABIDispatcher) {
    let mut asset = deploy_asset();
    let mut vault = deploy_vault_limits(asset.contract_address);

    (asset, vault)
}

#[test]
#[should_panic(expected: 'ERC4626: exceeds max deposit')]
fn test_max_limit_deposit() {
    let (_, vault) = setup_limits();

    let max_deposit = vault.max_deposit(HOLDER());
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.deposit(max_deposit + 1, HOLDER());
}

#[test]
#[should_panic(expected: 'ERC4626: exceeds max mint')]
fn test_max_limit_mint() {
    let (_, vault) = setup_limits();

    let max_mint = vault.max_mint(HOLDER());
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.mint(max_mint + 1, HOLDER());
}

#[test]
#[should_panic(expected: 'ERC4626: exceeds max withdraw')]
fn test_max_limit_withdraw() {
    let (_, vault) = setup_limits();

    let max_withdraw = vault.max_redeem(HOLDER());
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.withdraw(max_withdraw + 1, HOLDER(), HOLDER());
}

#[test]
#[should_panic(expected: 'ERC4626: exceeds max redeem')]
fn test_max_limit_redeem() {
    let (_, vault) = setup_limits();

    let max_redeem = vault.max_redeem(HOLDER());
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.redeem(max_redeem + 1, HOLDER(), HOLDER());
}

//
// Fees
//

fn setup_input_fees() -> (IERC20ReentrantDispatcher, ERC4626ABIDispatcher) {
    let mut asset = deploy_asset();
    let mut vault = deploy_vault_fees(asset.contract_address);

    let half_max: u256 = Bounded::MAX / 2;
    asset.unsafe_mint(HOLDER(), half_max);

    cheat_caller_address(asset.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    asset.approve(vault.contract_address, half_max);

    (asset, vault)
}

fn setup_output_fees() -> (IERC20ReentrantDispatcher, ERC4626ABIDispatcher) {
    let mut asset = deploy_asset();
    let half_max: u256 = Bounded::MAX / 2;

    // Mint shares to HOLDER
    let mut vault = deploy_vault_exit_fees_with_shares(asset.contract_address, half_max, HOLDER());

    // Mint assets to vault
    asset.unsafe_mint(vault.contract_address, half_max);

    (asset, vault)
}

#[test]
fn test_input_fees_deposit() {
    let (asset, vault) = setup_input_fees();

    let FEE_BASIS_POINTS: u256 = 500; // 5%
    let VALUE_WITHOUT_FEES: u256 = 10_000;
    let FEES = (VALUE_WITHOUT_FEES * FEE_BASIS_POINTS) / 10_000;
    let VALUE_WITH_FEES = VALUE_WITHOUT_FEES + FEES;

    let actual_value = vault.preview_deposit(VALUE_WITH_FEES);
    assert_eq!(actual_value, VALUE_WITHOUT_FEES);

    let holder_asset_bal = asset.balance_of(HOLDER());
    let vault_asset_bal = asset.balance_of(vault.contract_address);

    let mut spy = spy_events();
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.deposit(VALUE_WITH_FEES, RECIPIENT());

    // Check asset balances
    assert_expected_assets(asset, HOLDER(), holder_asset_bal - VALUE_WITH_FEES);
    assert_expected_assets(asset, vault.contract_address, vault_asset_bal + VALUE_WITHOUT_FEES);
    assert_expected_assets(asset, TREASURY(), FEES);

    // Check shares
    assert_expected_shares(vault, RECIPIENT(), VALUE_WITHOUT_FEES);

    // Check events
    spy
        .assert_event_transfer(
            asset.contract_address, HOLDER(), vault.contract_address, VALUE_WITH_FEES
        );
    spy.assert_event_transfer(vault.contract_address, ZERO(), RECIPIENT(), VALUE_WITHOUT_FEES);
    spy
        .assert_event_deposit(
            vault.contract_address, HOLDER(), RECIPIENT(), VALUE_WITH_FEES, VALUE_WITHOUT_FEES
        );
    spy.assert_event_transfer(asset.contract_address, vault.contract_address, TREASURY(), FEES);
}

#[test]
fn test_input_fees_mint() {
    let (asset, vault) = setup_input_fees();

    let FEE_BASIS_POINTS: u256 = 500; // 5%
    let VALUE_WITHOUT_FEES: u256 = 10_000;
    let FEES = (VALUE_WITHOUT_FEES * FEE_BASIS_POINTS) / 10_000;
    let VALUE_WITH_FEES = VALUE_WITHOUT_FEES + FEES;

    let actual_value = vault.preview_mint(VALUE_WITHOUT_FEES);
    assert_eq!(actual_value, VALUE_WITH_FEES);

    let holder_asset_bal = asset.balance_of(HOLDER());
    let vault_asset_bal = asset.balance_of(vault.contract_address);

    let mut spy = spy_events();
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.mint(VALUE_WITHOUT_FEES, RECIPIENT());

    // Check asset balances
    assert_expected_assets(asset, HOLDER(), holder_asset_bal - VALUE_WITH_FEES);
    assert_expected_assets(asset, vault.contract_address, vault_asset_bal + VALUE_WITHOUT_FEES);
    assert_expected_assets(asset, TREASURY(), FEES);

    // Check shares
    assert_expected_shares(vault, RECIPIENT(), VALUE_WITHOUT_FEES);

    // Check events
    spy
        .assert_event_transfer(
            asset.contract_address, HOLDER(), vault.contract_address, VALUE_WITH_FEES
        );
    spy.assert_event_transfer(vault.contract_address, ZERO(), RECIPIENT(), VALUE_WITHOUT_FEES);
    spy
        .assert_event_deposit(
            vault.contract_address, HOLDER(), RECIPIENT(), VALUE_WITH_FEES, VALUE_WITHOUT_FEES
        );
    spy.assert_event_transfer(asset.contract_address, vault.contract_address, TREASURY(), FEES);
}

#[test]
fn test_output_fees_redeem() {
    let (asset, vault) = setup_output_fees();

    let FEE_BASIS_POINTS: u256 = 500; // 5%
    let VALUE_WITHOUT_FEES: u256 = 10_000;
    let FEES = (VALUE_WITHOUT_FEES * FEE_BASIS_POINTS) / 10_000;
    let VALUE_WITH_FEES = VALUE_WITHOUT_FEES + FEES;

    let preview_redeem = vault.preview_redeem(VALUE_WITH_FEES);
    assert_eq!(preview_redeem, VALUE_WITHOUT_FEES);

    let vault_asset_bal = asset.balance_of(vault.contract_address);
    let recipient_asset_bal = asset.balance_of(RECIPIENT());
    let treasury_asset_bal = asset.balance_of(TREASURY());
    let holder_shares = vault.balance_of(HOLDER());

    let mut spy = spy_events();
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.redeem(VALUE_WITH_FEES, RECIPIENT(), HOLDER());

    // Check asset balances
    assert_expected_assets(asset, vault.contract_address, vault_asset_bal - VALUE_WITH_FEES);
    assert_expected_assets(asset, RECIPIENT(), recipient_asset_bal + VALUE_WITHOUT_FEES);
    assert_expected_assets(asset, TREASURY(), treasury_asset_bal + FEES);

    // Check shares
    assert_expected_shares(vault, HOLDER(), holder_shares - VALUE_WITH_FEES);

    // Check events
    spy.assert_event_transfer(asset.contract_address, vault.contract_address, TREASURY(), FEES);
    spy.assert_event_transfer(vault.contract_address, HOLDER(), ZERO(), VALUE_WITH_FEES);
    spy
        .assert_event_transfer(
            asset.contract_address, vault.contract_address, RECIPIENT(), VALUE_WITHOUT_FEES
        );
    spy
        .assert_only_event_withdraw(
            vault.contract_address,
            HOLDER(),
            RECIPIENT(),
            HOLDER(),
            VALUE_WITHOUT_FEES,
            VALUE_WITH_FEES
        );
}

#[test]
fn test_output_fees_withdraw() {
    let (asset, vault) = setup_output_fees();

    let FEE_BASIS_POINTS: u256 = 500; // 5%
    let VALUE_WITHOUT_FEES: u256 = 10_000;
    let FEES = (VALUE_WITHOUT_FEES * FEE_BASIS_POINTS) / 10_000;
    let VALUE_WITH_FEES = VALUE_WITHOUT_FEES + FEES;

    let preview_withdraw = vault.preview_withdraw(VALUE_WITHOUT_FEES);
    assert_eq!(preview_withdraw, VALUE_WITH_FEES);

    let vault_asset_bal = asset.balance_of(vault.contract_address);
    let recipient_asset_bal = asset.balance_of(RECIPIENT());
    let treasury_asset_bal = asset.balance_of(TREASURY());
    let holder_shares = vault.balance_of(HOLDER());

    let mut spy = spy_events();
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.withdraw(VALUE_WITHOUT_FEES, RECIPIENT(), HOLDER());

    // Check asset balances
    assert_expected_assets(asset, vault.contract_address, vault_asset_bal - VALUE_WITH_FEES);
    assert_expected_assets(asset, RECIPIENT(), recipient_asset_bal + VALUE_WITHOUT_FEES);
    assert_expected_assets(asset, TREASURY(), treasury_asset_bal + FEES);

    // Check shares
    assert_expected_shares(vault, HOLDER(), holder_shares - VALUE_WITH_FEES);

    // Check events
    spy.assert_event_transfer(asset.contract_address, vault.contract_address, TREASURY(), FEES);
    spy.assert_event_transfer(vault.contract_address, HOLDER(), ZERO(), VALUE_WITH_FEES);
    spy
        .assert_event_transfer(
            asset.contract_address, vault.contract_address, RECIPIENT(), VALUE_WITHOUT_FEES
        );
    spy
        .assert_only_event_withdraw(
            vault.contract_address,
            HOLDER(),
            RECIPIENT(),
            HOLDER(),
            VALUE_WITHOUT_FEES,
            VALUE_WITH_FEES
        );
}

//
// Assertions/Helpers
//

fn assert_expected_shares(
    vault: ERC4626ABIDispatcher, account: ContractAddress, expected_shares: u256
) {
    let actual_shares = vault.balance_of(account);
    assert_eq!(actual_shares, expected_shares);
}

fn assert_expected_assets(
    asset: IERC20ReentrantDispatcher, account: ContractAddress, expected_assets: u256
) {
    let actual_assets = asset.balance_of(account);
    assert_eq!(actual_assets, expected_assets);
}

#[generate_trait]
pub impl ERC4626SpyHelpersImpl of ERC4626SpyHelpers {
    fn assert_event_deposit(
        ref self: EventSpy,
        contract: ContractAddress,
        sender: ContractAddress,
        owner: ContractAddress,
        assets: u256,
        shares: u256
    ) {
        let expected = ERC4626Component::Event::Deposit(Deposit { sender, owner, assets, shares });
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_deposit(
        ref self: EventSpy,
        contract: ContractAddress,
        sender: ContractAddress,
        owner: ContractAddress,
        assets: u256,
        shares: u256
    ) {
        self.assert_event_deposit(contract, sender, owner, assets, shares);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_withdraw(
        ref self: EventSpy,
        contract: ContractAddress,
        sender: ContractAddress,
        receiver: ContractAddress,
        owner: ContractAddress,
        assets: u256,
        shares: u256
    ) {
        let expected = ERC4626Component::Event::Withdraw(
            Withdraw { sender, receiver, owner, assets, shares }
        );
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_withdraw(
        ref self: EventSpy,
        contract: ContractAddress,
        sender: ContractAddress,
        receiver: ContractAddress,
        owner: ContractAddress,
        assets: u256,
        shares: u256
    ) {
        self.assert_event_withdraw(contract, sender, receiver, owner, assets, shares);
        self.assert_no_events_left_from(contract);
    }
}
