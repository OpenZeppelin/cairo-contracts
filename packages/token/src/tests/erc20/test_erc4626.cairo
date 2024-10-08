use core::num::traits::Bounded;
//use crate::erc20::ERC20Component;
use crate::erc20::ERC20Component::InternalImpl as ERC20InternalImpl;
use crate::erc20::extensions::erc4626::DefaultConfig;
use crate::erc20::extensions::erc4626::ERC4626Component::{
    ERC4626Impl, ERC4626MetadataImpl, InternalImpl
};
use crate::erc20::extensions::erc4626::ERC4626Component::{Deposit, Withdraw};
use crate::erc20::extensions::erc4626::ERC4626Component;
use crate::erc20::extensions::erc4626::interface::{ERC4626ABIDispatcher, ERC4626ABIDispatcherTrait};
use crate::tests::mocks::erc20_reentrant::Type;
use crate::tests::mocks::erc20_reentrant::{
    IERC20ReentrantDispatcher, IERC20ReentrantDispatcherTrait
};
use openzeppelin_test_common::erc20::ERC20SpyHelpers;
//use crate::tests::mocks::erc20_reentrant::ERC20ReentrantMock;
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{NAME, SYMBOL, OTHER, RECIPIENT, ZERO};
//use crate::tests::mocks::erc4626_mocks::ERC4626Mock;
use openzeppelin_testing::events::EventSpyExt;
use openzeppelin_utils::math;
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{
    start_cheat_caller_address, cheat_caller_address, CheatSpan, spy_events, EventSpy
};
use starknet::{ContractAddress, contract_address_const};

fn ASSET_ADDRESS() -> ContractAddress {
    contract_address_const::<'ASSET_ADDRESS'>()
}

fn HOLDER() -> ContractAddress {
    contract_address_const::<'HOLDER'>()
}

fn VAULT_NAME() -> ByteArray {
    "VAULT"
}

fn VAULT_SYMBOL() -> ByteArray {
    "V"
}

const DEFAULT_DECIMALS: u8 = 18;
const OFFSET_DECIMALS: u8 = 1;

//
// Helpers
//

fn parse_token(token: u256) -> u256 {
    token * math::power(10, DEFAULT_DECIMALS.into())
}

