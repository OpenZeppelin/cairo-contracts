use openzeppelin::token::erc721::extensions::erc721_enumerable::erc721_enumerable::ERC721EnumerableComponent::PrivateTrait;
use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin::introspection;
use openzeppelin::tests::mocks::erc721_enumerable_mocks::DualCaseERC721EnumerableMock;
use openzeppelin::tests::utils::constants::{OWNER, RECIPIENT, OTHER, ZERO};
use openzeppelin::token::erc721::ERC721Component::{ERC721Impl, InternalImpl as ERC721InternalImpl};
use openzeppelin::token::erc721::extensions::erc721_enumerable::ERC721EnumerableComponent::{
    ERC721EnumerableImpl, ERC721EnumerableCamelImpl, InternalImpl
};
use openzeppelin::token::erc721::extensions::erc721_enumerable::ERC721EnumerableComponent;
use openzeppelin::token::erc721::extensions::erc721_enumerable::interface;
use starknet::ContractAddress;
use starknet::storage::{StorageMemberAccessTrait, StorageMapMemberAccessTrait};

// Token IDs
const TOKEN_1: u256 = 'TOKEN_1';
const TOKEN_2: u256 = 'TOKEN_2';
const TOKEN_3: u256 = 'TOKEN_3';

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

fn setup() -> (ComponentState, Span<u256>) {
    let mut state = COMPONENT_STATE();
    let mut mock_state = CONTRACT_STATE();
    state.initializer();

    let tokens_list = array![TOKEN_1, TOKEN_2, TOKEN_3].span();
    let mut i = 0;

    loop {
        if i == tokens_list.len() {
            break;
        };

        let token = *tokens_list.at(i);
        mock_state.erc721._mint(OWNER(), token);
        i = i + 1;
    };

    (state, tokens_list)
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
    let mut state = COMPONENT_STATE();
    let mut contract_state = CONTRACT_STATE();
    let token = TOKEN_1;

    let no_supply = state.total_supply();
    assert_eq!(no_supply, 0);

    // Mint
    contract_state.erc721._mint(OWNER(), token);

    let new_supply = state.total_supply();
    assert_eq!(new_supply, 1);

    // Burn
    contract_state.erc721._burn(token);

    let no_supply = state.total_supply();
    assert_eq!(no_supply, 0);
}

#[test]
fn test_totalSupply() {
    let mut state = COMPONENT_STATE();
    let mut contract_state = CONTRACT_STATE();
    let token = TOKEN_1;

    let no_supply = state.totalSupply();
    assert_eq!(no_supply, 0);

    // Mint
    contract_state.erc721._mint(OWNER(), token);

    let new_supply = state.totalSupply();
    assert_eq!(new_supply, 1);

    // Burn
    contract_state.erc721._burn(token);

    let no_supply = state.totalSupply();
    assert_eq!(no_supply, 0);
}

//
// token_by_index & tokenByIndex
//

#[test]
fn test_token_by_index() {
    let (_, token_list) = setup();

    assert_dual_token_by_index(token_list);
}

#[test]
#[should_panic(expected: ('ERC721Enum: out of bounds index',))]
fn test_token_by_index_equal_to_supply() {
    let (state, token_list) = setup();
    let supply = token_list.len().into();

    state.token_by_index(supply);
}

#[test]
#[should_panic(expected: ('ERC721Enum: out of bounds index',))]
fn test_token_by_index_greater_than_supply() {
    let (state, token_list) = setup();
    let supply_plus_one = token_list.len().into() + 1;

    state.token_by_index(supply_plus_one);
}

#[test]
fn test_token_by_index_burn_last_token() {
    let (_, _) = setup();
    let mut contract_state = CONTRACT_STATE();
    let last_token = TOKEN_3;

    contract_state.erc721._burn(last_token);

    let expected_list = array![TOKEN_1, TOKEN_2];
    assert_dual_token_by_index(expected_list.span());
}

