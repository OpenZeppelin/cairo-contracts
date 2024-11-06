// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.18.0 (governance/multisig/storage_utils.cairo)

use core::integer::u128_safe_divmod;
use starknet::storage_access::StorePacking;

const _2_POW_32: NonZero<u128> = 0xffffffff;

#[derive(Drop)]
pub struct TxInfo {
    pub is_executed: bool,
    pub submitted_block: u64
}

pub impl TxInfoStorePacking of StorePacking<TxInfo, u128> {
    fn pack(value: TxInfo) -> u128 {
        let TxInfo { is_executed, submitted_block } = value;
        let is_executed_value = if is_executed {
            1
        } else {
            0
        };
        submitted_block.into() * 2 + is_executed_value
    }

    fn unpack(value: u128) -> TxInfo {
        let (submitted_block, is_executed_value) = u128_safe_divmod(value, 2);
        let is_executed = is_executed_value == 1;
        TxInfo { is_executed, submitted_block: submitted_block.try_into().unwrap() }
    }
}

#[derive(Drop)]
pub struct SignersInfo {
    pub quorum: u32,
    pub signers_count: u32
}

pub impl SignersInfoStorePacking of StorePacking<SignersInfo, u128> {
    fn pack(value: SignersInfo) -> u128 {
        let SignersInfo { quorum, signers_count } = value;
        quorum.into() * _2_POW_32.into() + signers_count.into()
    }

    fn unpack(value: u128) -> SignersInfo {
        let (quorum, signers_count) = u128_safe_divmod(value, _2_POW_32);
        SignersInfo {
            quorum: quorum.try_into().unwrap(), signers_count: signers_count.try_into().unwrap()
        }
    }
}
