use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{
    DATA, OWNER, RECIPIENT, SPENDER, OPERATOR, NAME, SYMBOL, BASE_URI, TOKEN_ID
};
use openzeppelin_token::erc721::dual721::{DualCaseERC721, DualCaseERC721Trait};
use openzeppelin_token::erc721::interface::IERC721_ID;
use openzeppelin_token::erc721::interface::{
    IERC721CamelOnlyDispatcher, IERC721CamelOnlyDispatcherTrait
};
use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{start_cheat_caller_address};
use starknet::ContractAddress;

//
// Setup
//

fn setup_snake() -> (DualCaseERC721, IERC721Dispatcher) {
    let mut calldata = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(OWNER());
    calldata.append_serde(TOKEN_ID);

    let target = utils::declare_and_deploy("SnakeERC721Mock", calldata);
    start_cheat_caller_address(target, OWNER());
    (DualCaseERC721 { contract_address: target }, IERC721Dispatcher { contract_address: target })
}

fn setup_camel() -> (DualCaseERC721, IERC721CamelOnlyDispatcher) {
    let mut calldata = array![];
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(OWNER());
    calldata.append_serde(TOKEN_ID);

    let target = utils::declare_and_deploy("CamelERC721Mock", calldata);
    start_cheat_caller_address(target, OWNER());
    (
        DualCaseERC721 { contract_address: target },
        IERC721CamelOnlyDispatcher { contract_address: target }
    )
}

fn setup_non_erc721() -> DualCaseERC721 {
    let calldata = array![];
    let target = utils::declare_and_deploy("NonImplementingMock", calldata);
    DualCaseERC721 { contract_address: target }
}

fn setup_erc721_panic() -> (DualCaseERC721, DualCaseERC721) {
    let snake_target = utils::declare_and_deploy("SnakeERC721PanicMock", array![]);
    let camel_target = utils::declare_and_deploy("CamelERC721PanicMock", array![]);
    (
        DualCaseERC721 { contract_address: snake_target },
        DualCaseERC721 { contract_address: camel_target }
    )
}

fn setup_receiver() -> ContractAddress {
    utils::declare_and_deploy("DualCaseERC721ReceiverMock", array![])
}

//
// Case agnostic methods
//

