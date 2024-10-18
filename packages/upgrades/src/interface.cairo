// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.18.0 (upgrades/interface.cairo)

use starknet::ClassHash;

#[starknet::interface]
pub trait IUpgradeable<TState> {
    fn upgrade(ref self: TState, new_class_hash: ClassHash);
}

#[starknet::interface]
pub trait IUpgradeAndCall<TState> {
    fn upgrade_and_call(
        ref self: TState, new_class_hash: ClassHash, selector: felt252, calldata: Span<felt252>
    ) -> Span<felt252>;
}
