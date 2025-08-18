use openzeppelin_test_common::mocks::governor::GovernorMock::SNIP12MetadataImpl;
use openzeppelin_testing::constants::{OTHER, VOTES_TOKEN, ZERO};
use snforge_std::{start_cheat_block_timestamp_global, start_mock_call};
use starknet::ContractAddress;
use crate::governor::DefaultConfig;
use crate::governor::GovernorComponent::InternalImpl;
use crate::governor::extensions::GovernorVotesComponent::{
    GovernorVotes, InternalTrait, VotesTokenImpl,
};
use crate::tests::governor::timestamp::common::{
    COMPONENT_STATE, CONTRACT_STATE, deploy_legacy_votes_token, deploy_votes_token,
};

//
// GovernorVotes
//

#[test]
fn test_clock() {
    let component_state = COMPONENT_STATE();
    deploy_votes_token();
    initialize_component(VOTES_TOKEN);
    let timestamp = 'ts0';

    start_cheat_block_timestamp_global(timestamp);
    let clock = GovernorVotes::clock(@component_state);
    assert_eq!(clock, timestamp);
}

#[test]
fn test_CLOCK_MODE() {
    let component_state = COMPONENT_STATE();
    deploy_votes_token();
    initialize_component(VOTES_TOKEN);

    let mode = GovernorVotes::CLOCK_MODE(@component_state);
    assert_eq!(mode, "mode=timestamp&from=starknet::SN_MAIN");
}

#[test]
fn test_clock_legacy_token() {
    let component_state = COMPONENT_STATE();
    deploy_legacy_votes_token();
    initialize_component(VOTES_TOKEN);
    let timestamp = 'ts0';

    start_cheat_block_timestamp_global(timestamp);
    let clock = GovernorVotes::clock(@component_state);
    assert_eq!(clock, timestamp);
}

#[test]
fn test_CLOCK_MODE_legacy_token() {
    let component_state = COMPONENT_STATE();
    deploy_legacy_votes_token();
    initialize_component(VOTES_TOKEN);

    let mode = GovernorVotes::CLOCK_MODE(@component_state);
    assert_eq!(mode, "mode=timestamp&from=starknet::SN_MAIN");
}

#[test]
fn test_get_votes() {
    let component_state = COMPONENT_STATE();
    deploy_votes_token();
    initialize_component(VOTES_TOKEN);

    let past_timepoint = 'ts0';
    let now_timepoint = 'ts1';
    let expected_weight = 100;
    let params = array!['param'].span();

    start_cheat_block_timestamp_global(now_timepoint);
    start_mock_call(VOTES_TOKEN, selector!("get_past_votes"), expected_weight);

    let votes = GovernorVotes::get_votes(@component_state, OTHER, past_timepoint, params);
    assert_eq!(votes, expected_weight);
}

//
// External
//

#[test]
fn test_token() {
    let mock_state = CONTRACT_STATE();
    deploy_votes_token();
    initialize_component(VOTES_TOKEN);

    let token = mock_state.governor_votes.token();
    assert_eq!(token, VOTES_TOKEN);
}

//
// Internal
//

#[test]
fn test_initializer() {
    let mock_state = CONTRACT_STATE();

    initialize_component(VOTES_TOKEN);

    let token = mock_state.governor_votes.token();
    assert_eq!(token, VOTES_TOKEN);
}

#[test]
#[should_panic(expected: 'Invalid votes token')]
fn test_initializer_with_zero_token() {
    initialize_component(ZERO);
}

//
// Helpers
//

fn initialize_component(votes_token: ContractAddress) {
    let mut mock_state = CONTRACT_STATE();
    mock_state.governor_votes.initializer(votes_token);
}
