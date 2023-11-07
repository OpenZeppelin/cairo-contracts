// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0-beta.1 (utils/cryptography/typed_message.cairo)

// Utils for off-chain typed message generation.

use core::hash::HashStateExTrait;
use hash::{HashStateTrait, Hash};
use pedersen::{PedersenTrait, HashState};
use starknet::ContractAddress;

// sn_keccak('StarkNetDomain(name:felt,version:felt,chainId:felt)')
const STARKNET_DOMAIN_TYPE_HASH: felt252 =
    0x1bfc207425a47a5dfa1a50a4f5241203f50624ca5fdf5e18755765416b8e288;

#[derive(Drop, Copy, Hash)]
struct StarknetDomain {
    name: felt252,
    version: felt252,
    chain_id: felt252,
}

trait IStructHash<T> {
    fn hash_struct(self: @T) -> felt252;
}

trait IOffchainMessageHash<T> {
    fn get_message_hash(
        self: @T, name: felt252, version: felt252, owner: ContractAddress
    ) -> felt252;
}

impl StructHashStarknetDomain of IStructHash<StarknetDomain> {
    fn hash_struct(self: @StarknetDomain) -> felt252 {
        let hash_state = PedersenTrait::new(0);
        hash_state
            .update_with(STARKNET_DOMAIN_TYPE_HASH)
            .update_with(*self)
            .update_with(4)
            .finalize()
    }
}
