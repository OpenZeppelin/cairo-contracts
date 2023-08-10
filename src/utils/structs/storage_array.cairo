// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (utils/structs/storage_array.cairo)

use array::ArrayTrait;
use integer::Felt252TryIntoU32;
use option::OptionTrait;
use poseidon::poseidon_hash_span;
use starknet::{
    StorageBaseAddress, Store, SyscallResultTrait, SyscallResult, storage_address_from_base,
    storage_base_address_from_felt252, storage_read_syscall, storage_write_syscall
};
use traits::{Into, TryInto};

const NOT_IMPLEMENTED: felt252 = 'Not implemented';

/// Represents an Array that can be stored in storage.
#[derive(Copy, Drop)]
struct StorageArray<T> {
    address_domain: u32,
    base: StorageBaseAddress
}

impl StoreStorageArray<T, impl TDrop: Drop<T>, impl TStore: Store<T>> of Store<StorageArray<T>> {
    #[inline(always)]
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<StorageArray<T>> {
        SyscallResult::Ok(StorageArray { address_domain, base })
    }
    #[inline(always)]
    fn write(
        address_domain: u32, base: StorageBaseAddress, value: StorageArray<T>
    ) -> SyscallResult<()> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }
    #[inline(always)]
    fn read_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8
    ) -> SyscallResult<StorageArray<T>> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }
    #[inline(always)]
    fn write_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8, value: StorageArray<T>
    ) -> SyscallResult<()> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }
    #[inline(always)]
    fn size() -> u8 {
        // TODO: Check with size make sense in this context.
        // 1 was selected because the len is stored at base.
        1_u8
    }
}

/// Trait for accessing a storage array.
///
/// `read_at` and `write_at` don't check the len of the array, caution must be exercised.
/// The current len of the array is stored at the base StorageBaseAddress as felt.
trait StorageArrayTrait<T> {
    fn read_at(self: @StorageArray<T>, index: usize) -> T;
    fn write_at(ref self: StorageArray<T>, index: usize, value: T) -> ();
    fn append(ref self: StorageArray<T>, value: T) -> ();
    fn len(self: @StorageArray<T>) -> u32;
}

impl StorageArrayImpl<T, impl TDrop: Drop<T>, impl TStore: Store<T>> of StorageArrayTrait<T> {
    fn read_at(self: @StorageArray<T>, index: usize) -> T {
        // Get the storage address of the element.
        let storage_address_felt: felt252 = storage_address_from_base(*self.base).into();
        let element_address = poseidon_hash_span(
            array![storage_address_felt + index.into()].span()
        );

        // Read the element from storage.
        TStore::read(*self.address_domain, storage_base_address_from_felt252(element_address))
            .unwrap_syscall()
    }

    fn write_at(ref self: StorageArray<T>, index: usize, value: T) {
        // Get the storage address of the element.
        let storage_address_felt: felt252 = storage_address_from_base(self.base).into();
        let element_address = poseidon_hash_span(
            array![storage_address_felt + index.into()].span()
        );

        // Write the element to storage.
        TStore::write(
            self.address_domain, storage_base_address_from_felt252(element_address), value
        )
            .unwrap_syscall()
    }

    fn append(ref self: StorageArray<T>, value: T) {
        // Get the storage address of the element.
        let storage_address_felt: felt252 = storage_address_from_base(self.base).into();
        let element_address = poseidon_hash_span(
            array![storage_address_felt + self.len().into()].span()
        );

        // Write the element to storage.
        TStore::write(
            self.address_domain, storage_base_address_from_felt252(element_address), value
        )
            .unwrap_syscall();

        // Update the len.
        let new_len: felt252 = (self.len() + 1).into();
        storage_write_syscall(self.address_domain, storage_address_from_base(self.base), new_len)
            .unwrap_syscall();
    }

    fn len(self: @StorageArray<T>) -> u32 {
        storage_read_syscall(*self.address_domain, storage_address_from_base(*self.base))
            .unwrap_syscall()
            .try_into()
            .unwrap()
    }
}
