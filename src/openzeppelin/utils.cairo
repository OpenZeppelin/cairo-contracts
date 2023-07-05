mod constants;
mod selectors;
mod serde;

use array::ArrayTrait;
use array::SpanTrait;
use box::BoxTrait;
use option::OptionTrait;
use starknet::call_contract_syscall;
use starknet::ContractAddress;
use starknet::Felt252TryIntoContractAddress;
use starknet::SyscallResult;
use starknet::SyscallResultTrait;
use traits::TryInto;

fn try_selector_with_fallback(
    target: ContractAddress, snake_selector: felt252, camel_selector: felt252, args: Span<felt252>
) -> SyscallResult<Span<felt252>> {
    match call_contract_syscall(target, snake_selector, args) {
        Result::Ok(ret) => Result::Ok(ret),
        Result::Err(errors) => {
            if *errors.at(0) == 'ENTRYPOINT_NOT_FOUND' {
                return call_contract_syscall(target, camel_selector, args);
            } else {
                Result::Err(errors)
            }
        }
    }
}

impl BoolIntoFelt252 of Into<bool, felt252> {
    fn into(self: bool) -> felt252 {
        if self {
            return 1;
        } else {
            return 0;
        }
    }
}

impl Felt252TryIntoBool of TryInto<felt252, bool> {
    fn try_into(self: felt252) -> Option<bool> {
        if self == 0 {
            Option::Some(false)
        } else if self == 1 {
            Option::Some(true)
        } else {
            Option::None(())
        }
    }
}

#[inline(always)]
fn check_gas() {
    match gas::withdraw_gas() {
        Option::Some(_) => {},
        Option::None(_) => {
            let mut data = ArrayTrait::new();
            data.append('Out of gas');
            panic(data);
        },
    }
}

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
