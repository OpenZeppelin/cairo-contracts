use starknet::call_contract_syscall;
use starknet::ContractAddress;
use starknet::SyscallResult;
use option::OptionTrait;
use array::ArrayTrait;
use array::SpanTrait;
use box::BoxTrait;
mod constants;
mod serde;

fn try_selector_with_fallback(
    target: ContractAddress, snake_selector: felt252, camel_selector: felt252, args: Span<felt252>
) -> SyscallResult<Span<felt252>> {
    match call_contract_syscall(target, snake_selector, args) {
        Result::Ok(r) => Result::Ok(r),
        Result::Err(r) => {
            if *r.at(0) == 'ENTRYPOINT_NOT_FOUND' {
                return call_contract_syscall(target, camel_selector, args);
            } else {
                Result::Err(r)
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
