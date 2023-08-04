// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (utils/unwrap_and_cast.cairo)

use array::SpanTrait;

use openzeppelin::utils::Felt252TryIntoBool;
use option::OptionTrait;
use starknet::ContractAddress;
use starknet::Felt252TryIntoContractAddress;
use starknet::SyscallResult;
use starknet::SyscallResultTrait;
use traits::TryInto;

trait UnwrapAndCast<T> {
    fn unwrap_and_cast(self: SyscallResult<Span<felt252>>) -> T;
}

impl UnwrapAndCastBool of UnwrapAndCast<bool> {
    fn unwrap_and_cast(self: SyscallResult<Span<felt252>>) -> bool {
        (*self.unwrap_syscall().at(0)).try_into().unwrap()
    }
}

impl UnwrapAndCastContractAddress of UnwrapAndCast<ContractAddress> {
    fn unwrap_and_cast(self: SyscallResult<Span<felt252>>) -> ContractAddress {
        (*self.unwrap_syscall().at(0)).try_into().unwrap()
    }
}

impl UnwrapFelt of UnwrapAndCast<felt252> {
    fn unwrap_and_cast(self: SyscallResult<Span<felt252>>) -> felt252 {
        *self.unwrap_syscall().at(0)
    }
}

impl UnwrapAndCastU8 of UnwrapAndCast<u8> {
    fn unwrap_and_cast(self: SyscallResult<Span<felt252>>) -> u8 {
        (*self.unwrap_syscall().at(0)).try_into().unwrap()
    }
}

impl UnwrapAndCastU256 of UnwrapAndCast<u256> {
    fn unwrap_and_cast(self: SyscallResult<Span<felt252>>) -> u256 {
        let unwrapped = self.unwrap_syscall();
        u256 {
            low: (*unwrapped.at(0)).try_into().unwrap(),
            high: (*unwrapped.at(1)).try_into().unwrap(),
        }
    }
}
