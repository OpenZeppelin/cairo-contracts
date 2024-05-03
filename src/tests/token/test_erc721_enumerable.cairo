use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin::introspection::src5;
use openzeppelin::introspection;
use openzeppelin::tests::mocks::erc721_enumerable_mocks::DualCaseERC721EnumerableMock;
use openzeppelin::tests::utils::constants::{OWNER, RECIPIENT, OTHER};
use openzeppelin::token::erc721::ERC721Component::{ERC721Impl, InternalImpl as ERC721InternalImpl};
use openzeppelin::token::erc721::extensions::erc721_enumerable::ERC721EnumerableComponent::{
    ERC721EnumerableImpl, ERC721EnumerableCamelImpl, InternalImpl
};
use openzeppelin::token::erc721::extensions::erc721_enumerable::ERC721EnumerableComponent;
use openzeppelin::token::erc721::extensions::erc721_enumerable::interface;
use starknet::ContractAddress;
use starknet::storage::{StorageMapMemberAccessTrait, StorageMemberAccessTrait};
use starknet::testing;

// Token IDs
const TOKEN_1: u256 = 111;
const TOKEN_2: u256 = 222;
const TOKEN_3: u256 = 333;

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
// Initializer
//

#[test]
fn test_initializer() {
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
    let state = setup();

    let supply = state.totalSupply();
    assert_eq!(supply, TOKENS_LEN);
}

//
// token_of_owner_by_index
//

#[test]
fn test_token_of_owner_by_index() {
    let state = setup();
    let tokens_list = array![TOKEN_1, TOKEN_2, TOKEN_3];

    assert_token_of_owner_by_index(state, OWNER(), tokens_list);
}

#[test]
#[should_panic(expected: ('ERC721Enum: out of bounds index',))]
fn test_token_of_owner_by_index_when_index_equals_owned_tokens() {
    let state = setup();

    state.token_of_owner_by_index(OWNER(), TOKENS_LEN);
}

#[test]
#[should_panic(expected: ('ERC721Enum: out of bounds index',))]
fn test_token_of_owner_by_index_when_index_exceeds_owned_tokens() {
    let state = setup();

    state.token_of_owner_by_index(OWNER(), TOKENS_LEN + 1);
}

#[test]
#[should_panic(expected: ('ERC721Enum: out of bounds index',))]
fn test_token_of_owner_by_index_when_target_has_no_tokens() {
    let state = setup();

    state.token_of_owner_by_index(OTHER(), 0);
}

#[test]
fn test_token_of_owner_by_index_when_all_tokens_transferred() {
    let state = setup();
    let mut contract_state = CONTRACT_STATE();
    let tokens_list = array![TOKEN_1, TOKEN_2, TOKEN_3];

    testing::set_caller_address(OWNER());

    contract_state.transfer_from(OWNER(), RECIPIENT(), TOKEN_1);
    contract_state.transfer_from(OWNER(), RECIPIENT(), TOKEN_2);
    contract_state.transfer_from(OWNER(), RECIPIENT(), TOKEN_3);

    assert_token_of_owner_by_index(state, RECIPIENT(), tokens_list);
}

//
// token_by_index
//

#[test]
fn test_token_by_index() {
    let state = setup();
    let token_list = array![TOKEN_1, TOKEN_2, TOKEN_3];

    assert_token_by_index(state, token_list);
}

#[test]
#[should_panic(expected: ('ERC721Enum: out of bounds index',))]
fn test_token_by_index_equal_to_supply() {
    let state = setup();

    state.token_by_index(TOKENS_LEN);
}

#[test]
#[should_panic(expected: ('ERC721Enum: out of bounds index',))]
fn test_token_by_index_greater_than_supply() {
    let state = setup();

    state.token_by_index(TOKENS_LEN + 1);
}

#[test]
fn test_token_by_index_burn_last_token() {
    let state = setup();
    let mut contract_state = CONTRACT_STATE();
    let last_token = TOKEN_3;

    contract_state.erc721._burn(last_token);

    let expected_list = array![TOKEN_1, TOKEN_2];
    assert_token_by_index(state, expected_list);
}

#[test]
fn test_token_by_index_burn_first_token() {
    let state = setup();
    let mut contract_state = CONTRACT_STATE();
    let first_token = TOKEN_1;

    contract_state.erc721._burn(first_token);

    // Burnt tokens are replaced by the last token
    // to prevent indexing gaps
    let expected_list = array![TOKEN_3, TOKEN_2];
    assert_token_by_index(state, expected_list);
}

#[test]
fn test_token_by_index_burn_and_mint_all() {
    let state = setup();
    let mut contract_state = CONTRACT_STATE();

    contract_state.erc721._burn(TOKEN_2);
    contract_state.erc721._burn(TOKEN_3);
    contract_state.erc721._burn(TOKEN_1);

    let supply = state.total_supply();
    assert_eq!(supply, 0);

    contract_state.erc721._mint(OWNER(), TOKEN_1);
    contract_state.erc721._mint(OWNER(), TOKEN_2);
    contract_state.erc721._mint(OWNER(), TOKEN_3);

    let expected_list = array![TOKEN_1, TOKEN_2, TOKEN_3];
    assert_token_by_index(state, expected_list);
}

//
// Helpers
//

fn assert_token_of_owner_by_index(
    state: ComponentState, owner: ContractAddress, expected_token_list: Array<u256>
) {
    let mut i = 0;
    loop {
        if i == expected_token_list.len() {
            break;
        };
        let token = state.token_of_owner_by_index(owner, i.into());
        assert_eq!(token, *expected_token_list.at(i));
        i = i + 1;
    };
}

fn assert_token_by_index(
    state: ComponentState, expected_token_list: Array<u256>
) {
    let mut i = 0;
    loop {
        if i == expected_token_list.len() {
            break;
        };
        let token = state.token_by_index(i.into());
        assert_eq!(token, *expected_token_list.at(i));
        i = i + 1;
    };
}
