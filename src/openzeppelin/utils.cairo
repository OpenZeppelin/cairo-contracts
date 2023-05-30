use starknet::call_contract_syscall;
use starknet::ContractAddress;
use starknet::SyscallResult;
use array::ArrayTrait;
use array::SpanTrait;
use box::BoxTrait;
use option::OptionTrait;
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
                return Result::Err(r);
            }
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
