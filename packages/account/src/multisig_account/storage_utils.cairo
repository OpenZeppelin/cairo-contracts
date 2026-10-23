// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.1
// (account/src/multisig_account/storage_utils.cairo)

use core::integer::u128_safe_divmod;
use starknet::storage_access::StorePacking;

/// Stores a multisig account's quorum and signer count in one storage slot.
#[derive(Drop)]
pub struct SignersInfo {
    pub quorum: u32,
    pub signers_count: u32,
}

const TWO_POW_32: NonZero<u128> = 0x100000000;

/// Packs `SignersInfo` into a `u128` value.
///
/// The signer count occupies bits 0 through 31 and the quorum occupies bits 32 through 63.
pub impl SignersInfoStorePacking of StorePacking<SignersInfo, u128> {
    fn pack(value: SignersInfo) -> u128 {
        let SignersInfo { quorum, signers_count } = value;
        quorum.into() * TWO_POW_32.into() + signers_count.into()
    }

    fn unpack(value: u128) -> SignersInfo {
        let (quorum, signers_count) = u128_safe_divmod(value, TWO_POW_32);
        SignersInfo {
            quorum: quorum.try_into().unwrap(), signers_count: signers_count.try_into().unwrap(),
        }
    }
}

#[cfg(test)]
#[cfg(feature: 'fuzzing')]
mod tests {
    use starknet::storage_access::StorePacking;
    use super::SignersInfo;

    #[test]
    #[fuzzer]
    fn test_pack_unpack_signers_info(quorum: u32, signers_count: u32) {
        let packed_value = StorePacking::pack(SignersInfo { quorum, signers_count });
        let unpacked_info: SignersInfo = StorePacking::unpack(packed_value);

        assert_eq!(unpacked_info.quorum, quorum);
        assert_eq!(unpacked_info.signers_count, signers_count);
    }
}