#[test]
fn test_token_by_index_burn_first_token() {
    let (_, _) = setup();
    let mut contract_state = CONTRACT_STATE();
    let first_token = TOKEN_1;

    contract_state.erc721._burn(first_token);

    // Burnt tokens are replaced by the last token
    // to prevent indexing gaps
    let expected_list = array![TOKEN_3, TOKEN_2];
    assert_dual_token_by_index(expected_list.span());
}

#[test]
fn test_token_by_index_burn_and_mint_all() {
    let (state, _) = setup();
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
    assert_dual_token_by_index(expected_list.span());
}

//
// token_of_owner_by_index & tokenOfOwnerByIndex
//

#[test]
fn test_token_of_owner_by_index() {
    let (_, tokens_list) = setup();

    assert_dual_token_of_owner_by_index(OWNER(), tokens_list);
}

#[test]
#[should_panic(expected: ('ERC721Enum: out of bounds index',))]
fn test_token_of_owner_by_index_when_index_equals_owned_tokens() {
    let (state, tokens_list) = setup();
    let owned_token_len = tokens_list.len().into();

    state.token_of_owner_by_index(OWNER(), owned_token_len);
}

#[test]
#[should_panic(expected: ('ERC721Enum: out of bounds index',))]
fn test_token_of_owner_by_index_when_index_exceeds_owned_tokens() {
    let (state, tokens_list) = setup();
    let owned_tokens_len_plus_one = tokens_list.len().into() + 1;

    state.token_of_owner_by_index(OWNER(), owned_tokens_len_plus_one);
}

#[test]
#[should_panic(expected: ('ERC721Enum: out of bounds index',))]
fn test_token_of_owner_by_index_when_target_has_no_tokens() {
    let (state, _) = setup();

    state.token_of_owner_by_index(OTHER(), 0);
}

#[test]
#[should_panic(expected: ('ERC721: invalid account',))]
fn test_token_of_owner_by_index_when_owner_is_zero() {
    let (state, _) = setup();

    state.token_of_owner_by_index(ZERO(), 0);
}

#[test]
fn test_token_of_owner_by_index_remove_last_token() {
    let (_, tokens_list) = setup();
    let mut contract_state = CONTRACT_STATE();
    let last_token = *tokens_list.at(tokens_list.len() - 1);

    contract_state.erc721._transfer(OWNER(), RECIPIENT(), last_token);

    let expected_list = array![TOKEN_1, TOKEN_2];
    assert_dual_token_of_owner_by_index(OWNER(), expected_list.span());
}

#[test]
fn test_token_of_owner_by_index_remove_first_token() {
    let (_, tokens_list) = setup();
    let mut contract_state = CONTRACT_STATE();
    let first_token = *tokens_list.at(0);

    contract_state.erc721._transfer(OWNER(), RECIPIENT(), first_token);

    // Removed tokens are replaced by the last token
    // to prevent indexing gaps
    let expected_list = array![TOKEN_3, TOKEN_2];
    assert_dual_token_of_owner_by_index(OWNER(), expected_list.span());
}

#[test]
fn test_token_of_owner_by_index_when_all_tokens_transferred() {
    let (_, tokens_list) = setup();
    let mut contract_state = CONTRACT_STATE();

    contract_state.erc721._transfer(OWNER(), RECIPIENT(), TOKEN_1);
    contract_state.erc721._transfer(OWNER(), RECIPIENT(), TOKEN_2);
    contract_state.erc721._transfer(OWNER(), RECIPIENT(), TOKEN_3);

    assert_dual_token_of_owner_by_index(RECIPIENT(), tokens_list);
}

//
// _update
//