fn parse_share(share: u256) -> u256 {
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

fn deploy_vault(
    asset_address: ContractAddress, initial_supply: u256, recipient: ContractAddress
) -> ERC4626ABIDispatcher {
    let mut vault_calldata: Array<felt252> = array![];
    vault_calldata.append_serde(VAULT_NAME());
    vault_calldata.append_serde(VAULT_SYMBOL());
    vault_calldata.append_serde(asset_address);
    vault_calldata.append_serde(initial_supply);
    vault_calldata.append_serde(recipient);

    let contract_address = utils::declare_and_deploy("ERC4626Mock", vault_calldata);
    ERC4626ABIDispatcher { contract_address }
}

fn setup_empty() -> (IERC20ReentrantDispatcher, ERC4626ABIDispatcher) {
    let mut asset = deploy_asset();

    let no_amount = 0;
    let recipient = HOLDER();
    let mut vault = deploy_vault(asset.contract_address, no_amount, recipient);
    (asset, vault)
}

// Further testing required for decimals once design is finalized
#[test]
fn test_offset_decimals() {
    let (_, vault) = setup_empty();

    let decimals = vault.decimals();
    assert_eq!(decimals, 19);
}

//
// Reentrancy
//

#[test]
#[ignore]
fn test_share_price_with_reentrancy_before() {
    let (asset, vault) = setup_empty();

    let amount = 1_000_000_000_000_000_000;
    let reenter_amt = 1_000_000_000;

    asset.unsafe_mint(HOLDER(), amount);
    asset.unsafe_mint(OTHER(), amount);

    let approvers: Span<ContractAddress> = array![HOLDER(), OTHER(), asset.contract_address].span();

    for approver in approvers {
        cheat_caller_address(asset.contract_address, *approver, CheatSpan::TargetCalls(1));
        asset.approve(vault.contract_address, Bounded::MAX);
    };
    //stop_cheat_caller_address(asset.contract_address);

    // Mint token for deposit
    asset.unsafe_mint(asset.contract_address, reenter_amt);

    // Schedule reentrancy
    let mut calldata: Array<felt252> = array![];
    calldata.append_serde(reenter_amt);
    calldata.append_serde(HOLDER());

    asset
        .schedule_reenter(
            Type::Before, vault.contract_address, selector!("deposit"), calldata.span()
        );

    // Initial share price
    start_cheat_caller_address(vault.contract_address, HOLDER());

    let shares_for_deposit = vault.preview_deposit(amount);
    let _shares_for_reenter = vault.preview_deposit(reenter_amt);

    // Do deposit normally, triggering the hook
    vault.deposit(amount, HOLDER());

    // Assert prices are kept
    let shares_after = vault.preview_deposit(amount);
    assert_eq!(shares_for_deposit, shares_after, "ahhh");
}

#[test]
fn test_metadata() {
    let (asset, vault) = setup_empty();
    let name = vault.name();
    let symbol = vault.symbol();
    let decimals = vault.decimals();
    let asset_address = vault.asset();

    assert_eq!(name, VAULT_NAME());
    assert_eq!(symbol, VAULT_SYMBOL());
    assert_eq!(decimals, DEFAULT_DECIMALS + OFFSET_DECIMALS);
    assert_eq!(asset_address, asset.contract_address);
}

//
// Empty vault: no assets, no shares
//

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

    // Setup
    asset.unsafe_mint(HOLDER(), Bounded::MAX / 2);
    cheat_caller_address(asset.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    asset.approve(vault.contract_address, Bounded::MAX);

    // Check max deposit
    let max_deposit = vault.max_deposit(HOLDER());
    assert_eq!(max_deposit, Bounded::MAX);

    // Check preview == expected shares
    let preview_deposit = vault.preview_deposit(amount);
    let exp_shares = parse_share(1);
    assert_eq!(preview_deposit, exp_shares);

    let holder_balance_before = asset.balance_of(HOLDER());
    let mut spy = spy_events();

    // Deposit
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    let shares = vault.deposit(amount, RECIPIENT());

    // Check events
    spy.assert_event_transfer(asset.contract_address, HOLDER(), vault.contract_address, amount);
    spy.assert_event_transfer(vault.contract_address, ZERO(), RECIPIENT(), shares);
    spy.assert_only_event_deposit(vault.contract_address, HOLDER(), RECIPIENT(), amount, shares);

    let holder_balance_after = asset.balance_of(HOLDER());
    assert_eq!(holder_balance_after, holder_balance_before - amount);
}

#[test]
fn test_mint() {
    let (asset, vault) = setup_empty();

    // Setup
    asset.unsafe_mint(HOLDER(), Bounded::MAX / 2);
    cheat_caller_address(asset.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    asset.approve(vault.contract_address, Bounded::MAX);

    // Check max mint
    let max_mint = vault.max_mint(HOLDER());
    assert_eq!(max_mint, Bounded::MAX);

    // Check preview mint
    let preview_mint = vault.preview_mint(parse_share(1));
    let exp_assets = parse_token(1);
    assert_eq!(preview_mint, exp_assets);

    let mut spy = spy_events();

    // Mint
    cheat_caller_address(vault.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    vault.mint(parse_share(1), RECIPIENT());

    // Check events
    spy
        .assert_event_transfer(
            asset.contract_address, HOLDER(), vault.contract_address, parse_token(1)
        );
    spy.assert_event_transfer(vault.contract_address, ZERO(), RECIPIENT(), parse_share(1));
    spy
        .assert_only_event_deposit(
            vault.contract_address, HOLDER(), RECIPIENT(), parse_token(1), parse_share(1)
        );
}

#[test]
fn test_withdraw() {
    let (asset, vault) = setup_empty();

    // Setup
    asset.unsafe_mint(HOLDER(), Bounded::MAX / 2);
    cheat_caller_address(asset.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    asset.approve(vault.contract_address, Bounded::MAX);

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

    // Setup
    asset.unsafe_mint(HOLDER(), Bounded::MAX / 2);
    cheat_caller_address(asset.contract_address, HOLDER(), CheatSpan::TargetCalls(1));
    asset.approve(vault.contract_address, Bounded::MAX);

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
// Helpers
//

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
