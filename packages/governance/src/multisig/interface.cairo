// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.18.0 (governance/multisig/interface.cairo)

use starknet::ContractAddress;
use starknet::account::Call;

pub type TransactionID = felt252;

#[derive(Copy, Drop, Serde, PartialEq, Debug)]
pub enum TransactionState {
    NotFound,
    Pending,
    Confirmed,
    Executed
}

/// Interface for a contract providing the Multisig functionality.
#[starknet::interface]
pub trait IMultisig<TState> {
    fn get_quorum(self: @TState) -> u8;
    fn is_signer(self: @TState, signer: ContractAddress) -> bool;
    fn get_signers(self: @TState) -> Span<ContractAddress>;
    fn is_confirmed(self: @TState, id: TransactionID) -> bool;
    fn is_confirmed_by(self: @TState, id: TransactionID, signer: ContractAddress) -> bool;
    fn is_executed(self: @TState, id: TransactionID) -> bool;
    fn get_submitted_block(self: @TState, id: TransactionID) -> u64;
    fn get_transaction_state(self: @TState, id: TransactionID) -> TransactionState;
    fn get_transaction_confirmations(self: @TState, id: TransactionID) -> u8;
    fn hash_transaction(
        self: @TState,
        to: ContractAddress,
        selector: felt252,
        calldata: Span<felt252>,
        salt: felt252
    ) -> TransactionID;
    fn hash_transaction_batch(self: @TState, calls: Span<Call>, salt: felt252) -> TransactionID;

    fn add_signers(ref self: TState, new_quorum: u8, signers_to_add: Span<ContractAddress>);
    fn remove_signers(ref self: TState, new_quorum: u8, signers_to_remove: Span<ContractAddress>);
    fn replace_signer(
        ref self: TState, signer_to_remove: ContractAddress, signer_to_add: ContractAddress
    );
    fn change_quorum(ref self: TState, new_quorum: u8);
    fn submit_transaction(
        ref self: TState,
        to: ContractAddress,
        selector: felt252,
        calldata: Span<felt252>,
        salt: felt252,
    ) -> TransactionID;
    fn submit_transaction_batch(
        ref self: TState, calls: Span<Call>, salt: felt252
    ) -> TransactionID;
    fn confirm_transaction(ref self: TState, id: TransactionID);
    fn revoke_confirmation(ref self: TState, id: TransactionID);
    fn execute_transaction(
        ref self: TState,
        to: ContractAddress,
        selector: felt252,
        calldata: Span<felt252>,
        salt: felt252
    );
    fn execute_transaction_batch(ref self: TState, calls: Span<Call>, salt: felt252);
}