#[test]
fn test__update_when_mint() {
    let (mut state, _) = setup();
    let initial_supply = state.total_supply();
    let new_token = 'TOKEN_4';

    state.before_update(OWNER(), new_token);

    // Check new supply
    let new_supply = state.total_supply();
    assert_eq!(initial_supply + 1, new_supply);

    // Check owner's tokens
    let exp_owner_tokens = array![TOKEN_1, TOKEN_2, TOKEN_3, new_token];
    assert_after_update_owned_tokens_list(OWNER(), exp_owner_tokens.span());

    // Check total tokens list
    let exp_total_tokens = array![TOKEN_1, TOKEN_2, TOKEN_3, new_token];
    assert_dual_token_by_index(exp_total_tokens.span());
}

#[test]
fn test__update_when_last_token_burned() {
    let (mut state, tokens_list) = setup();
    let initial_supply = state.total_supply();
    let last_token_to_burn = *tokens_list.at(initial_supply.try_into().unwrap() - 1);

    state.before_update(ZERO(), last_token_to_burn);

    // Check new supply
    let new_supply = state.total_supply();
    assert_eq!(initial_supply - 1, new_supply);

    // Check owner's tokens
    let exp_owner_tokens = array![TOKEN_1, TOKEN_2];
    assert_after_update_owned_tokens_list(OWNER(), exp_owner_tokens.span());

    // Check total tokens
    let exp_total_tokens = array![TOKEN_1, TOKEN_2];
    assert_after_update_all_tokens_list(exp_total_tokens.span());
}

#[test]
fn test__update_when_first_token_burned() {
    let (mut state, tokens_list) = setup();
    let initial_supply = state.total_supply();
    let first_token_to_burn = *tokens_list.at(0);

    state.before_update(ZERO(), first_token_to_burn);

    // Check new supply
    let new_supply = state.total_supply();
    assert_eq!(initial_supply - 1, new_supply);

    // Removed tokens are replaced by the last token
    // to prevent indexing gaps
    //
    // Check owner's tokens
    let exp_owner_tokens = array![TOKEN_3, TOKEN_2];
    assert_after_update_owned_tokens_list(OWNER(), exp_owner_tokens.span());

    // Check total tokens
    let exp_total_tokens = array![TOKEN_3, TOKEN_2];
    assert_after_update_all_tokens_list(exp_total_tokens.span());
}

#[test]
fn test__update_when_transfer_last_token() {
    let (mut state, tokens_list) = setup();
    let initial_supply = state.total_supply();
    let transfer_token = *tokens_list.at(initial_supply.try_into().unwrap() - 1);

    state.before_update(RECIPIENT(), transfer_token);

    // Check supply doesn't change
    let new_supply = state.total_supply();
    assert_eq!(initial_supply, new_supply);

    // Check owner's tokens
    let exp_owner_tokens = array![TOKEN_1, TOKEN_2];
    assert_after_update_owned_tokens_list(OWNER(), exp_owner_tokens.span());

    // Check recipient's tokens
    let exp_recipient_tokens = array![transfer_token];
    assert_after_update_owned_tokens_list(RECIPIENT(), exp_recipient_tokens.span());

    // Check total tokens
    let exp_total_tokens = array![TOKEN_1, TOKEN_2, TOKEN_3];
    assert_after_update_all_tokens_list(exp_total_tokens.span());
}

#[test]
fn test__update_when_transfer_first_token() {
    let (mut state, tokens_list) = setup();
    let initial_supply = state.total_supply();
    let transfer_token = *tokens_list.at(0);

    state.before_update(RECIPIENT(), transfer_token);

    // Check supply doesn't change
    let new_supply = state.total_supply();
    assert_eq!(initial_supply, new_supply);

    // Removed tokens are replaced by the last token
    // to prevent indexing gaps
    //
    // Check owner's tokens
    let exp_owner_tokens = array![TOKEN_3, TOKEN_2];
    assert_after_update_owned_tokens_list(OWNER(), exp_owner_tokens.span());

    // Check recipient's tokens
    let exp_recipient_tokens = array![transfer_token];
    assert_after_update_owned_tokens_list(RECIPIENT(), exp_recipient_tokens.span());

    // Check all tokens
    let exp_total_tokens = array![TOKEN_1, TOKEN_2, TOKEN_3];
    assert_after_update_all_tokens_list(exp_total_tokens.span());
}

