// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.15.1 (utils/utils.cairo)

pub mod cryptography;
pub mod deployments;
pub mod interfaces;
pub mod math;
pub mod selectors;
pub mod serde;
pub mod structs;

#[cfg(test)]
mod tests;

pub mod unwrap_and_cast;

pub use cryptography::{nonces, snip12};
pub use unwrap_and_cast::UnwrapAndCast;
use starknet::syscalls::call_contract_syscall;

use starknet::{ContractAddress, SyscallResult};

pub fn try_selector_with_fallback(
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
