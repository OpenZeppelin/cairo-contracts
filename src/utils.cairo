// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.12.0 (utils.cairo)

mod cryptography;
mod deployments;
mod interfaces;
mod math;
mod selectors;
mod serde;
mod structs;
mod unwrap_and_cast;

use cryptography::nonces;
use cryptography::snip12;
use starknet::ContractAddress;
use starknet::SyscallResult;
use starknet::SyscallResultTrait;
use starknet::call_contract_syscall;
use unwrap_and_cast::UnwrapAndCast;

fn try_selector_with_fallback(
    target: ContractAddress, selector: felt252, fallback: felt252, args: Span<felt252>
) -> SyscallResult<Span<felt252>> {
    match call_contract_syscall(target, selector, args) {
        Result::Ok(ret) => Result::Ok(ret),
        Result::Err(errors) => {
            if *errors.at(0) == 'ENTRYPOINT_NOT_FOUND' {
                return call_contract_syscall(target, fallback, args);
            } else {
                Result::Err(errors)
            }
        }
    }
}
