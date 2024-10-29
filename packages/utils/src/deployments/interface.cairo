// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.18.0 (utils/deployments/interface.cairo)

use starknet::{ClassHash, ContractAddress};

#[starknet::interface]
pub trait IUniversalDeployer<TState> {
    fn deploy_contract(
        ref self: TState,
        class_hash: ClassHash,
        salt: felt252,
        from_zero: bool,
        calldata: Span<felt252>
    ) -> ContractAddress;
}
