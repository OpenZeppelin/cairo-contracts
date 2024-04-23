// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.12.0 (utils/cryptography/snip12.cairo)

use core::hash::HashStateExTrait;
use hash::{HashStateTrait, Hash};
use poseidon::PoseidonTrait;
use starknet::{ContractAddress, get_tx_info};

// selector!(
//   "\"StarknetDomain\"(
//    \"name\":\"shortstring\",
//    \"version\":\"shortstring\",
//    \"chainId\":\"shortstring\",
//    \"revision\":\"shortstring\"
//   )"
// );
const STARKNET_DOMAIN_TYPE_HASH: felt252 =
    0x1ff2f602e42168014d405a94f75e8a93d640751d71d16311266e140d8b0a210;

#[derive(Drop, Copy, Hash)]
struct StarknetDomain {
    name: felt252,
    version: felt252,
    chain_id: felt252,
    revision: felt252,
}

trait StructHash<T> {
    fn hash_struct(self: @T) -> felt252;
}

trait OffchainMessageHash<T> {
    fn get_message_hash(self: @T, signer: ContractAddress) -> felt252;
}

impl StructHashStarknetDomainImpl of StructHash<StarknetDomain> {
    fn hash_struct(self: @StarknetDomain) -> felt252 {
        let hash_state = PoseidonTrait::new();
        hash_state.update_with(STARKNET_DOMAIN_TYPE_HASH).update_with(*self).finalize()
    }
}

trait SNIP12Metadata {
    /// Returns the name of the dapp.
    fn name() -> felt252;

    /// Returns the version of the dapp.
    fn version() -> felt252;
}

impl OffchainMessageHashImpl<
    T, +StructHash<T>, impl metadata: SNIP12Metadata
> of OffchainMessageHash<T> {
    fn get_message_hash(self: @T, signer: ContractAddress) -> felt252 {
        let domain = StarknetDomain {
            name: metadata::name(),
            version: metadata::version(),
            chain_id: get_tx_info().unbox().chain_id,
            revision: 1
        };
        let mut state = PoseidonTrait::new();
        state = state.update_with('StarkNet Message');
        state = state.update_with(domain.hash_struct());
        state = state.update_with(signer);
        state = state.update_with(self.hash_struct());
        state.finalize()
    }
}
