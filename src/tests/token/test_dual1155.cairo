use openzeppelin::tests::mocks::erc1155_mocks::{CamelERC1155Mock, SnakeERC1155Mock};
use openzeppelin::tests::mocks::erc1155_mocks::{CamelERC1155PanicMock, SnakeERC1155PanicMock};

use openzeppelin::tests::mocks::erc1155_receiver_mocks::DualCaseERC1155ReceiverMock;
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::utils::constants::{
    DATA, OWNER, RECIPIENT, SPENDER, OPERATOR, OTHER, NAME, SYMBOL, TOKEN_ID, TOKEN_VALUE, URI
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc1155::dual1155::{DualCaseERC1155, DualCaseERC1155Trait};
use openzeppelin::token::erc1155::interface::IERC1155_ID;
use openzeppelin::token::erc1155::interface::{
    IERC1155CamelOnlyDispatcher, IERC1155CamelOnlyDispatcherTrait
};
use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;
use starknet::testing::set_caller_address;
use starknet::testing::set_contract_address;

//
// Setup
//

fn setup_snake() -> (DualCaseERC1155, IERC1155Dispatcher) {
    let mut calldata = array![];
    calldata.append_serde(NAME);
    calldata.append_serde(SYMBOL);
    calldata.append_serde(OWNER());
    calldata.append_serde(TOKEN_ID);
    calldata.append_serde(TOKEN_VALUE);
    calldata.append_serde(URI);
    set_contract_address(OWNER());
    let target = utils::deploy(SnakeERC1155Mock::TEST_CLASS_HASH, calldata);
    (DualCaseERC1155 { contract_address: target }, IERC1155Dispatcher { contract_address: target })
}

fn setup_camel() -> (DualCaseERC1155, IERC1155CamelOnlyDispatcher) {
    let mut calldata = array![];
    calldata.append_serde(NAME);
    calldata.append_serde(SYMBOL);
    calldata.append_serde(OWNER());
    calldata.append_serde(TOKEN_ID);
    calldata.append_serde(URI);
    set_contract_address(OWNER());
    let target = utils::deploy(CamelERC1155Mock::TEST_CLASS_HASH, calldata);
    (
        DualCaseERC1155 { contract_address: target },
        IERC1155CamelOnlyDispatcher { contract_address: target }
    )
}

fn setup_non_erc1155() -> DualCaseERC1155 {
    let calldata = array![];
    let target = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, calldata);
    DualCaseERC1155 { contract_address: target }
}

fn setup_erc1155_panic() -> (DualCaseERC1155, DualCaseERC1155) {
    let snake_target = utils::deploy(SnakeERC1155PanicMock::TEST_CLASS_HASH, array![]);
    let camel_target = utils::deploy(CamelERC1155PanicMock::TEST_CLASS_HASH, array![]);
    (
        DualCaseERC1155 { contract_address: snake_target },
        DualCaseERC1155 { contract_address: camel_target }
    )
}

fn setup_receiver() -> ContractAddress {
    utils::deploy(DualCaseERC1155ReceiverMock::TEST_CLASS_HASH, array![])
}

//
// Tests
//

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_name() {
    let dispatcher = setup_non_erc1155();
    dispatcher.name();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED',))]
fn test_dual_name_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_panic();
    dispatcher.name();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_symbol() {
    let dispatcher = setup_non_erc1155();
    dispatcher.symbol();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED',))]
fn test_dual_symbol_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_panic();
    dispatcher.symbol();
}

//
// snake_case target
//

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_balance_of() {
    let dispatcher = setup_non_erc1155();
    dispatcher.balance_of(OWNER(), TOKEN_ID);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_transfer_from() {
    let dispatcher = setup_non_erc1155();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, TOKEN_VALUE);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_safe_transfer_from() {
    let dispatcher = setup_non_erc1155();
    dispatcher.safe_transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, TOKEN_VALUE, DATA(true));
}

#[test]
#[available_gas(2000000)]
fn test_dual_set_approval_for_all() {
    let (dispatcher, target) = setup_snake();
    set_contract_address(OWNER());
    dispatcher.set_approval_for_all(OPERATOR(), true);
    assert(target.is_approved_for_all(OWNER(), OPERATOR()), 'Operator not approved correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_set_approval_for_all() {
    let dispatcher = setup_non_erc1155();
    dispatcher.set_approval_for_all(OPERATOR(), true);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED',))]
fn test_dual_set_approval_for_all_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_panic();
    dispatcher.set_approval_for_all(OPERATOR(), true);
}

#[test]
#[available_gas(2000000)]
fn test_dual_is_approved_for_all() {
    let (dispatcher, target) = setup_snake();
    set_contract_address(OWNER());
    target.set_approval_for_all(OPERATOR(), true);
    assert(dispatcher.is_approved_for_all(OWNER(), OPERATOR()), 'Operator not approved correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_is_approved_for_all() {
    let dispatcher = setup_non_erc1155();
    dispatcher.is_approved_for_all(OWNER(), OPERATOR());
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED',))]
fn test_dual_is_approved_for_all_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_panic();
    dispatcher.is_approved_for_all(OWNER(), OPERATOR());
}

#[test]
#[available_gas(2000000)]
fn test_dual_uri() {
    let (dispatcher, target) = setup_snake();
    assert(dispatcher.uri(TOKEN_ID) == URI, 'Should return URI');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_uri() {
    let dispatcher = setup_non_erc1155();
    dispatcher.uri(TOKEN_ID);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED',))]
fn test_dual_uri_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_panic();
    dispatcher.uri(TOKEN_ID);
}

#[test]
#[available_gas(2000000)]
fn test_dual_supports_interface() {
    let (dispatcher, _) = setup_snake();
    assert(dispatcher.supports_interface(IERC1155_ID), 'Should support own interface');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_supports_interface() {
    let dispatcher = setup_non_erc1155();
    dispatcher.supports_interface(IERC1155_ID);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED',))]
fn test_dual_supports_interface_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_panic();
    dispatcher.supports_interface(IERC1155_ID);
}

//
// camelCase target
//

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED',))]
fn test_dual_setApprovalForAll_exists_and_panics() {
    let (_, dispatcher) = setup_erc1155_panic();
    dispatcher.set_approval_for_all(OPERATOR(), true);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED',))]
fn test_dual_tokenURI_exists_and_panics() {
    let (_, dispatcher) = setup_erc1155_panic();
    dispatcher.uri(TOKEN_ID);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED',))]
fn test_dual_supportsInterface_exists_and_panics() {
    let (_, dispatcher) = setup_erc1155_panic();
    dispatcher.supports_interface(IERC1155_ID);
}
