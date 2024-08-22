use core::num::traits::Zero;
use openzeppelin_test_common::erc1155::{setup_account, setup_receiver};
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{
    EMPTY_DATA, OWNER, RECIPIENT, OPERATOR, TOKEN_ID, TOKEN_ID_2, TOKEN_VALUE
};
use openzeppelin_token::erc1155::dual1155::{DualCaseERC1155, DualCaseERC1155Trait};
use openzeppelin_token::erc1155::interface::IERC1155_ID;
use openzeppelin_token::erc1155::interface::{IERC1155CamelDispatcher, IERC1155CamelDispatcherTrait};
use openzeppelin_token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::start_cheat_caller_address;
use starknet::ContractAddress;

//
// Setup
//

fn setup_snake() -> (DualCaseERC1155, IERC1155Dispatcher, ContractAddress) {
    let base_uri: ByteArray = "URI";
    let owner = setup_account();
    let mut calldata = array![];
    calldata.append_serde(base_uri);
    calldata.append_serde(owner);
    calldata.append_serde(TOKEN_ID);
    calldata.append_serde(TOKEN_VALUE);
    let target = utils::declare_and_deploy("SnakeERC1155Mock", calldata);
    (
        DualCaseERC1155 { contract_address: target },
        IERC1155Dispatcher { contract_address: target },
        owner
    )
}

fn setup_camel() -> (DualCaseERC1155, IERC1155CamelDispatcher, ContractAddress) {
    let base_uri: ByteArray = "URI";
    let owner = setup_account();
    let mut calldata = array![];
    calldata.append_serde(base_uri);
    calldata.append_serde(owner);
    calldata.append_serde(TOKEN_ID);
    calldata.append_serde(TOKEN_VALUE);
    let target = utils::declare_and_deploy("CamelERC1155Mock", calldata);
    (
        DualCaseERC1155 { contract_address: target },
        IERC1155CamelDispatcher { contract_address: target },
        owner
    )
}

fn setup_non_erc1155() -> DualCaseERC1155 {
    let calldata = array![];
    let target = utils::declare_and_deploy("NonImplementingMock", calldata);
    DualCaseERC1155 { contract_address: target }
}

fn setup_erc1155_panic() -> (DualCaseERC1155, DualCaseERC1155) {
    let snake_target = utils::declare_and_deploy("SnakeERC1155PanicMock", array![]);
    let camel_target = utils::declare_and_deploy("CamelERC1155PanicMock", array![]);
    (
        DualCaseERC1155 { contract_address: snake_target },
        DualCaseERC1155 { contract_address: camel_target }
    )
}

//
// Case agnostic methods
//

#[test]
fn test_dual_uri_snake() {
    let (snake_dispatcher, _, _) = setup_snake();
    assert_eq!(snake_dispatcher.uri(TOKEN_ID), "URI");
}

#[test]
fn test_dual_uri_camel() {
    let (camel_dispatcher, _, _) = setup_camel();
    assert_eq!(camel_dispatcher.uri(TOKEN_ID), "URI");
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_uri() {
    let dispatcher = setup_non_erc1155();
    dispatcher.uri(TOKEN_ID);
}

#[test]
#[should_panic(expected: "Some error")]
fn test_dual_uri_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_panic();
    dispatcher.uri(TOKEN_ID);
}

//
// snake_case target
//

#[test]
fn test_dual_balance_of() {
    let (dispatcher, _, owner) = setup_snake();
    assert_eq!(dispatcher.balance_of(owner, TOKEN_ID), TOKEN_VALUE);
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_balance_of() {
    let dispatcher = setup_non_erc1155();
    dispatcher.balance_of(OWNER(), TOKEN_ID);
}

#[test]
#[should_panic(expected: "Some error")]
fn test_dual_balance_of_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_panic();
    dispatcher.balance_of(OWNER(), TOKEN_ID);
}

