use core::integer::u128_safe_divmod;
use core::num::traits::Bounded;
use starknet::storage_access::StorePacking;
use crate::governor::ProposalCore;
use crate::multisig::storage_utils::{SignersInfo, SignersInfoStorePackingV2, TxInfo};

#[test]
#[fuzzer]
fn test_pack_unpack_tx_info(is_executed_val: u8, submitted_block: u64) {
    let is_executed = is_executed_val % 2 == 0;
    let packed_value = StorePacking::pack(TxInfo { is_executed, submitted_block });
    let unpacked_tx_info: TxInfo = StorePacking::unpack(packed_value);

    assert_eq!(unpacked_tx_info.is_executed, is_executed);
    assert_eq!(unpacked_tx_info.submitted_block, submitted_block);
}

#[test]
#[fuzzer]
fn test_pack_unpack_proposal_core(
    proposer_val: felt252,
    vote_start: u64,
    vote_duration: u64,
    executed_val: u8,
    canceled_val: u8,
    eta_seconds: u64,
) {
    let proposer = match proposer_val.try_into() {
        Option::Some(proposer) => proposer,
        Option::None => { return; },
    };
    let executed = executed_val % 2 == 0;
    let canceled = canceled_val % 2 == 0;
    let initial_proposal_core = ProposalCore {
        proposer, vote_start, vote_duration, executed, canceled, eta_seconds,
    };

    let packed_value = StorePacking::pack(initial_proposal_core);
    let unpacked_proposal_core: ProposalCore = StorePacking::unpack(packed_value);

    assert!(unpacked_proposal_core == initial_proposal_core);
}

#[test]
#[fuzzer]
fn test_pack_unpack_signers_info_v2(quorum: u32, signers_count: u32) {
    let info = SignersInfo { quorum, signers_count };
    let packed_value = SignersInfoStorePackingV2::pack(info);
    let unpacked_info = SignersInfoStorePackingV2::unpack(packed_value);

    assert_eq!(unpacked_info.quorum, quorum);
    assert_eq!(unpacked_info.signers_count, signers_count);
}

#[test]
#[fuzzer]
fn test_pack_signers_info_with_v1_unpack_with_v2(quorum: u32, signers_count: u32) {
    if signers_count == Bounded::MAX {
        // Cannot properly unpack if packed with V1 and `signers_count` is max u32 value
        return;
    }
    let info = SignersInfo { quorum, signers_count };
    let packed_value = LegacySignersInfoStorePackingV1::pack(info);
    let unpacked_info = SignersInfoStorePackingV2::unpack(packed_value);

    assert_eq!(unpacked_info.quorum, quorum);
    assert_eq!(unpacked_info.signers_count, signers_count);
}

//
// Helpers
//

const MAX_U32: NonZero<u128> = 0xffffffff;

impl LegacySignersInfoStorePackingV1 of StorePacking<SignersInfo, u128> {
    fn pack(value: SignersInfo) -> u128 {
        let SignersInfo { quorum, signers_count } = value;
        quorum.into() * MAX_U32.into() + signers_count.into()
    }

    fn unpack(value: u128) -> SignersInfo {
        let (quorum, signers_count) = u128_safe_divmod(value, MAX_U32);
        SignersInfo {
            quorum: quorum.try_into().unwrap(), signers_count: signers_count.try_into().unwrap(),
        }
    }
}
