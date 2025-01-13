use crate::governor::ProposalCore;
use crate::multisig::storage_utils::TxInfo;
use starknet::storage_access::StorePacking;

#[test]
fn test_pack_unpack_tx_info(is_executed_val: u8, submitted_block: u64) {
    let is_executed = is_executed_val % 2 == 0;
    let packed_value = StorePacking::pack(TxInfo { is_executed, submitted_block });
    let unpacked_tx_info: TxInfo = StorePacking::unpack(packed_value);

    assert_eq!(unpacked_tx_info.is_executed, is_executed);
    assert_eq!(unpacked_tx_info.submitted_block, submitted_block);
}

#[test]
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
