use openzeppelin::tests::mocks::erc721_enumerable_mocks::{
    CamelERC721EnumerableMock, SnakeERC721EnumerableMock
};
use openzeppelin::tests::mocks::erc721_enumerable_mocks::{
    CamelERC721EnumerablePanicMock, SnakeERC721EnumerablePanicMock
};
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::utils::constants::{OWNER, NAME, SYMBOL, BASE_URI, TOKEN_ID};
use openzeppelin::tests::utils;
use openzeppelin::token::erc721::dual721_enumerable::{
    DualCaseERC721Enumerable, DualCaseERC721EnumerableTrait
};
use openzeppelin::token::erc721::extensions::erc721_enumerable::interface::{
    IERC721EnumerableDispatcher, IERC721EnumerableCamelDispatcher
};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;

//
// Setup
//

fn setup_snake() -> (DualCaseERC721Enumerable, IERC721EnumerableDispatcher) {
    let mut calldata = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(OWNER());
    calldata.append_serde(TOKEN_ID);
    let target = utils::deploy(SnakeERC721EnumerableMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseERC721Enumerable { contract_address: target },
        IERC721EnumerableDispatcher { contract_address: target }
    )
}

fn setup_camel() -> (DualCaseERC721Enumerable, IERC721EnumerableCamelDispatcher) {
    let mut calldata = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(OWNER());
    calldata.append_serde(TOKEN_ID);
    let target = utils::deploy(CamelERC721EnumerableMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseERC721Enumerable { contract_address: target },
        IERC721EnumerableCamelDispatcher { contract_address: target }
    )
}

fn setup_non_erc721_enumerable() -> DualCaseERC721Enumerable {
    let calldata = array![];
    let target = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, calldata);
    DualCaseERC721Enumerable { contract_address: target }
}

fn setup_erc721_enumerable_panic() -> (DualCaseERC721Enumerable, DualCaseERC721Enumerable) {
    let snake_target = utils::deploy(SnakeERC721EnumerablePanicMock::TEST_CLASS_HASH, array![]);
    let camel_target = utils::deploy(CamelERC721EnumerablePanicMock::TEST_CLASS_HASH, array![]);
    (
        DualCaseERC721Enumerable { contract_address: snake_target },
        DualCaseERC721Enumerable { contract_address: camel_target }
    )
}

//
// snake_case target
//

#[test]
fn test_dual_total_supply() {
    let (dispatcher, _) = setup_snake();
    assert_eq!(dispatcher.total_supply(), 1);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_total_supply() {
    let dispatcher = setup_non_erc721_enumerable();
    dispatcher.total_supply();
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_total_supply_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_enumerable_panic();
    dispatcher.total_supply();
}

#[test]
fn test_dual_token_by_index() {
    let (dispatcher, _) = setup_snake();
    assert_eq!(dispatcher.token_by_index(0), TOKEN_ID);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_token_by_index() {
    let dispatcher = setup_non_erc721_enumerable();
    dispatcher.token_by_index(0);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_token_by_index_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_enumerable_panic();
    dispatcher.token_by_index(0);
}

#[test]
fn test_dual_token_of_owner_by_index() {
    let (dispatcher, _) = setup_snake();
    assert_eq!(dispatcher.token_of_owner_by_index(OWNER(), 0), TOKEN_ID);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_token_of_owner_by_index() {
    let dispatcher = setup_non_erc721_enumerable();
    dispatcher.token_of_owner_by_index(OWNER(), 0);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_token_of_owner_by_index_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_enumerable_panic();
    dispatcher.token_of_owner_by_index(OWNER(), 0);
}

//
// camelCase target
//

#[test]
fn test_dual_totalSupply() {
    let (dispatcher, _) = setup_camel();
    assert_eq!(dispatcher.total_supply(), 1);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_totalSupply_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_enumerable_panic();
    dispatcher.total_supply();
}

#[test]
fn test_dual_tokenByIndex() {
    let (dispatcher, _) = setup_camel();
    assert_eq!(dispatcher.token_by_index(0), TOKEN_ID);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_tokenByIndex_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_enumerable_panic();
    dispatcher.token_by_index(0);
}

#[test]
fn test_dual_tokenOfOwnerByIndex() {
    let (dispatcher, _) = setup_camel();
    assert_eq!(dispatcher.token_of_owner_by_index(OWNER(), 0), TOKEN_ID);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_tokenOfOwnerByIndex_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_enumerable_panic();
    dispatcher.token_of_owner_by_index(OWNER(), 0);
}
