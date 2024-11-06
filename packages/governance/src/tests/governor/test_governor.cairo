use core::hash::{HashStateTrait, HashStateExTrait};
use core::pedersen::PedersenTrait;
use crate::governor::GovernorComponent::InternalImpl;
use crate::governor::interface::IGOVERNOR_ID;
use crate::governor::{GovernorComponent, ProposalCore};
use crate::timelock::utils::call_impls::{HashCallImpl, HashCallsImpl};
use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin_test_common::mocks::governor::GovernorMock;
use openzeppelin_testing::constants::{ADMIN, ZERO};
use openzeppelin_token::erc1155::interface::IERC1155_RECEIVER_ID;
use openzeppelin_token::erc721::interface::IERC721_RECEIVER_ID;
use openzeppelin_utils::bytearray::ByteArrayExtTrait;
use starknet::ContractAddress;
use starknet::account::Call;
use starknet::storage::StorageMapWriteAccess;

type ComponentState = GovernorComponent::ComponentState<GovernorMock::ContractState>;

fn CONTRACT_STATE() -> GovernorMock::ContractState {
    GovernorMock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    GovernorComponent::component_state_for_testing()
}

//
// Internal
//

#[test]
fn test_initializer() {
    let mut state = COMPONENT_STATE();
    let contract_state = CONTRACT_STATE();

    state.initializer();

    assert!(contract_state.supports_interface(IGOVERNOR_ID));
    assert!(contract_state.supports_interface(IERC721_RECEIVER_ID));
    assert!(contract_state.supports_interface(IERC1155_RECEIVER_ID));
}

//
// get_proposal
//

#[test]
fn test_get_empty_proposal() {
    let mut state = COMPONENT_STATE();

    let proposal = state.get_proposal(0);

    assert_eq!(proposal.proposer, ZERO());
    assert_eq!(proposal.vote_start, 0);
    assert_eq!(proposal.vote_duration, 0);
    assert_eq!(proposal.executed, false);
    assert_eq!(proposal.canceled, false);
    assert_eq!(proposal.eta_seconds, 0);
}

#[test]
fn test_get_proposal() {
    let mut state = COMPONENT_STATE();
    let (_, expected_proposal) = get_proposal_info();

    state.Governor_proposals.write(1, expected_proposal);

    let proposal = state.get_proposal(1);
    assert_eq!(proposal, expected_proposal);
}

//
// is_valid_description_for_proposer
//

#[test]
fn test_is_valid_description_too_short() {
    let state = COMPONENT_STATE();
    let short_description: ByteArray = "fffffffffffffffffffffffffffffffffffffffffffffffffff";
    assert_eq!(short_description.len(), 51);

    let is_valid = state.is_valid_description_for_proposer(ADMIN(), @short_description);
    assert!(is_valid);
}

#[test]
fn test_is_valid_description_wrong_suffix() {
    let state = COMPONENT_STATE();
    let description = "?proposer=0x4718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d";

    let is_valid = state.is_valid_description_for_proposer(ADMIN(), @description);
    assert!(is_valid);
}

#[test]
fn test_is_valid_description_wrong_proposer() {
    let state = COMPONENT_STATE();
    let description = "#proposer=0x4718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d";

    let is_valid = state.is_valid_description_for_proposer(ADMIN(), @description);
    assert!(!is_valid);
}

#[test]
fn test_is_valid_description_valid_proposer() {
    let state = COMPONENT_STATE();
    let address = ADMIN().to_byte_array(16, 64);
    let mut description: ByteArray = "#proposer=0x";

    description.append(@address);

    let is_valid = state.is_valid_description_for_proposer(ADMIN(), @description);
    assert!(is_valid);
}

//
// _hash_proposal
//

#[test]
fn test__hash_proposal() {
    let state = COMPONENT_STATE();
    let calls = get_calls(ZERO());
    let description = @"proposal description";
    let description_hash = description.hash();

    let expected_hash = hash_proposal(calls, description_hash);
    let hash = state._hash_proposal(calls, description_hash);

    assert_eq!(hash, expected_hash);
}

//
// Helpers
//

fn get_proposal_info() -> (felt252, ProposalCore) {
    get_proposal_with_id(array![].span(), @"")
}

fn get_proposal_with_id(calls: Span<Call>, description: @ByteArray) -> (felt252, ProposalCore) {
    let timestamp = starknet::get_block_timestamp();
    let vote_start = timestamp + GovernorMock::VOTING_DELAY;
    let vote_duration = GovernorMock::VOTING_PERIOD;

    let proposal_id = hash_proposal(calls, description.hash());
    let proposal = ProposalCore {
        proposer: ADMIN(),
        vote_start,
        vote_duration,
        executed: false,
        canceled: false,
        eta_seconds: 0
    };

    (proposal_id, proposal)
}

fn hash_proposal(calls: Span<Call>, description_hash: felt252) -> felt252 {
    PedersenTrait::new(0).update_with(calls).update_with(description_hash).finalize()
}

fn get_calls(to: ContractAddress) -> Span<Call> {
    let call1 = Call { to, selector: selector!(""), calldata: array![].span() };
    let call2 = Call { to, selector: selector!(""), calldata: array![].span() };

    array![call1, call2].span()
}
