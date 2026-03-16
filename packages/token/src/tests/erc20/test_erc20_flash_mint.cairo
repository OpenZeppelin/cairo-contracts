use core::num::traits::Bounded;
use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_interfaces::erc3156::{
    IERC3156FlashLenderDispatcher, IERC3156FlashLenderDispatcherTrait,
};
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{
    EMPTY_DATA, NAME, OTHER, OWNER, RECIPIENT, SYMBOL, VALUE, ZERO,
};
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
use starknet::ContractAddress;

const INITIAL_SUPPLY: u256 = VALUE * 10;
const FLASH_FEE: u256 = 10;
const FLASH_LOAN_CAP: u256 = VALUE * 2;
const ON_FLASH_LOAN_RETURN: felt252 = selector!("ERC3156FlashBorrower.onFlashLoan");
const INVALID_MAGIC_VALUE: felt252 = 'INVALID_MAGIC';

fn deploy_flash_mint(initial_supply: u256, recipient: ContractAddress) -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(initial_supply);
    calldata.append_serde(recipient);
    utils::declare_and_deploy("ERC20FlashMintMock", calldata)
}

fn deploy_configured_flash_mint(
    initial_supply: u256,
    recipient: ContractAddress,
    flash_fee: u256,
    fee_receiver: ContractAddress,
    flash_loan_cap: u256,
) -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(initial_supply);
    calldata.append_serde(recipient);
    calldata.append_serde(flash_fee);
    calldata.append_serde(fee_receiver);
    calldata.append_serde(flash_loan_cap);
    utils::declare_and_deploy("ERC20FlashMintConfiguredMock", calldata)
}

fn deploy_borrower(return_value: felt252) -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(return_value);
    utils::declare_and_deploy("ERC3156FlashBorrowerMock", calldata)
}

fn erc20(token: ContractAddress) -> IERC20Dispatcher {
    IERC20Dispatcher { contract_address: token }
}

fn lender(token: ContractAddress) -> IERC3156FlashLenderDispatcher {
    IERC3156FlashLenderDispatcher { contract_address: token }
}

#[test]
fn max_flash_loan_returns_remaining_supply_for_supported_token() {
    let token = deploy_flash_mint(INITIAL_SUPPLY, OWNER);

    assert_eq!(lender(token).max_flash_loan(token), Bounded::MAX - INITIAL_SUPPLY);
}

#[test]
fn max_flash_loan_returns_zero_for_unsupported_token() {
    let token = deploy_flash_mint(INITIAL_SUPPLY, OWNER);

    assert_eq!(lender(token).max_flash_loan(OTHER), 0);
}

#[test]
fn max_flash_loan_uses_configured_cap() {
    let token = deploy_configured_flash_mint(INITIAL_SUPPLY, OWNER, 0, ZERO, FLASH_LOAN_CAP);

    assert_eq!(lender(token).max_flash_loan(token), FLASH_LOAN_CAP);
}

#[test]
fn flash_fee_returns_configured_fee_for_supported_token() {
    let token = deploy_configured_flash_mint(INITIAL_SUPPLY, OWNER, FLASH_FEE, ZERO, Bounded::MAX);

    assert_eq!(lender(token).flash_fee(token, VALUE), FLASH_FEE);
}

#[test]
#[should_panic(expected: 'FlashMint: unsupported token')]
fn flash_fee_reverts_for_unsupported_token() {
    let token = deploy_flash_mint(INITIAL_SUPPLY, OWNER);

    lender(token).flash_fee(OTHER, VALUE);
}

#[test]
fn flash_loan_executes_and_burns_tokens_with_zero_fee() {
    let token = deploy_flash_mint(INITIAL_SUPPLY, OWNER);
    let borrower = deploy_borrower(ON_FLASH_LOAN_RETURN);
    let token_dispatcher = erc20(token);

    assert!(lender(token).flash_loan(borrower, token, VALUE, EMPTY_DATA()));
    assert_eq!(token_dispatcher.total_supply(), INITIAL_SUPPLY);
    assert_eq!(token_dispatcher.balance_of(borrower), 0);
    assert_eq!(token_dispatcher.allowance(borrower, token), 0);
}

#[test]
#[should_panic(expected: 'FlashMint: exceeded max loan')]
fn flash_loan_reverts_when_amount_exceeds_configured_cap() {
    let token = deploy_configured_flash_mint(INITIAL_SUPPLY, OWNER, 0, ZERO, FLASH_LOAN_CAP);
    let borrower = deploy_borrower(ON_FLASH_LOAN_RETURN);

    lender(token).flash_loan(borrower, token, FLASH_LOAN_CAP + 1, EMPTY_DATA());
}

#[test]
#[should_panic(expected: 'FlashMint: invalid receiver')]
fn flash_loan_reverts_on_invalid_receiver_magic_value() {
    let token = deploy_flash_mint(INITIAL_SUPPLY, OWNER);
    let borrower = deploy_borrower(INVALID_MAGIC_VALUE);

    lender(token).flash_loan(borrower, token, VALUE, EMPTY_DATA());
}

#[test]
fn flash_loan_transfers_fee_to_fee_receiver() {
    let token = deploy_configured_flash_mint(
        INITIAL_SUPPLY, OWNER, FLASH_FEE, RECIPIENT, Bounded::MAX,
    );
    let borrower = deploy_borrower(ON_FLASH_LOAN_RETURN);
    let token_dispatcher = erc20(token);

    start_cheat_caller_address(token, OWNER);
    assert!(token_dispatcher.transfer(borrower, FLASH_FEE));
    stop_cheat_caller_address(token);

    assert!(lender(token).flash_loan(borrower, token, VALUE, EMPTY_DATA()));
    assert_eq!(token_dispatcher.total_supply(), INITIAL_SUPPLY);
    assert_eq!(token_dispatcher.balance_of(borrower), 0);
    assert_eq!(token_dispatcher.balance_of(RECIPIENT), FLASH_FEE);
    assert_eq!(token_dispatcher.allowance(borrower, token), 0);
}
