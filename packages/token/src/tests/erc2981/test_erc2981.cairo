use openzeppelin_introspection::interface::ISRC5Dispatcher;
use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin_testing::constants::{OTHER, ZERO, RECIPIENT};
use openzeppelin_token::common::erc2981::ERC2981Component::{ERC2981Impl, InternalImpl};
use openzeppelin_token::common::erc2981::interface::IERC2981_ID;
use openzeppelin_token::common::erc2981::{ERC2981Component, DefaultConfig};
use openzeppelin_token::tests::mocks::erc2981_mocks::ERC2981Mock;
use starknet::{ContractAddress, contract_address_const};

type ComponentState = ERC2981Component::ComponentState<ERC2981Mock::ContractState>;

fn CONTRACT_STATE() -> ERC2981Mock::ContractState {
    ERC2981Mock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    ERC2981Component::component_state_for_testing()
}

fn DEFAULT_RECEIVER() -> ContractAddress {
    contract_address_const::<'DEFAULT_RECEIVER'>()
}

// 0.5% (default denominator is 10000)
const DEFAULT_FEE_NUMERATOR: u128 = 50;
// 5% (default denominator is 10000)
const FEE_NUMERATOR: u128 = 500;

fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    state.initializer(DEFAULT_RECEIVER(), DEFAULT_FEE_NUMERATOR);
    state
}

//
// Initializer
//

#[test]
fn test_initializer() {
    let mut state = COMPONENT_STATE();
    let mock_state = CONTRACT_STATE();

    state.initializer(DEFAULT_RECEIVER(), DEFAULT_FEE_NUMERATOR);

    let (receiver, numerator, denominator) = state.default_royalty();

    assert_eq!(receiver, DEFAULT_RECEIVER());
    assert_eq!(numerator, DEFAULT_FEE_NUMERATOR);
    assert_eq!(denominator, ERC2981Component::DEFAULT_FEE_DENOMINATOR);

    let supports_ierc2981 = mock_state.supports_interface(IERC2981_ID);
    assert!(supports_ierc2981);
}

//
// Getters
//

#[test]
fn test_royalty_info_default_royalty() {
    let mut state = setup();
    let token_id = 12;
    let sale_price = 1_000_000;

    let (receiver, amount) = state.royalty_info(token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER());
    assert_eq!(amount, 5000);
}

#[test]
fn test_royalty_info_token_royalty_set() {
    let mut state = setup();
    let token_id = 12;
    let sale_price = 1_000_000;

    let (receiver, amount) = state.royalty_info(token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER());
    assert_eq!(amount, 5000);

    state.set_token_royalty(token_id, RECIPIENT(), FEE_NUMERATOR);

    let (receiver, amount) = state.royalty_info(token_id, sale_price);
    assert_eq!(receiver, RECIPIENT());
    assert_eq!(amount, 50000);
}

//
// Internals
//

#[test]
fn test_default_royalty() {
    let mut state = setup();

    let (receiver, numerator, denominator) = state.default_royalty();

    assert_eq!(receiver, DEFAULT_RECEIVER());
    assert_eq!(numerator, DEFAULT_FEE_NUMERATOR);
    assert_eq!(denominator, ERC2981Component::DEFAULT_FEE_DENOMINATOR);
}

#[test]
fn test_set_default_royalty() {
    let mut state = setup();
    let token_id = 12;
    let sale_price = 1_000_000;

    let (receiver, amount) = state.royalty_info(token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER());
    assert_eq!(amount, 5000);

    state.set_default_royalty(RECIPIENT(), FEE_NUMERATOR);

    let (receiver, amount) = state.royalty_info(token_id, sale_price);
    assert_eq!(receiver, RECIPIENT());
    assert_eq!(amount, 50000);
}

#[test]
fn test_set_default_royalty_with_zero_royalty_fraction() {
    let mut state = setup();
    let token_id = 12;
    let sale_price = 1_000_000;

    state.set_default_royalty(DEFAULT_RECEIVER(), 0);
    let (receiver, amount) = state.royalty_info(token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER());
    assert_eq!(amount, 0);
}

#[test]
#[should_panic(expected: ('ERC2981: invalid receiver',))]
fn test_set_default_royalty_with_zero_receiver() {
    let mut state = setup();

    state.set_default_royalty(ZERO(), FEE_NUMERATOR);
}

#[test]
#[should_panic(expected: ('ERC2981: invalid royalty',))]
fn test_set_default_royalty_with_invalid_fee_numerator() {
    let mut state = setup();
    let fee_denominator = ERC2981Component::DEFAULT_FEE_DENOMINATOR;

    state.set_default_royalty(DEFAULT_RECEIVER(), fee_denominator + 1);
}

#[test]
fn test_set_token_royalty() {
    let mut state = setup();
    let token_id = 12;
    let another_token_id = 13;
    let sale_price = 1_000_000;

    let (receiver, amount) = state.royalty_info(token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER());
    assert_eq!(amount, 5000);

    let (receiver, amount) = state.royalty_info(another_token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER());
    assert_eq!(amount, 5000);

    state.set_token_royalty(token_id, RECIPIENT(), FEE_NUMERATOR);

    let (receiver, amount) = state.royalty_info(token_id, sale_price);
    assert_eq!(receiver, RECIPIENT());
    assert_eq!(amount, 50000);

    let (receiver, amount) = state.royalty_info(another_token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER());
    assert_eq!(amount, 5000);
}

#[test]
fn test_set_token_royalty_with_zero_royalty_fraction() {
    let mut state = setup();
    let token_id = 12;
    let sale_price = 1_000_000;

    state.set_token_royalty(token_id, RECIPIENT(), 0);
    let (receiver, amount) = state.royalty_info(token_id, sale_price);
    assert_eq!(receiver, RECIPIENT());
    assert_eq!(amount, 0);
}

#[test]
#[should_panic(expected: ('ERC2981: invalid receiver',))]
fn test_set_token_royalty_with_zero_receiver() {
    let mut state = setup();
    let token_id = 12;
    state.set_token_royalty(token_id, ZERO(), FEE_NUMERATOR);
}

#[test]
#[should_panic(expected: ('ERC2981: invalid royalty',))]
fn test_set_token_royalty_with_invalid_fee_numerator() {
    let mut state = setup();
    let token_id = 12;
    let fee_denominator = ERC2981Component::DEFAULT_FEE_DENOMINATOR;

    state.set_token_royalty(token_id, RECIPIENT(), fee_denominator + 1);
}

#[test]
fn test_reset_token_royalty() {
    let mut state = setup();
    let token_id = 12;
    let sale_price = 1_000_000;

    let (receiver, amount) = state.royalty_info(token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER());
    assert_eq!(amount, 5000);

    state.set_token_royalty(token_id, RECIPIENT(), FEE_NUMERATOR);

    let (receiver, amount) = state.royalty_info(token_id, sale_price);
    assert_eq!(receiver, RECIPIENT());
    assert_eq!(amount, 50000);

    state.reset_token_royalty(token_id);

    let (receiver, amount) = state.royalty_info(token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER());
    assert_eq!(amount, 5000);
}

#[test]
fn test_default_config() {
    let fee_denominator = DefaultConfig::FEE_DENOMINATOR;
    assert_eq!(fee_denominator, ERC2981Component::DEFAULT_FEE_DENOMINATOR);
    assert_eq!(fee_denominator, 10_000);
}
