// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.18.0 (governance/multisig/interface.cairo)

use starknet::ContractAddress;
use starknet::account::Call;

pub type TransactionID = u64;

#[derive(Copy, Drop, Serde)]
pub enum TransactionStatus {
    NotFound,
    Submitted,
    Confirmed,
    Executed
}

/// Interface for a contract providing the Multisig functionality.
#[starknet::interface]
pub trait IMultisig<TState> {
    fn is_confirmed(self: @TState, id: TransactionID) -> bool;
    fn is_executed(self: @TState, id: TransactionID) -> bool;
    fn get_transaction_status(self: @TState, id: TransactionID) -> TransactionStatus;
    fn get_transaction_calls(self: @TState, id: TransactionID) -> Span<Call>;
    fn get_threshold(self: @TState) -> u32;
    fn is_signer(self: @TState, signer: ContractAddress) -> bool;
    fn add_signers(ref self: TState, new_threshold: u32, signers_to_add: Span<ContractAddress>);
    fn remove_signers(
        ref self: TState, new_threshold: u32, signers_to_remove: Span<ContractAddress>
    );
    fn replace_signer(
        ref self: TState, signer_to_remove: ContractAddress, signer_to_add: ContractAddress
    );
    fn change_threshold(ref self: TState, new_threshold: u32);
    fn submit_transaction(
        ref self: TState, to: ContractAddress, selector: felt252, calldata: Span<felt252>
    ) -> TransactionID;
    fn submit_transaction_batch(ref self: TState, calls: Span<Call>) -> TransactionID;
    fn confirm_transaction(ref self: TState, id: TransactionID);
    fn revoke_confirmation(ref self: TState, id: TransactionID);
    fn execute_transaction(ref self: TState, id: TransactionID);
}
