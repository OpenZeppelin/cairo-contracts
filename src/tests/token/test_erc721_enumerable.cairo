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

fn TOKENS_LIST() -> Array<u256> {
    array![TOKEN_1, TOKEN_2, TOKEN_3]
}

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

//
// token_of_owner_by_index
//

#[test]
fn test_token_of_owner_by_index_when_index_is_lt_owned_tokens() {
    let mut state = setup();

    let mut i = 0;
    loop {
        if i == TOKENS_LIST().len() {
            break;
        };
        let token = state.token_of_owner_by_index(OWNER(), i.into());
        assert_eq!(token, *TOKENS_LIST().at(i));
        i = i + 1;
    };
}

#[test]
#[should_panic(expected: ('ERC721Enum: out of bounds index',))]
fn test_token_of_owner_by_index_when_index_equals_owned_tokens() {
    let mut state = setup();

    state.token_of_owner_by_index(OWNER(), TOKENS_LEN);
}

#[test]
#[should_panic(expected: ('ERC721Enum: out of bounds index',))]
fn test_token_of_owner_by_index_when_index_exceeds_owned_tokens() {
    let mut state = setup();

    state.token_of_owner_by_index(OWNER(), TOKENS_LEN + 1);
}

#[test]
#[should_panic(expected: ('ERC721Enum: out of bounds index',))]
fn test_token_of_owner_by_index_when_target_has_no_tokens() {
    let mut state = setup();

    state.token_of_owner_by_index(OTHER(), 0);
}

#[test]
fn test_token_of_owner_by_index_when_all_tokens_transferred() {
    let mut state = setup();
    let mut contract_state = CONTRACT_STATE();
    testing::set_caller_address(OWNER());

    contract_state.transfer_from(OWNER(), RECIPIENT(), TOKEN_1);
    contract_state.transfer_from(OWNER(), RECIPIENT(), TOKEN_2);
    contract_state.transfer_from(OWNER(), RECIPIENT(), TOKEN_3);

    let mut token = state.token_of_owner_by_index(RECIPIENT(), 0);
    assert_eq!(token, TOKEN_1);

    token = state.token_of_owner_by_index(RECIPIENT(), 1);
    assert_eq!(token, TOKEN_2);

    token = state.token_of_owner_by_index(RECIPIENT(), 2);
    assert_eq!(token, TOKEN_3);
}

//
// token_by_index
//

#[test]
fn test_token_by_index() {
    let mut state = setup();

    let mut index = 0;
    loop {
        if index == TOKENS_LIST().len() {
            break;
        };

        let token = state.token_by_index(index.into());
        assert_eq!(token, *TOKENS_LIST().at(index));
        index = index + 1;
    };
}

#[test]
#[should_panic(expected: ('ERC721Enum: out of bounds index',))]
fn test_token_by_index_equal_to_supply() {
    let mut state = setup();

    state.token_by_index(TOKENS_LEN);
}
