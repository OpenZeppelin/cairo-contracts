// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.12.0 (utils/universal_deployer/interface.cairo)

use starknet::ClassHash;
use starknet::ContractAddress;

#[starknet::interface]
trait IUniversalDeployer<TState> {
    fn deploy_contract(
        ref self: TState,
        class_hash: ClassHash,
        salt: felt252,
        from_zero: bool,
        calldata: Span<felt252>
    ) -> ContractAddress;
}
