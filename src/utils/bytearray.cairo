///
/// TMP - remove once ByteArrayStore is merged to corelib
///

use core::bytes_31::BYTES_IN_BYTES31;
use starknet::storage_access::{
    StorageBaseAddress, storage_address_from_base, storage_address_from_base_and_offset,
    StorageAddress, storage_base_address_from_felt252
};
use starknet::storage_access;
use starknet::{
    SyscallResult, syscalls::{storage_read_syscall, storage_write_syscall},
    contract_address::{ContractAddress, Felt252TryIntoContractAddress, ContractAddressIntoFelt252},
    class_hash::{ClassHash, Felt252TryIntoClassHash, ClassHashIntoFelt252}
};

impl ByteArrayStore of starknet::Store<ByteArray> {
    #[inline(always)]
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<ByteArray> {
        inner_read_byte_array(address_domain, storage_address_from_base(base))
    }
    #[inline(always)]
    fn write(address_domain: u32, base: StorageBaseAddress, value: ByteArray) -> SyscallResult<()> {
        inner_write_byte_array(address_domain, storage_address_from_base(base), value)
    }
    #[inline(always)]
    fn read_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8
    ) -> SyscallResult<ByteArray> {
        inner_read_byte_array(address_domain, storage_address_from_base_and_offset(base, offset))
    }
    #[inline(always)]
    fn write_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8, value: ByteArray
    ) -> SyscallResult<()> {
        inner_write_byte_array(
            address_domain, storage_address_from_base_and_offset(base, offset), value
        )
    }
    #[inline(always)]
    fn size() -> u8 {
        1
    }
}

/// Returns a pointer to the `chunk`'th chunk of the byte array at `address`.
/// The pointer is a `Poseidon` hash over:
/// * `address` - The address "containing" the ByteArray (but actually stores just the length).
/// * `chunk` - The index of the chunk.
/// * The short string `ByteArray` as the capacity.
fn inner_byte_array_pointer(address: StorageAddress, chunk: felt252) -> StorageBaseAddress {
    let (r, _, _) = core::poseidon::hades_permutation(address.into(), chunk, 'ByteArray'_felt252);
    storage_base_address_from_felt252(r)
}

/// Reads a byte array from storage from domain `address_domain` and address `address`.
/// The length of the byte array is read from `address` at domain `address_domain`.
/// For more info read the documentation of `ByteArrayStore`.
fn inner_read_byte_array(address_domain: u32, address: StorageAddress) -> SyscallResult<ByteArray> {
    let len: usize =
        match starknet::syscalls::storage_read_syscall(address_domain, address)?.try_into() {
        Option::Some(x) => x,
        Option::None => { return SyscallResult::Err(array!['Invalid ByteArray length']); },
    };
    let (mut remaining_full_words, pending_word_len) = core::DivRem::div_rem(
        len, BYTES_IN_BYTES31.try_into().unwrap()
    );
    let mut chunk = 0;
    let mut chunk_base = inner_byte_array_pointer(address, chunk);
    let mut index_in_chunk = 0_u8;
    let mut result: ByteArray = Default::default();
    loop {
        if remaining_full_words == 0 {
            break Result::Ok(());
        }
        let value =
            match starknet::syscalls::storage_read_syscall(
                address_domain, storage_address_from_base_and_offset(chunk_base, index_in_chunk)
            ) {
            Result::Ok(value) => value,
            Result::Err(err) => { break Result::Err(err); },
        };
        let value: bytes31 = match value.try_into() {
            Option::Some(x) => x,
            Option::None => { break Result::Err(array!['Invalid value']); },
        };
        result.data.append(value);
        remaining_full_words -= 1;
        index_in_chunk = match core::integer::u8_overflowing_add(index_in_chunk, 1) {
            Result::Ok(x) => x,
            Result::Err(_) => {
                // After reading 256 `bytes31`s `index_in_chunk` will overflow and we move to the
                // next chunk.
                chunk += 1;
                chunk_base = inner_byte_array_pointer(address, chunk);
                0
            },
        };
    }?;
    if pending_word_len != 0 {
        result
            .pending_word =
                starknet::syscalls::storage_read_syscall(
                    address_domain, storage_address_from_base_and_offset(chunk_base, index_in_chunk)
                )?;
        result.pending_word_len = pending_word_len;
    }
    Result::Ok(result)
}

/// Writes a byte array to storage to domain `address_domain` and address `address`.
/// The length of the byte array is written to `address` at domain `address_domain`.
/// For more info read the documentation of `ByteArrayStore`.
fn inner_write_byte_array(
    address_domain: u32, address: StorageAddress, value: ByteArray
) -> SyscallResult<()> {
    let len = value.len();
    starknet::syscalls::storage_write_syscall(address_domain, address, len.into())?;
    let mut full_words = value.data.span();
    let mut chunk = 0;
    let mut chunk_base = inner_byte_array_pointer(address, chunk);
    let mut index_in_chunk = 0_u8;
    loop {
        let curr_value = match full_words.pop_front() {
            Option::Some(x) => x,
            Option::None => { break Result::Ok(()); },
        };
        match starknet::syscalls::storage_write_syscall(
            address_domain,
            storage_address_from_base_and_offset(chunk_base, index_in_chunk),
            (*curr_value).into()
        ) {
            Result::Ok(_) => {},
            Result::Err(err) => { break Result::Err(err); },
        };
        index_in_chunk = match core::integer::u8_overflowing_add(index_in_chunk, 1) {
            Result::Ok(x) => x,
            Result::Err(_) => {
                // After writing 256 `byte31`s `index_in_chunk` will overflow and we move to the
                // next chunk.
                chunk += 1;
                chunk_base = inner_byte_array_pointer(address, chunk);
                0
            },
        };
    }?;
    if value.pending_word_len != 0 {
        starknet::syscalls::storage_write_syscall(
            address_domain,
            storage_address_from_base_and_offset(chunk_base, index_in_chunk),
            value.pending_word
        )?;
    }
    Result::Ok(())
}
