// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v2.0.0-alpha.1 (presets/src/meta_tx_v0.cairo)

use core::gas::GasBuiltin;
use starknet::ContractAddress;

#[starknet::contract]
pub mod MetaTransactionV0 {
    use crate::interfaces::MetaTransactionV0ABI;
    use super::{ContractAddress, meta_tx_v0_syscall};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl MetaTransactionV0Impl of MetaTransactionV0ABI<ContractState> {
        /// Wrapper around the `meta_tx_v0_syscall` function.
        ///
        /// Invokes the given entry point as a v0 meta transaction.
        ///
        /// * The signature is replaced with the given signature.
        /// * The caller is the OS (address 0).
        /// * The transaction version is replaced by 0.
        /// * The transaction hash is replaced by the corresponding version-0 transaction hash.
        ///
        /// The changes apply to the called contract and the inner contracts it calls.
        ///
        /// NOTE: This syscall should only be used to allow support for old version-0 bound
        /// accounts, and should not be used for other purposes.
        fn execute_meta_tx_v0(
            ref self: ContractState,
            target: ContractAddress,
            entry_point_selector: felt252,
            calldata: Span<felt252>,
            signature: Span<felt252>,
        ) -> starknet::SyscallResult<Span<felt252>> {
            meta_tx_v0_syscall(target, entry_point_selector, calldata, signature)
        }
    }
}

// Temporary local declaration of the syscall until it gets exposed as a public
// function in corelib
extern fn meta_tx_v0_syscall(
    address: ContractAddress,
    entry_point_selector: felt252,
    calldata: Span<felt252>,
    signature: Span<felt252>,
) -> starknet::SyscallResult<Span<felt252>> implicits(GasBuiltin, System) nopanic;
