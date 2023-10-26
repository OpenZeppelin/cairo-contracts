// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0-beta.0 (token/erc20/dual20.cairo)

use openzeppelin::utils::UnwrapAndCast;
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::utils::try_selector_with_fallback;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;
use starknet::call_contract_syscall;

#[derive(Copy, Drop)]
struct DualCaseERC20 {
    contract_address: ContractAddress
}

trait DualCaseERC20Trait {
    fn name(self: @DualCaseERC20) -> felt252;
    fn symbol(self: @DualCaseERC20) -> felt252;
    fn decimals(self: @DualCaseERC20) -> u8;
    fn total_supply(self: @DualCaseERC20) -> u256;
    fn balance_of(self: @DualCaseERC20, account: ContractAddress) -> u256;
    fn allowance(self: @DualCaseERC20, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(self: @DualCaseERC20, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        self: @DualCaseERC20, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(self: @DualCaseERC20, spender: ContractAddress, amount: u256) -> bool;
}

impl DualCaseERC20Impl of DualCaseERC20Trait {
    fn name(self: @DualCaseERC20) -> felt252 {
        let args = array![];
        call_contract_syscall(*self.contract_address, selectors::name, args.span())
            .unwrap_and_cast()
    }

    fn symbol(self: @DualCaseERC20) -> felt252 {
        let args = array![];
        call_contract_syscall(*self.contract_address, selectors::symbol, args.span())
            .unwrap_and_cast()
    }

    fn decimals(self: @DualCaseERC20) -> u8 {
        let args = array![];
        call_contract_syscall(*self.contract_address, selectors::decimals, args.span())
            .unwrap_and_cast()
    }

    fn total_supply(self: @DualCaseERC20) -> u256 {
        let mut args = array![];
        try_selector_with_fallback(
            *self.contract_address, selectors::total_supply, selectors::totalSupply, args.span()
        )
            .unwrap_and_cast()
    }

    fn balance_of(self: @DualCaseERC20, account: ContractAddress) -> u256 {
        let mut args = array![];
        args.append_serde(account);

        try_selector_with_fallback(
            *self.contract_address, selectors::balance_of, selectors::balanceOf, args.span()
        )
            .unwrap_and_cast()
    }

    fn allowance(self: @DualCaseERC20, owner: ContractAddress, spender: ContractAddress) -> u256 {
        let mut args = array![];
        args.append_serde(owner);
        args.append_serde(spender);

        call_contract_syscall(*self.contract_address, selectors::allowance, args.span())
            .unwrap_and_cast()
    }

    fn transfer(self: @DualCaseERC20, recipient: ContractAddress, amount: u256) -> bool {
        let mut args = array![];
        args.append_serde(recipient);
        args.append_serde(amount);

        call_contract_syscall(*self.contract_address, selectors::transfer, args.span())
            .unwrap_and_cast()
    }

    fn transfer_from(
        self: @DualCaseERC20, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool {
        let mut args = array![];
        args.append_serde(sender);
        args.append_serde(recipient);
        args.append_serde(amount);

        try_selector_with_fallback(
            *self.contract_address, selectors::transfer_from, selectors::transferFrom, args.span()
        )
            .unwrap_and_cast()
    }

    fn approve(self: @DualCaseERC20, spender: ContractAddress, amount: u256) -> bool {
        let mut args = array![];
        args.append_serde(spender);
        args.append_serde(amount);

        call_contract_syscall(*self.contract_address, selectors::approve, args.span())
            .unwrap_and_cast()
    }
}
