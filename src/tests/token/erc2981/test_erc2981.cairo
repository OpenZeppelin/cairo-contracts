use openzeppelin::introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};

use openzeppelin::tests::mocks::erc2981_mocks::ERC2981Mock;
use openzeppelin::token::common::erc2981::ERC2981Component::{ERC2981Impl, InternalImpl};
use openzeppelin::token::common::erc2981::ERC2981Component;
use openzeppelin::token::common::erc2981::interface::IERC2981_ID;
use openzeppelin::token::common::erc2981::{IERC2981Dispatcher, IERC2981DispatcherTrait};

use starknet::{ContractAddress, contract_address_const};


type ComponentState = ERC2981Component::ComponentState<ERC2981Mock::ContractState>;

fn COMPONENT_STATE() -> ComponentState {
    ERC2981Component::component_state_for_testing()
}

fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

fn DEFAULT_RECEIVER() -> ContractAddress {
    contract_address_const::<'DEFAULT_RECEIVER'>()
}

fn RECEIVER() -> ContractAddress {
    contract_address_const::<'RECEIVER'>()
}

// 0.5% (default denominator is 10000)
fn DEFAULT_FEE_NUMERATOR() -> u256 {
    50
}

// 5% (default denominator is 10000)
fn FEE_NUMERATOR() -> u256 {
    500
}

fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    state.initializer(DEFAULT_RECEIVER(), DEFAULT_FEE_NUMERATOR());
    state
}


#[test]
fn test_default_royalty() {
    let mut state = setup();
    let token_id = 12;
    let sale_price = 1_000_000;
    let (receiver, amount) = state.royalty_info(token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER(), "Default receiver incorrect");
    assert_eq!(amount, 5000, "Default fees incorrect");

    state._set_default_royalty(RECEIVER(), FEE_NUMERATOR());

    let (receiver, amount) = state.royalty_info(token_id, sale_price);
    assert_eq!(receiver, RECEIVER(), "Default receiver incorrect");
    assert_eq!(amount, 50000, "Default fees incorrect");
}


#[test]
fn test_token_royalty_token() {
    let mut state = setup();
    let token_id = 12;
    let another_token_id = 13;
    let sale_price = 1_000_000;
    let (receiver, amount) = state.royalty_info(token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER(), "Default receiver incorrect");
    assert_eq!(amount, 5000, "Wrong royalty amount");
    let (receiver, amount) = state.royalty_info(another_token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER(), "Default receiver incorrect");
    assert_eq!(amount, 5000, "Wrong royalty amount");

    state._set_token_royalty(token_id, RECEIVER(), FEE_NUMERATOR());
    let (receiver, amount) = state.royalty_info(another_token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER(), "Default receiver incorrect");
    assert_eq!(amount, 5000, "Wrong royalty amount");
    let (receiver, amount) = state.royalty_info(token_id, sale_price);
    assert_eq!(receiver, RECEIVER(), "Default receiver incorrect");
    assert_eq!(amount, 50000, "Wrong royalty amount");

    state._reset_token_royalty(token_id);
    let (receiver, amount) = state.royalty_info(token_id, sale_price);
    assert_eq!(receiver, DEFAULT_RECEIVER(), "Default receiver incorrect");
    assert_eq!(amount, 5000, "Wrong royalty amount");
}