//
// _add_token_to_owner_enumeration
//

#[test]
fn test__add_token_to_owner_enumeration() {
    let (mut state, tokens_list) = setup();
    let new_token_id = 'TOKEN_4';
    let new_token_index = tokens_list.len().into();

    assert_owner_tokens_index_to_id(OWNER(), new_token_index, 0);
    assert_owner_tokens_id_to_index(new_token_id, 0);

    state._add_token_to_owner_enumeration(OWNER(), new_token_id);

    assert_owner_tokens_index_to_id(OWNER(), new_token_index, new_token_id);
    assert_owner_tokens_id_to_index(new_token_id, new_token_index);
}

//
// _add_token_to_all_tokens_enumeration
//

#[test]
fn test__add_token_to_all_tokens_enumeration() {
    let (mut state, _) = setup();
    let initial_supply = state.total_supply();
    let new_token_id = 'TOKEN_4';
    let new_token_index = initial_supply;

    assert_all_tokens_index_to_id(new_token_index, 0);
    assert_all_tokens_id_to_index(new_token_id, 0);

    state._add_token_to_all_tokens_enumeration(new_token_id);

    assert_all_tokens_index_to_id(new_token_index, new_token_id);
    assert_all_tokens_id_to_index(new_token_id, new_token_index);

    // Check supply
    let new_supply = state.total_supply();
    assert_eq!(initial_supply + 1, new_supply);
}

//
// _remove_token_from_owner_enumeration
//

#[test]
fn test__remove_token_from_owner_enumeration_with_last_token() {
    let (mut state, tokens_list) = setup();
    let last_token_index = state.total_supply() - 1;
    let last_token_id = *tokens_list.at(last_token_index.try_into().unwrap());

    assert_owner_tokens_index_to_id(OWNER(), last_token_index, last_token_id);
    assert_owner_tokens_id_to_index(last_token_id, last_token_index);

    state._remove_token_from_owner_enumeration(OWNER(), last_token_id);

    assert_owner_tokens_index_to_id(OWNER(), last_token_index, 0);
    assert_owner_tokens_id_to_index(last_token_id, 0);
}

#[test]
fn test__remove_token_from_owner_enumeration_with_first_token() {
    let (mut state, tokens_list) = setup();
    let first_token_index = 0;
    let first_token_id = *tokens_list.at(0);
    let last_token_index = tokens_list.len() - 1;
    let last_token_id = *tokens_list.at(last_token_index);

    assert_owner_tokens_index_to_id(OWNER(), first_token_index, first_token_id);
    assert_owner_tokens_id_to_index(first_token_id, first_token_index);

    state._remove_token_from_owner_enumeration(OWNER(), first_token_id);

    // Note that the original last indexed token id is now the first because of the
    // swap-and-pop operation.
    assert_owner_tokens_index_to_id(OWNER(), first_token_index, last_token_id);
    assert_owner_tokens_id_to_index(first_token_id, 0);
}

//
// _remove_token_from_all_tokens_enumeration
//

#[test]
fn test__remove_token_from_all_tokens_enumeration_with_last_token() {
    let (mut state, tokens_list) = setup();
    let initial_supply = state.total_supply();
    let last_token_index = state.total_supply() - 1;
    let last_token_id = *tokens_list.at(last_token_index.try_into().unwrap());

    assert_all_tokens_index_to_id(last_token_index, last_token_id);
    assert_all_tokens_id_to_index(last_token_id, last_token_index);

    state._remove_token_from_all_tokens_enumeration(last_token_id);

    assert_all_tokens_index_to_id(last_token_index, last_token_id);
    assert_all_tokens_id_to_index(last_token_id, last_token_index);

    // Check supply
    let new_supply = state.total_supply();
    assert_eq!(initial_supply - 1, new_supply);
}