#[test]
fn test_dual_balance_of_batch() {
    let (dispatcher, _, owner) = setup_snake();
    let accounts = array![owner, RECIPIENT()].span();
    let token_ids = array![TOKEN_ID, TOKEN_ID_2].span();

    let balances = dispatcher.balance_of_batch(accounts, token_ids);
    assert_eq!(*balances.at(0), TOKEN_VALUE);
    assert!((*balances.at(1)).is_zero());
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_balance_of_batch() {
    let dispatcher = setup_non_erc1155();
    let (accounts, token_ids) = get_accounts_and_ids();
    dispatcher.balance_of_batch(accounts, token_ids);
}

#[test]
#[should_panic(expected: "Some error")]
fn test_dual_balance_of_batch_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_panic();
    let (accounts, token_ids) = get_accounts_and_ids();
    dispatcher.balance_of_batch(accounts, token_ids);
}

#[test]
fn test_dual_safe_transfer_from() {
    let (dispatcher, target, owner) = setup_snake();
    let receiver = setup_receiver();

    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.safe_transfer_from(owner, receiver, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
    assert_eq!(target.balance_of(receiver, TOKEN_ID), TOKEN_VALUE);
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_safe_transfer_from() {
    let dispatcher = setup_non_erc1155();
    dispatcher.safe_transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
}

#[test]
#[should_panic(expected: "Some error")]
fn test_dual_safe_transfer_from_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_panic();
    dispatcher.safe_transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
}

#[test]
fn test_dual_safe_batch_transfer_from() {
    let (dispatcher, target, owner) = setup_snake();
    let token_ids = array![TOKEN_ID, TOKEN_ID_2].span();
    let values = array![TOKEN_VALUE, 0].span();
    let receiver = setup_receiver();

    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.safe_batch_transfer_from(owner, receiver, token_ids, values, EMPTY_DATA());
    assert_eq!(target.balance_of(receiver, TOKEN_ID), TOKEN_VALUE);
    assert!(target.balance_of(receiver, TOKEN_ID_2).is_zero());
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_safe_batch_transfer_from() {
    let dispatcher = setup_non_erc1155();
    let token_ids = array![TOKEN_ID, TOKEN_ID_2].span();
    let values = array![TOKEN_VALUE, 0].span();
    dispatcher.safe_batch_transfer_from(OWNER(), RECIPIENT(), token_ids, values, EMPTY_DATA());
}

#[test]
#[should_panic(expected: "Some error")]
fn test_dual_safe_batch_transfer_from_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_panic();
    let token_ids = array![TOKEN_ID, TOKEN_ID_2].span();
    let values = array![TOKEN_VALUE, 0].span();
    dispatcher.safe_batch_transfer_from(OWNER(), RECIPIENT(), token_ids, values, EMPTY_DATA());
}

#[test]
fn test_dual_is_approved_for_all() {
    let (dispatcher, target, _) = setup_snake();

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    target.set_approval_for_all(OPERATOR(), true);

    let is_approved_for_all = dispatcher.is_approved_for_all(OWNER(), OPERATOR());
    assert!(is_approved_for_all);
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_is_approved_for_all() {
    let dispatcher = setup_non_erc1155();
    dispatcher.is_approved_for_all(OWNER(), OPERATOR());
}

#[test]
#[should_panic(expected: "Some error")]
fn test_dual_is_approved_for_all_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_panic();
    dispatcher.is_approved_for_all(OWNER(), OPERATOR());
}

#[test]
fn test_dual_set_approval_for_all() {
    let (dispatcher, target, _) = setup_snake();

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.set_approval_for_all(OPERATOR(), true);

    let is_approved_for_all = target.is_approved_for_all(OWNER(), OPERATOR());
    assert!(is_approved_for_all);
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_set_approval_for_all() {
    let dispatcher = setup_non_erc1155();
    dispatcher.set_approval_for_all(OPERATOR(), true);
}

#[test]
#[should_panic(expected: "Some error")]
fn test_dual_set_approval_for_all_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_panic();
    dispatcher.set_approval_for_all(OPERATOR(), true);
}

#[test]
fn test_dual_supports_interface() {
    let (dispatcher, _, _) = setup_snake();
    let supports_ierc1155 = dispatcher.supports_interface(IERC1155_ID);
    assert!(supports_ierc1155);
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_supports_interface() {
    let dispatcher = setup_non_erc1155();
    dispatcher.supports_interface(IERC1155_ID);
}

#[test]
#[should_panic(expected: "Some error")]
fn test_dual_supports_interface_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_panic();
    dispatcher.supports_interface(IERC1155_ID);
}

//
// camelCase target
//

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
fn test_dual_balanceOf() {
    let (dispatcher, _, owner) = setup_camel();
    assert_eq!(dispatcher.balance_of(owner, TOKEN_ID), TOKEN_VALUE);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
#[should_panic(expected: "Some error")]
fn test_dual_balanceOf_exists_and_panics() {
    let (_, dispatcher) = setup_erc1155_panic();
    dispatcher.balance_of(OWNER(), TOKEN_ID);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
fn test_dual_balanceOfBatch() {
    let (dispatcher, _, owner) = setup_camel();
    let accounts = array![owner, RECIPIENT()].span();
    let token_ids = array![TOKEN_ID, TOKEN_ID_2].span();

    let balances = dispatcher.balance_of_batch(accounts, token_ids);
    assert_eq!(*balances.at(0), TOKEN_VALUE);
    assert!((*balances.at(1)).is_zero());
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
#[should_panic(expected: "Some error")]
fn test_dual_balanceOfBatch_exists_and_panics() {
    let (_, dispatcher) = setup_erc1155_panic();
    let (accounts, token_ids) = get_accounts_and_ids();
    dispatcher.balance_of_batch(accounts, token_ids);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
fn test_dual_safeTransferFrom() {
    let (dispatcher, target, owner) = setup_camel();
    let receiver = setup_receiver();

    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.safe_transfer_from(owner, receiver, TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
    assert_eq!(target.balanceOf(receiver, TOKEN_ID), TOKEN_VALUE);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
#[should_panic(expected: "Some error")]
fn test_dual_safeTransferFrom_exists_and_panics() {
    let (_, dispatcher) = setup_erc1155_panic();
    dispatcher.safe_transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
fn test_dual_safeBatchTransferFrom() {
    let (dispatcher, target, owner) = setup_camel();
    let token_ids = array![TOKEN_ID, TOKEN_ID_2].span();
    let values = array![TOKEN_VALUE, 0].span();
    let receiver = setup_receiver();

    start_cheat_caller_address(dispatcher.contract_address, owner);
    dispatcher.safe_batch_transfer_from(owner, receiver, token_ids, values, EMPTY_DATA());
    assert_eq!(target.balanceOf(receiver, TOKEN_ID), TOKEN_VALUE);
    assert!(target.balanceOf(receiver, TOKEN_ID_2).is_zero());
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
#[should_panic(expected: "Some error")]
fn test_dual_safeBatchTransferFrom_exists_and_panics() {
    let (_, dispatcher) = setup_erc1155_panic();
    let token_ids = array![TOKEN_ID, TOKEN_ID_2].span();
    let values = array![TOKEN_VALUE, 0].span();
    dispatcher.safe_batch_transfer_from(OWNER(), RECIPIENT(), token_ids, values, EMPTY_DATA());
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
fn test_dual_isApprovedForAll() {
    let (dispatcher, target, _) = setup_camel();

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    target.setApprovalForAll(OPERATOR(), true);

    let is_approved_for_all = dispatcher.is_approved_for_all(OWNER(), OPERATOR());
    assert!(is_approved_for_all);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
#[should_panic(expected: "Some error")]
fn test_dual_isApprovedForAll_exists_and_panics() {
    let (_, dispatcher) = setup_erc1155_panic();
    dispatcher.is_approved_for_all(OWNER(), OPERATOR());
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
fn test_dual_setApprovalForAll() {
    let (dispatcher, target, _) = setup_camel();

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.set_approval_for_all(OPERATOR(), true);

    let is_approved_for_all = target.isApprovedForAll(OWNER(), OPERATOR());
    assert!(is_approved_for_all);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
#[should_panic(expected: "Some error")]
fn test_dual_setApprovalForAll_exists_and_panics() {
    let (_, dispatcher) = setup_erc1155_panic();
    dispatcher.set_approval_for_all(OPERATOR(), true);
}

//
// Helpers
//

fn get_accounts_and_ids() -> (Span<ContractAddress>, Span<u256>) {
    let accounts = array![OWNER(), RECIPIENT()].span();
    let ids = array![TOKEN_ID, TOKEN_ID_2].span();
    (accounts, ids)
}
