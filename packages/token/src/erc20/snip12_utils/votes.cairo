// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.17.0 (token/erc20/snip12_utils/votes.cairo)

use core::hash::{HashStateTrait, HashStateExTrait};
use core::poseidon::PoseidonTrait;
use openzeppelin_utils::cryptography::snip12::StructHash;
use starknet::ContractAddress;

// sn_keccak("\"Delegation\"(\"delegatee\":\"ContractAddress\",\"nonce\":\"felt\",\"expiry\":\"u128\")")
//
// Since there's no u64 type in SNIP-12, we use u128 for `expiry` in the type hash generation.
pub const DELEGATION_TYPE_HASH: felt252 =
    0x241244ac7acec849adc6df9848262c651eb035a3add56e7f6c7bcda6649e837;

#[derive(Copy, Drop, Hash)]
pub struct Delegation {
    pub delegatee: ContractAddress,
    pub nonce: felt252,
    pub expiry: u64
}

impl StructHashImpl of StructHash<Delegation> {
    fn hash_struct(self: @Delegation) -> felt252 {
        PoseidonTrait::new().update_with(DELEGATION_TYPE_HASH).update_with(*self).finalize()
    }
}
