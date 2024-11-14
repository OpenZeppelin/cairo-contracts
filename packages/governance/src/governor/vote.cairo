// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.19.0 (governance/governor/vote.cairo)

use core::hash::{HashStateTrait, HashStateExTrait};
use core::poseidon::PoseidonTrait;
use crate::utils::HashSpanImpl;
use openzeppelin_utils::cryptography::snip12::StructHash;
use starknet::ContractAddress;

// sn_keccak(
//      "\"Vote\"(\"verifying_contract\":\"ContractAddress\",
//      \"nonce\":\"felt\",
//      \"proposal_id\":\"felt\",
//      \"support\":\"u8\",
//      \"voter\":\"ContractAddress\")"
// )
//
// Since there's no u8 type in SNIP-12, we use u128 for `support` in the type hash generation.
pub const VOTE_TYPE_HASH: felt252 =
    0x21d38a715b9e9f6da132e4d01c8e4bd956340b0407942182043d516d8e27f3f;

#[derive(Copy, Drop, Hash)]
pub struct Vote {
    pub verifying_contract: ContractAddress,
    pub nonce: felt252,
    pub proposal_id: felt252,
    pub support: u8,
    pub voter: ContractAddress,
}

impl VoteStructHashImpl of StructHash<Vote> {
    fn hash_struct(self: @Vote) -> felt252 {
        let hash_state = PoseidonTrait::new();
        hash_state.update_with(VOTE_TYPE_HASH).update_with(*self).finalize()
    }
}

// sn_keccak(
//      "\"Vote\"(\"verifying_contract\":\"ContractAddress\",
//      \"nonce\":\"felt\",
//      \"proposal_id\":\"felt\",
//      \"support\":\"u8\",
//      \"voter\":\"ContractAddress\",
//      \"reason_hash\":\"felt\",
//      \"params\":\"felt*\")"
// )
//
// Since there's no u8 type in SNIP-12, we use u128 for `support` in the type hash generation.
pub const VOTE_WITH_REASON_AND_PARAMS_TYPE_HASH: felt252 =
    0x3866b6236bd1166c5b7eeda1b8e6d1d8f3cd5b82bccd3dac6f8d476d4848dd4;

#[derive(Copy, Drop, Hash)]
pub struct VoteWithReasonAndParams {
    pub verifying_contract: ContractAddress,
    pub nonce: felt252,
    pub proposal_id: felt252,
    pub support: u8,
    pub voter: ContractAddress,
    pub reason_hash: felt252,
    pub params: Span<felt252>,
}

impl VoteWithReasonAndParamsStructHashImpl of StructHash<VoteWithReasonAndParams> {
    fn hash_struct(self: @VoteWithReasonAndParams) -> felt252 {
        let hash_state = PoseidonTrait::new();
        hash_state.update_with(VOTE_WITH_REASON_AND_PARAMS_TYPE_HASH).update_with(*self).finalize()
    }
}

#[cfg(test)]
mod tests {
    use super::{VOTE_TYPE_HASH, VOTE_WITH_REASON_AND_PARAMS_TYPE_HASH};

    #[test]
    fn test_vote_type_hash() {
        let expected = selector!(
            "\"Vote\"(\"verifying_contract\":\"ContractAddress\",\"nonce\":\"felt\",\"proposal_id\":\"felt\",\"support\":\"u8\",\"voter\":\"ContractAddress\")"
        );
        assert_eq!(VOTE_TYPE_HASH, expected);
    }

    #[test]
    fn test_vote_with_reason_and_params_type_hash() {
        let expected = selector!(
            "\"Vote\"(\"verifying_contract\":\"ContractAddress\",\"nonce\":\"felt\",\"proposal_id\":\"felt\",\"support\":\"u8\",\"voter\":\"ContractAddress\",\"reason_hash\":\"felt\",\"params\":\"felt*\")"
        );
        assert_eq!(VOTE_WITH_REASON_AND_PARAMS_TYPE_HASH, expected);
    }
}
