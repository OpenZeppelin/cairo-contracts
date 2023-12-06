// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0 (utils.cairo)

mod selectors;
mod serde;
mod unwrap_and_cast;

use core::pedersen::pedersen;
use starknet::ContractAddress;
use starknet::SyscallResult;
use starknet::SyscallResultTrait;
use starknet::call_contract_syscall;
use starknet::storage_address_try_from_felt252;
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

/// Manually deletes `erc165_id` value from the storage variable
/// `ERC165_supported_interfaces` in the calling contract's storage.
/// This function should only be used by a migration initializer during the
/// ERC165-to-SRC5 migration process.
fn deregister_erc165_interface(erc165_id: felt252) {
    let address_domain = 0_u32;
    let base_address = selector!("ERC165_supported_interfaces");
    let storage_address = storage_address_try_from_felt252(pedersen(base_address, erc165_id))
        .unwrap();

    starknet::storage_write_syscall(address_domain, storage_address, 0);
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
