// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v2.0.0-alpha.1 (presets/src/meta_tx_v0.cairo)

#[starknet::contract]
pub mod MetaTransactionV0 {
    use starknet::ContractAddress;
    use starknet::syscalls::meta_tx_v0_syscall;
    use crate::interfaces::MetaTransactionV0ABI;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl MetaTransactionV0Impl of MetaTransactionV0ABI<ContractState> {
        /// Wrapper around the `meta_tx_v0_syscall` function.
        ///
        /// * The signature is replaced with the given signature.
        /// * The caller is the OS (address 0).
        /// * The transaction version is replaced by 0.
        /// * The transaction hash is replaced by the corresponding version-0 transaction hash.
        ///
        /// The context changes apply to the called contract and the inner contracts it calls,
        /// except for the caller, which is updated appropriately in subcalls.
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
