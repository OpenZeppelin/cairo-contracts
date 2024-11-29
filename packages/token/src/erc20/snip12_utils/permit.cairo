// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.20.0-rc.0 (token/erc20/snip12_utils/permit.cairo)

use core::hash::{HashStateTrait, HashStateExTrait};
use core::poseidon::PoseidonTrait;
use openzeppelin_utils::cryptography::snip12::StructHash;
use starknet::ContractAddress;

#[derive(Copy, Drop, Hash)]
pub struct Permit {
    pub token: ContractAddress,
    pub spender: ContractAddress,
    pub amount: u256,
    pub nonce: felt252,
    pub deadline: u64,
}

// Since there's no u64 type in SNIP-12, the type used for `deadline` parameter is u128
// selector!(
//     "\"Permit\"(
//         \"token\":\"ContractAddress\",
//         \"spender\":\"ContractAddress\",
//         \"amount\":\"u256\",
//         \"nonce\":\"felt\",
//         \"deadline\":\"u128\"
//     )"
// );
pub const PERMIT_TYPE_HASH: felt252 =
    0x2a8eb238e7cde741a544afcc79fe945d4292b089875fd068633854927fd5a96;

impl StructHashImpl of StructHash<Permit> {
    fn hash_struct(self: @Permit) -> felt252 {
        PoseidonTrait::new().update_with(PERMIT_TYPE_HASH).update_with(*self).finalize()
    }
}
