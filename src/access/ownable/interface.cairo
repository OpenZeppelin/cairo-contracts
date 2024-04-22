// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.12.0 (access/ownable/interface.cairo)

use starknet::ContractAddress;

#[starknet::interface]
trait IOwnable<TState> {
    fn owner(self: @TState) -> ContractAddress;
    fn transfer_ownership(ref self: TState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TState);
}

#[starknet::interface]
trait IOwnableCamelOnly<TState> {
    fn transferOwnership(ref self: TState, newOwner: ContractAddress);
    fn renounceOwnership(ref self: TState);
}

#[starknet::interface]
trait OwnableABI<TState> {
    // IOwnable
    fn owner(self: @TState) -> ContractAddress;
    fn transfer_ownership(ref self: TState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TState);

    // IOwnableCamelOnly
    fn transferOwnership(ref self: TState, newOwner: ContractAddress);
    fn renounceOwnership(ref self: TState);
}

#[starknet::interface]
trait IOwnableTwoStep<TState> {
    fn owner(self: @TState) -> ContractAddress;
    fn pending_owner(self: @TState) -> ContractAddress;
    fn accept_ownership(ref self: TState);
    fn transfer_ownership(ref self: TState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TState);
}

#[starknet::interface]
trait IOwnableTwoStepCamelOnly<TState> {
    fn pendingOwner(self: @TState) -> ContractAddress;
    fn acceptOwnership(ref self: TState);
    fn transferOwnership(ref self: TState, newOwner: ContractAddress);
    fn renounceOwnership(ref self: TState);
}

#[starknet::interface]
trait OwnableTwoStepABI<TState> {
    // IOwnableTwoStep
    fn owner(self: @TState) -> ContractAddress;
    fn pending_owner(self: @TState) -> ContractAddress;
    fn accept_ownership(ref self: TState);
    fn transfer_ownership(ref self: TState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TState);

    // IOwnableTwoStepCamelOnly
    fn pendingOwner(self: @TState) -> ContractAddress;
    fn acceptOwnership(ref self: TState);
    fn transferOwnership(ref self: TState, newOwner: ContractAddress);
    fn renounceOwnership(ref self: TState);
}
