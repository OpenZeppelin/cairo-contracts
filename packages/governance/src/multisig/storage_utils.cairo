// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.20.0-rc.0 (governance/multisig/storage_utils.cairo)

use core::integer::u128_safe_divmod;
use starknet::storage_access::StorePacking;

const _2_POW_32: NonZero<u128> = 0xffffffff;

/// Helper struct for `MultisigComponent` that optimizes how transaction-related information
/// is stored, including the transaction's execution status and the block it was submitted in.
#[derive(Drop)]
pub struct TxInfo {
    pub is_executed: bool,
    pub submitted_block: u64,
}

/// Packs a `TxInfo` entity into a `u128` value.
///
/// The packing is done as follows:
/// - The boolean `is_executed` is stored as a single bit at the highest bit position (index 127).
/// - The `submitted_block` value occupies 64 bits in the range [63..126].
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

/// Helper struct for `MultisigComponent` that optimizes how the quorum
/// value and the total number of signers are stored.
#[derive(Drop)]
pub struct SignersInfo {
    pub quorum: u32,
    pub signers_count: u32,
}

/// Packs a `SignersInfo` entity into a `u128` value.
///
/// The packing is done as follows:
/// - `quorum` value occupies 32 bits in bit range [64..95].
/// - `signers_count` value occupies the highest 32 bits in bit range [96..127].
pub impl SignersInfoStorePacking of StorePacking<SignersInfo, u128> {
    fn pack(value: SignersInfo) -> u128 {
        let SignersInfo { quorum, signers_count } = value;
        quorum.into() * _2_POW_32.into() + signers_count.into()
    }

    fn unpack(value: u128) -> SignersInfo {
        let (quorum, signers_count) = u128_safe_divmod(value, _2_POW_32);
        SignersInfo {
            quorum: quorum.try_into().unwrap(), signers_count: signers_count.try_into().unwrap(),
        }
    }
}