#[test]
fn test_dual_name() {
    let (snake_dispatcher, _) = setup_snake();
    assert_eq!(snake_dispatcher.name(), NAME());

    let (camel_dispatcher, _) = setup_camel();
    assert_eq!(camel_dispatcher.name(), NAME());
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_name() {
    let dispatcher = setup_non_erc721();
    dispatcher.name();
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_name_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_panic();
    dispatcher.name();
}

#[test]
fn test_dual_symbol() {
    let (snake_dispatcher, _) = setup_snake();
    let (camel_dispatcher, _) = setup_camel();
    assert_eq!(snake_dispatcher.symbol(), SYMBOL());
    assert_eq!(camel_dispatcher.symbol(), SYMBOL());
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_symbol() {
    let dispatcher = setup_non_erc721();
    dispatcher.symbol();
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_symbol_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_panic();
    dispatcher.symbol();
}

#[test]
fn test_dual_approve() {
    let (snake_dispatcher, snake_target) = setup_snake();

    start_cheat_caller_address(snake_dispatcher.contract_address, OWNER());
    snake_dispatcher.approve(SPENDER(), TOKEN_ID);
    assert_eq!(snake_target.get_approved(TOKEN_ID), SPENDER());

    let (camel_dispatcher, camel_target) = setup_camel();

    start_cheat_caller_address(camel_dispatcher.contract_address, OWNER());
    camel_dispatcher.approve(SPENDER(), TOKEN_ID);
    assert_eq!(camel_target.getApproved(TOKEN_ID), SPENDER());
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_approve() {
    let dispatcher = setup_non_erc721();
    dispatcher.approve(SPENDER(), TOKEN_ID);
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_approve_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_panic();
    dispatcher.approve(SPENDER(), TOKEN_ID);
}

//
// snake_case target
//

#[test]
fn test_dual_balance_of() {
    let (dispatcher, _) = setup_snake();
    assert_eq!(dispatcher.balance_of(OWNER()), 1);
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_balance_of() {
    let dispatcher = setup_non_erc721();
    dispatcher.balance_of(OWNER());
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_balance_of_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_panic();
    dispatcher.balance_of(OWNER());
}

#[test]
fn test_dual_owner_of() {
    let (dispatcher, _) = setup_snake();
    assert_eq!(dispatcher.owner_of(TOKEN_ID), OWNER());
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_owner_of() {
    let dispatcher = setup_non_erc721();
    dispatcher.owner_of(TOKEN_ID);
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_owner_of_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_panic();
    dispatcher.owner_of(TOKEN_ID);
}

#[test]
fn test_dual_transfer_from() {
    let (dispatcher, target) = setup_snake();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID);
    assert_eq!(target.owner_of(TOKEN_ID), RECIPIENT());
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_transfer_from() {
    let dispatcher = setup_non_erc721();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID);
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_transfer_from_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_panic();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID);
}

#[test]
fn test_dual_safe_transfer_from() {
    let (dispatcher, target) = setup_snake();
    let receiver = setup_receiver();
    dispatcher.safe_transfer_from(OWNER(), receiver, TOKEN_ID, DATA(true));
    assert_eq!(target.owner_of(TOKEN_ID), receiver);
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_safe_transfer_from() {
    let dispatcher = setup_non_erc721();
    dispatcher.safe_transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, DATA(true));
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_safe_transfer_from_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_panic();
    dispatcher.safe_transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, DATA(true));
}

#[test]
fn test_dual_get_approved() {
    let (dispatcher, target) = setup_snake();

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    target.approve(SPENDER(), TOKEN_ID);
    assert_eq!(dispatcher.get_approved(TOKEN_ID), SPENDER());
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_get_approved() {
    let dispatcher = setup_non_erc721();
    dispatcher.get_approved(TOKEN_ID);
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_get_approved_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_panic();
    dispatcher.get_approved(TOKEN_ID);
}

#[test]
fn test_dual_set_approval_for_all() {
    let (dispatcher, target) = setup_snake();

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.set_approval_for_all(OPERATOR(), true);

    let is_approved_for_all = target.is_approved_for_all(OWNER(), OPERATOR());
    assert!(is_approved_for_all);
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_set_approval_for_all() {
    let dispatcher = setup_non_erc721();
    dispatcher.set_approval_for_all(OPERATOR(), true);
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_set_approval_for_all_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_panic();
    dispatcher.set_approval_for_all(OPERATOR(), true);
}

#[test]
fn test_dual_is_approved_for_all() {
    let (dispatcher, target) = setup_snake();

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    target.set_approval_for_all(OPERATOR(), true);

    let is_approved_for_all = dispatcher.is_approved_for_all(OWNER(), OPERATOR());
    assert!(is_approved_for_all);
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_is_approved_for_all() {
    let dispatcher = setup_non_erc721();
    dispatcher.is_approved_for_all(OWNER(), OPERATOR());
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_is_approved_for_all_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_panic();
    dispatcher.is_approved_for_all(OWNER(), OPERATOR());
}

#[test]
fn test_dual_token_uri() {
    let (dispatcher, _) = setup_snake();
    let uri = dispatcher.token_uri(TOKEN_ID);
    let expected = format!("{}{}", BASE_URI(), TOKEN_ID);
    assert_eq!(uri, expected);
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_token_uri() {
    let dispatcher = setup_non_erc721();
    dispatcher.token_uri(TOKEN_ID);
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_token_uri_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_panic();
    dispatcher.token_uri(TOKEN_ID);
}

#[test]
fn test_dual_supports_interface() {
    let (dispatcher, _) = setup_snake();
    let supports_ierc721 = dispatcher.supports_interface(IERC721_ID);
    assert!(supports_ierc721);
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_supports_interface() {
    let dispatcher = setup_non_erc721();
    dispatcher.supports_interface(IERC721_ID);
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_supports_interface_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_panic();
    dispatcher.supports_interface(IERC721_ID);
}

//
// camelCase target
//

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
fn test_dual_balanceOf() {
    let (dispatcher, _) = setup_camel();
    assert_eq!(dispatcher.balance_of(OWNER()), 1);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
#[should_panic(expected: ("Some error",))]
fn test_dual_balanceOf_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_panic();
    dispatcher.balance_of(OWNER());
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
fn test_dual_ownerOf() {
    let (dispatcher, _) = setup_camel();
    let current_owner = dispatcher.owner_of(TOKEN_ID);
    assert_eq!(current_owner, OWNER());
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
#[should_panic(expected: ("Some error",))]
fn test_dual_ownerOf_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_panic();
    dispatcher.owner_of(TOKEN_ID);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
fn test_dual_transferFrom() {
    let (dispatcher, target) = setup_camel();

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID);

    let current_owner = target.ownerOf(TOKEN_ID);
    assert_eq!(current_owner, RECIPIENT());
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
#[should_panic(expected: ("Some error",))]
fn test_dual_transferFrom_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_panic();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
fn test_dual_safeTransferFrom() {
    let (dispatcher, target) = setup_camel();
    let receiver = setup_receiver();
    dispatcher.safe_transfer_from(OWNER(), receiver, TOKEN_ID, DATA(true));

    let current_owner = target.ownerOf(TOKEN_ID);
    assert_eq!(current_owner, receiver);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
#[should_panic(expected: ("Some error",))]
fn test_dual_safeTransferFrom_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_panic();
    dispatcher.safe_transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, DATA(true));
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
fn test_dual_getApproved() {
    let (dispatcher, _) = setup_camel();

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.approve(SPENDER(), TOKEN_ID);

    let approved = dispatcher.get_approved(TOKEN_ID);
    assert_eq!(approved, SPENDER());
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
#[should_panic(expected: ("Some error",))]
fn test_dual_getApproved_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_panic();
    dispatcher.get_approved(TOKEN_ID);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
fn test_dual_setApprovalForAll() {
    let (dispatcher, target) = setup_camel();

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.set_approval_for_all(OPERATOR(), true);

    let is_approved_for_all = target.isApprovedForAll(OWNER(), OPERATOR());
    assert!(is_approved_for_all);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
#[should_panic(expected: ("Some error",))]
fn test_dual_setApprovalForAll_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_panic();
    dispatcher.set_approval_for_all(OPERATOR(), true);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
fn test_dual_isApprovedForAll() {
    let (dispatcher, target) = setup_camel();

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    target.setApprovalForAll(OPERATOR(), true);

    let is_approved_for_all = dispatcher.is_approved_for_all(OWNER(), OPERATOR());
    assert!(is_approved_for_all);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
#[should_panic(expected: ("Some error",))]
fn test_dual_isApprovedForAll_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_panic();
    dispatcher.is_approved_for_all(OWNER(), OPERATOR());
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
fn test_dual_tokenURI() {
    let (dispatcher, _) = setup_camel();
    let uri = dispatcher.token_uri(TOKEN_ID);
    let expected = format!("{}{}", BASE_URI(), TOKEN_ID);
    assert_eq!(uri, expected);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
#[should_panic(expected: ("Some error",))]
fn test_dual_tokenURI_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_panic();
    dispatcher.token_uri(TOKEN_ID);
}
