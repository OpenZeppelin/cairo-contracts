use array::ArrayTrait;
use array::SpanTrait;
use core::result::ResultTrait;
use integer::Felt252TryIntoU8;
use option::OptionTrait;
use starknet::call_contract_syscall;
use starknet::ContractAddress;
use starknet::Felt252TryIntoContractAddress;
use starknet::SyscallResultTrait;
use traits::Into;
use traits::TryInto;

use openzeppelin::utils::try_selector_with_fallback;
use openzeppelin::utils::Felt252TryIntoBool;
use openzeppelin::utils::BoolIntoFelt252;
use openzeppelin::utils::selectors;

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
        *call_contract_syscall(
            *self.contract_address, selectors::name, ArrayTrait::new().span()
        )
            .unwrap_syscall()
            .at(0)
    }

    fn symbol(self: @DualERC20) -> felt252 {
        *call_contract_syscall(
            *self.contract_address, selectors::symbol, ArrayTrait::new().span()
        )
            .unwrap_syscall()
            .at(0)
    }

    fn decimals(self: @DualERC20) -> u8 {
        (*call_contract_syscall(
            *self.contract_address, selectors::decimals, ArrayTrait::new().span()
        )
            .unwrap_syscall()
            .at(0))
            .try_into()
            .unwrap()
    }

    fn total_supply(self: @DualERC20) -> u256 {
        let snake_selector = selectors::total_supply;
        let camel_selector = selectors::totalSupply;

        let mut args = ArrayTrait::new();
        let res = try_selector_with_fallback(
            *self.contract_address, snake_selector, camel_selector, args.span()
        )
            .unwrap_syscall();

        u256 { low: (*res.at(0)).try_into().unwrap(), high: (*res.at(1)).try_into().unwrap(),  }
    }

    fn balance_of(self: @DualERC20, account: ContractAddress) -> u256 {
        let snake_selector = selectors::balance_of;
        let camel_selector = selectors::balanceOf;

        let mut args = ArrayTrait::new();
        args.append(account.into());

        let res = try_selector_with_fallback(
            *self.contract_address, snake_selector, camel_selector, args.span()
        )
            .unwrap_syscall();

        u256 { low: (*res.at(0)).try_into().unwrap(), high: (*res.at(1)).try_into().unwrap(),  }
    }

    fn allowance(self: @DualERC20, owner: ContractAddress, spender: ContractAddress) -> u256 {
        let mut args = ArrayTrait::new();
        args.append(owner.into());
        args.append(spender.into());

        let res = call_contract_syscall(
            *self.contract_address, selectors::allowance, args.span()
        )
            .unwrap_syscall();

        u256 { low: (*res.at(0)).try_into().unwrap(), high: (*res.at(1)).try_into().unwrap(),  }
    }

    fn transfer(self: @DualERC20, recipient: ContractAddress, amount: u256) -> bool {
        let mut args = ArrayTrait::new();
        args.append(recipient.into());
        args.append(amount.low.into());
        args.append(amount.high.into());

        (*call_contract_syscall(*self.contract_address, selectors::transfer, args.span())
            .unwrap_syscall()
            .at(0))
            .try_into()
            .unwrap()
    }

    fn transfer_from(
        self: @DualERC20, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool {
        let snake_selector = selectors::transfer_from;
        let camel_selector = selectors::transferFrom;

        let mut args = ArrayTrait::new();
        args.append(sender.into());
        args.append(recipient.into());
        args.append(amount.low.into());
        args.append(amount.high.into());

        (*try_selector_with_fallback(
            *self.contract_address, snake_selector, camel_selector, args.span()
        )
            .unwrap_syscall()
            .at(0))
            .try_into()
            .unwrap()
    }

    fn approve(self: @DualERC20, spender: ContractAddress, amount: u256) -> bool {
        let mut args = ArrayTrait::new();
        args.append(spender.into());
        args.append(amount.low.into());
        args.append(amount.high.into());
        (*call_contract_syscall(*self.contract_address, selectors::approve, args.span())
            .unwrap_syscall()
            .at(0))
            .try_into()
            .unwrap()
    }
}
