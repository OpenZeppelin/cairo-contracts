// SPDX-License-Identifier: MIT
use openzeppelin::utils::UnwrapAndCast;
use openzeppelin::utils::selectors;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::utils::try_selector_with_fallback;
use starknet::ContractAddress;
use starknet::SyscallResultTrait;
use starknet::syscalls::call_contract_syscall;

#[derive(Copy, Drop)]
pub struct DualCaseERC6909 {
    pub contract_address: ContractAddress
}

pub trait DualCaseERC6909Trait {
    fn balance_of(self: @DualCaseERC6909, owner: ContractAddress, id: u256) -> u256;
    fn allowance(
        self: @DualCaseERC6909, owner: ContractAddress, spender: ContractAddress, id: u256
    ) -> u256;
    fn is_operator(
        self: @DualCaseERC6909, owner: ContractAddress, spender: ContractAddress
    ) -> bool;
    fn transfer(self: @DualCaseERC6909, receiver: ContractAddress, id: u256, amount: u256) -> bool;
    fn transfer_from(
        self: @DualCaseERC6909,
        sender: ContractAddress,
        receiver: ContractAddress,
        id: u256,
        amount: u256
    ) -> bool;
    fn approve(self: @DualCaseERC6909, spender: ContractAddress, id: u256, amount: u256) -> bool;
    fn set_operator(self: @DualCaseERC6909, spender: ContractAddress, approved: bool) -> bool;
    fn supports_interface(self: @DualCaseERC6909, interface_id: felt252) -> bool;
}

impl DualCaseERC6909Impl of DualCaseERC6909Trait {
    fn balance_of(self: @DualCaseERC6909, owner: ContractAddress, id: u256) -> u256 {
        let mut args = array![];
        args.append_serde(owner);
        args.append_serde(id);

        try_selector_with_fallback(
            *self.contract_address, selectors::balance_of, selectors::balanceOf, args.span()
        )
            .unwrap_and_cast()
    }

    fn allowance(
        self: @DualCaseERC6909, owner: ContractAddress, spender: ContractAddress, id: u256
    ) -> u256 {
        let mut args = array![];
        args.append_serde(owner);
        args.append_serde(spender);
        args.append_serde(id);

        call_contract_syscall(*self.contract_address, selectors::allowance, args.span())
            .unwrap_and_cast()
    }

    fn is_operator(
        self: @DualCaseERC6909, owner: ContractAddress, spender: ContractAddress
    ) -> bool {
        let mut args = array![];
        args.append_serde(owner);
        args.append_serde(spender);

        let is_operator: felt252 = selectors::is_operator;
        let isOperator: felt252 = selectors::isOperator;

        try_selector_with_fallback(*self.contract_address, is_operator, isOperator, args.span())
            .unwrap_and_cast()
    }

    fn transfer(self: @DualCaseERC6909, receiver: ContractAddress, id: u256, amount: u256) -> bool {
        let mut args = array![];
        args.append_serde(receiver);
        args.append_serde(id);
        args.append_serde(amount);

        call_contract_syscall(*self.contract_address, selectors::transfer, args.span())
            .unwrap_and_cast()
    }

    fn transfer_from(
        self: @DualCaseERC6909,
        sender: ContractAddress,
        receiver: ContractAddress,
        id: u256,
        amount: u256
    ) -> bool {
        let mut args = array![];
        args.append_serde(sender);
        args.append_serde(receiver);
        args.append_serde(id);
        args.append_serde(amount);

        try_selector_with_fallback(
            *self.contract_address, selectors::transfer_from, selectors::transferFrom, args.span()
        )
            .unwrap_and_cast()
    }

    fn approve(self: @DualCaseERC6909, spender: ContractAddress, id: u256, amount: u256) -> bool {
        let mut args = array![];
        args.append_serde(spender);
        args.append_serde(id);
        args.append_serde(amount);

        call_contract_syscall(*self.contract_address, selectors::approve, args.span())
            .unwrap_and_cast()
    }

    fn set_operator(self: @DualCaseERC6909, spender: ContractAddress, approved: bool) -> bool {
        let mut args = array![];
        args.append_serde(spender);
        args.append_serde(approved);

        let set_operator: felt252 = selectors::set_operator;
        let setOperator: felt252 = selectors::setOperator;

        try_selector_with_fallback(*self.contract_address, set_operator, setOperator, args.span())
            .unwrap_and_cast()
    }

    fn supports_interface(self: @DualCaseERC6909, interface_id: felt252) -> bool {
        let mut args = array![];
        args.append_serde(interface_id);

        let supports_interface: felt252 = selectors::supports_interface;
        let supportsInterface: felt252 = selectors::supportsInterface;

        try_selector_with_fallback(
            *self.contract_address, supports_interface, supportsInterface, args.span()
        )
            .unwrap_and_cast()
    }
}
