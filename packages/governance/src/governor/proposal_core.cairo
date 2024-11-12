// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.19.0 (governance/governor/proposal_core.cairo)

use starknet::ContractAddress;
use starknet::storage_access::StorePacking;

#[derive(Copy, Drop, Serde, PartialEq, Debug)]
pub struct ProposalCore {
    pub proposer: ContractAddress,
    pub vote_start: u64,
    pub vote_duration: u64,
    pub executed: bool,
    pub canceled: bool,
    pub eta_seconds: u64
}

const _2_POW_184: felt252 = 0x10000000000000000000000000000000000000000000000;
const _2_POW_120: felt252 = 0x1000000000000000000000000000000;
const _2_POW_119: felt252 = 0x800000000000000000000000000000;
const _2_POW_118: felt252 = 0x400000000000000000000000000000;
const _2_POW_54: felt252 = 0x40000000000000;

const _64_BITS_MASK: u256 = 0xffffffffffffffff;
const _1_BIT_MASK: u256 = 0x1;

/// Packs a ProposalCore into a (felt252, felt252).
///
/// The packing is done as follows:
///
/// 1. The first felt of the tuple contains `proposer` serialized.
/// 2. The second felt of the tuple contains `vote_start`, `vote_duration`, `executed`, `canceled`
/// and `eta_seconds` organized as:
///   - `vote_start` is stored at range [4,67] bits (0-indexed), taking the most significant usable
/// bits.
///   - `vote_duration` is stored at range [68, 131], following `vote_start`.
///   - `executed` is stored at range [132, 132], following `vote_duration`.
///   - `canceled` is stored at range [133, 133], following `executed`.
///   - `eta_seconds` is stored at range [134, 197], following `canceled`.
///
/// NOTE: In the second felt252, the first four bits are skipped to avoid representation errors due
/// to `felt252` max value being a bit less than a 252 bits number max value
/// (https://docs.starknet.io/documentation/architecture_and_concepts/Cryptography/p-value/).
impl ProposalCoreStorePacking of StorePacking<ProposalCore, (felt252, felt252)> {
    fn pack(value: ProposalCore) -> (felt252, felt252) {
        let proposal = value;

        // shift-left to reach the corresponding positions
        let vote_start = proposal.vote_start.into() * _2_POW_184;
        let vote_duration = proposal.vote_duration.into() * _2_POW_120;
        let executed = proposal.executed.into() * _2_POW_119;
        let canceled = proposal.canceled.into() * _2_POW_118;
        let eta_seconds = proposal.eta_seconds.into() * _2_POW_54;

        let second_felt = vote_start + vote_duration + executed + canceled + eta_seconds;

        (proposal.proposer.into(), second_felt)
    }

    fn unpack(value: (felt252, felt252)) -> ProposalCore {
        let (proposer, second_felt) = value;
        let second_felt: u256 = second_felt.into();

        // shift-right and mask to extract the corresponding values
        let vote_start: u256 = (second_felt / _2_POW_184.into()) & _64_BITS_MASK;
        let vote_duration: u256 = (second_felt / _2_POW_120.into()) & _64_BITS_MASK;
        let executed: u256 = (second_felt / _2_POW_119.into()) & _1_BIT_MASK;
        let canceled: u256 = (second_felt / _2_POW_118.into()) & _1_BIT_MASK;
        let eta_seconds: u256 = (second_felt / _2_POW_54.into()) & _64_BITS_MASK;

        ProposalCore {
            proposer: proposer.try_into().unwrap(),
            vote_start: vote_start.try_into().unwrap(),
            vote_duration: vote_duration.try_into().unwrap(),
            executed: executed > 0,
            canceled: canceled > 0,
            eta_seconds: eta_seconds.try_into().unwrap()
        }
    }
}
