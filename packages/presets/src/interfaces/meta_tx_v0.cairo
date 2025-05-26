use starknet::ContractAddress;

#[starknet::interface]
pub trait MetaTransactionV0ABI<TState> {
    /// Wrapper around the `meta_tx_v0_syscall` function.
    ///
    /// Invokes the given entry point as a v0 meta transaction.
    ///
    /// * The signature is replaced with the given signature.
    /// * The caller is the OS (address 0).
    /// * The transaction version is replaced by 0.
    /// * The transaction hash is replaced by the corresponding version-0 transaction hash.
    ///
    /// The context changes apply to the called contract and the inner contracts it calls, except
    /// for the caller, which is updated appropriately in subcalls.
    ///
    /// NOTE: This syscall should only be used to allow support for old version-0 bound accounts,
    /// and should not be used for other purposes.
    fn execute_meta_tx_v0(
        ref self: TState,
        target: ContractAddress,
        entry_point_selector: felt252,
        calldata: Span<felt252>,
        signature: Span<felt252>,
    ) -> starknet::SyscallResult<Span<felt252>>;
}
