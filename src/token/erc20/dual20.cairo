// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (token/erc20/dual20.cairo)

use array::ArrayTrait;
use openzeppelin::utils::UnwrapAndCast;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::utils::try_selector_with_fallback;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;
use starknet::call_contract_syscall;

#[derive(Copy, Drop)]
struct DualERC20 {
    contract_address: ContractAddress
}

trait DualERC20Trait {
    fn name(self: @DualERC20) -> felt252;
    fn symbol(self: @DualERC20) -> felt252;
    fn decimals(self: @DualERC20) -> u8;
    fn total_supply(self: @DualERC20) -> u256;
    fn balance_of(self: @DualERC20, account: ContractAddress) -> u256;
    fn allowance(self: @DualERC20, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(self: @DualERC20, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        self: @DualERC20, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(self: @DualERC20, spender: ContractAddress, amount: u256) -> bool;
}

impl DualERC20Impl of DualERC20Trait {
    fn name(self: @DualERC20) -> felt252 {
        let args = array![];
        call_contract_syscall(*self.contract_address, selector!("name"), args.span())
            .unwrap_and_cast()
    }

    fn symbol(self: @DualERC20) -> felt252 {
        let args = array![];
        call_contract_syscall(*self.contract_address, selector!("symbol"), args.span())
            .unwrap_and_cast()
    }

    fn decimals(self: @DualERC20) -> u8 {
        let args = array![];
        call_contract_syscall(*self.contract_address, selector!("decimals"), args.span())
            .unwrap_and_cast()
    }

    fn total_supply(self: @DualERC20) -> u256 {
        let mut args = array![];
        try_selector_with_fallback(
            *self.contract_address, selector!("total_supply"), selector!("totalSupply"), args.span()
        )
            .unwrap_and_cast()
    }

    fn balance_of(self: @DualERC20, account: ContractAddress) -> u256 {
        let mut args = array![];
        args.append_serde(account);

        try_selector_with_fallback(
            *self.contract_address, selector!("balance_of"), selector!("balanceOf"), args.span()
        )
            .unwrap_and_cast()
    }

    fn allowance(self: @DualERC20, owner: ContractAddress, spender: ContractAddress) -> u256 {
        let mut args = array![];
        args.append_serde(owner);
        args.append_serde(spender);

        call_contract_syscall(*self.contract_address, selector!("allowance"), args.span())
            .unwrap_and_cast()
    }

    fn transfer(self: @DualERC20, recipient: ContractAddress, amount: u256) -> bool {
        let mut args = array![];
        args.append_serde(recipient);
        args.append_serde(amount);

        call_contract_syscall(*self.contract_address, selector!("transfer"), args.span())
            .unwrap_and_cast()
    }

    fn transfer_from(
        self: @DualERC20, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool {
        let mut args = array![];
        args.append_serde(sender);
        args.append_serde(recipient);
        args.append_serde(amount);

        try_selector_with_fallback(
            *self.contract_address,
            selector!("transfer_from"),
            selector!("transferFrom"),
            args.span()
        )
            .unwrap_and_cast()
    }

    fn approve(self: @DualERC20, spender: ContractAddress, amount: u256) -> bool {
        let mut args = array![];
        args.append_serde(spender);
        args.append_serde(amount);

        call_contract_syscall(*self.contract_address, selector!("approve"), args.span())
            .unwrap_and_cast()
    }
}
