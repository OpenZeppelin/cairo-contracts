use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin::introspection::src5;
use openzeppelin::introspection;
use openzeppelin::tests::mocks::erc721_enumerable_mocks::DualCaseERC721EnumerableMock;
use openzeppelin::tests::utils::constants::{
    DATA, ZERO, OWNER, RECIPIENT, SPENDER, OPERATOR, OTHER, NAME, SYMBOL, TOKEN_ID, PUBKEY,
    BASE_URI, BASE_URI_2
};
use openzeppelin::token::erc721::ERC721Component::{ERC721Impl, InternalImpl as ERC721InternalImpl};
use openzeppelin::token::erc721::extensions::erc721_enumerable::ERC721EnumerableComponent::{
    ERC721EnumerableImpl, ERC721EnumerableCamelImpl, InternalImpl
};
use openzeppelin::token::erc721::extensions::erc721_enumerable::ERC721EnumerableComponent;
use openzeppelin::token::erc721::extensions::erc721_enumerable::interface;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::storage::StorageMapMemberAccessTrait;
use starknet::testing;

// Token IDs
const TOKEN_1: u256 = 1;
const TOKEN_2: u256 = 2;
const TOKEN_3: u256 = 3;
const NONEXISTENT: u256 = 9898;

const TOKENS_LEN: u256 = 3;

//
// Setup
//

type ComponentState =
    ERC721EnumerableComponent::ComponentState<DualCaseERC721EnumerableMock::ContractState>;

fn CONTRACT_STATE() -> DualCaseERC721EnumerableMock::ContractState {
    DualCaseERC721EnumerableMock::contract_state_for_testing()
}

fn COMPONENT_STATE() -> ComponentState {
    ERC721EnumerableComponent::component_state_for_testing()
}

fn setup() -> ComponentState {
    let mut state = COMPONENT_STATE();
    let mut mock_state = CONTRACT_STATE();
    state.initializer();

    let mut tokens = array![TOKEN_1, TOKEN_2, TOKEN_3];
    loop {
        if tokens.len() == 0 {
            break;
        };
        let token = tokens.pop_front().unwrap();
        mock_state.erc721._mint(OWNER(), token);
    };

    state
}

//
// Initializers
//

#[test]
fn test_initialize() {
    let mut state = COMPONENT_STATE();
    let mock_state = CONTRACT_STATE();

    state.initializer();

    let supports_ierc721_enum = mock_state.supports_interface(interface::IERC721ENUMERABLE_ID);
    assert!(supports_ierc721_enum);

    let supports_isrc5 = mock_state.supports_interface(introspection::interface::ISRC5_ID);
    assert!(supports_isrc5);
}

//
// total_supply
//

#[test]
fn test_total_supply() {
    let mut state = setup();

    let supply = state.total_supply();
    assert_eq!(supply, TOKENS_LEN);
}

#[test]
fn test_totalSupply() {
    let mut state = setup();

    let supply = state.totalSupply();
    assert_eq!(supply, TOKENS_LEN);
}