#[test]
fn test__remove_token_from_all_tokens_enumeration_with_first_token() {
    let (mut state, tokens_list) = setup();
    let initial_supply = state.total_supply();
    let first_token_index = 0;
    let first_token_id = *tokens_list.at(0);
    let last_token_index = tokens_list.len() - 1;
    let last_token_id = *tokens_list.at(last_token_index);

    assert_all_tokens_index_to_id(first_token_index, first_token_id);
    assert_all_tokens_id_to_index(first_token_id, first_token_index);

    state._remove_token_from_all_tokens_enumeration(first_token_id);

    assert_all_tokens_index_to_id(first_token_index, last_token_id);
    assert_all_tokens_id_to_index(first_token_id, 0);

    // Check supply
    let new_supply = state.total_supply();
    assert_eq!(initial_supply - 1, new_supply);
}

//
// Helpers
//

fn assert_dual_token_of_owner_by_index(owner: ContractAddress, expected_token_list: Span<u256>) {
    let mut state = COMPONENT_STATE();

    let mut i = 0;
    loop {
        if i == expected_token_list.len() {
            break;
        };
        // snake_case
        let token = state.token_of_owner_by_index(owner, i.into());
        assert_eq!(token, *expected_token_list.at(i));

        // camelCase
        let token = state.tokenOfOwnerByIndex(owner, i.into());
        assert_eq!(token, *expected_token_list.at(i));

        i = i + 1;
    };
}

fn assert_dual_token_by_index(expected_token_list: Span<u256>) {
    let mut state = COMPONENT_STATE();

    let mut i = 0;
    loop {
        if i == expected_token_list.len() {
            break;
        };
        // snake_case
        let token = state.token_by_index(i.into());
        assert_eq!(token, *expected_token_list.at(i));

        // camelCase
        let token = state.tokenByIndex(i.into());
        assert_eq!(token, *expected_token_list.at(i));

        i = i + 1;
    };
}

fn assert_after_update_all_tokens_list(expected_list: Span<u256>) {
    let state = COMPONENT_STATE();

    let mut i = 0;
    loop {
        if i == expected_list.len()  {
            break;
        };
        // Check total tokens list
        let token = state.ERC721Enumerable_all_tokens.read(i.into());
        assert_eq!(token, *expected_list.at(i));

        i = i + 1;
    };
}

fn assert_after_update_owned_tokens_list(owner: ContractAddress, expected_list: Span<u256>) {
    let state = COMPONENT_STATE();

    let mut i = 0;
    loop {
        if i == expected_list.len()  {
            break;
        };
        // Check owned tokens list
        let token = state.ERC721Enumerable_owned_tokens.read((owner, i.into()));
        assert_eq!(token, *expected_list.at(i));

        i = i + 1;
    };
}

fn assert_all_tokens_index_to_id(index: u256, exp_token_id: u256) {
    let state = COMPONENT_STATE();

    let index_to_id = state.ERC721Enumerable_all_tokens.read(index);
    assert_eq!(index_to_id, exp_token_id);
}

fn assert_all_tokens_id_to_index(token_id: u256, exp_index: u256) {
    let state = COMPONENT_STATE();

    let id_to_index = state.ERC721Enumerable_all_tokens_index.read(token_id);
    assert_eq!(id_to_index, exp_index);
}

fn assert_owner_tokens_index_to_id(owner: ContractAddress, index: u256, exp_token_id: u256) {
    let state = COMPONENT_STATE();

    let index_to_id = state.ERC721Enumerable_owned_tokens.read((owner, index));
    assert_eq!(index_to_id, exp_token_id);
}

fn assert_owner_tokens_id_to_index(token_id: u256, exp_index: u256) {
    let state = COMPONENT_STATE();

    let id_to_index = state.ERC721Enumerable_owned_tokens_index.read(token_id);
    assert_eq!(id_to_index, exp_index);
}
