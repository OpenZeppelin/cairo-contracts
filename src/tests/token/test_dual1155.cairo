use openzeppelin::tests::mocks::erc1155_mocks::{CamelERC1155Mock, SnakeERC1155Mock};
use openzeppelin::tests::mocks::erc1155_mocks::{CamelERC1155PanicMock, SnakeERC1155PanicMock};
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::token::test_erc1155::{setup_account, setup_receiver};
use openzeppelin::tests::utils::constants::{
    DATA, OWNER, RECIPIENT, OPERATOR, TOKEN_ID, TOKEN_ID_2, TOKEN_VALUE
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc1155::dual1155::{DualCaseERC1155, DualCaseERC1155Trait};
use openzeppelin::token::erc1155::interface::IERC1155_ID;
use openzeppelin::token::erc1155::interface::{
    IERC1155CamelDispatcher, IERC1155CamelDispatcherTrait
};
use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;
use starknet::testing;

//
// Setup
//

fn setup_snake() -> (DualCaseERC1155, IERC1155Dispatcher, ContractAddress) {
    let uri: ByteArray = "URI";
    let owner = setup_account();
    let mut calldata = array![];
    calldata.append_serde(owner);
    calldata.append_serde(TOKEN_ID);
    calldata.append_serde(TOKEN_VALUE);
    calldata.append_serde(uri);
    let target = utils::deploy(SnakeERC1155Mock::TEST_CLASS_HASH, calldata);
    (
        DualCaseERC1155 { contract_address: target },
        IERC1155Dispatcher { contract_address: target },
        owner
    )
}

fn setup_camel() -> (DualCaseERC1155, IERC1155CamelDispatcher, ContractAddress) {
    let uri: ByteArray = "URI";
    let owner = setup_account();
    let mut calldata = array![];
    calldata.append_serde(owner);
    calldata.append_serde(TOKEN_ID);
    calldata.append_serde(TOKEN_VALUE);
    calldata.append_serde(uri);
    let target = utils::deploy(CamelERC1155Mock::TEST_CLASS_HASH, calldata);
    (
        DualCaseERC1155 { contract_address: target },
        IERC1155CamelDispatcher { contract_address: target },
        owner
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

//
// Case agnostic methods
//

#[test]
fn test_dual_uri() {
    let (snake_dispatcher, _, _) = setup_snake();
    let (camel_dispatcher, _, _) = setup_camel();
    assert_eq!(snake_dispatcher.uri(TOKEN_ID), "URI");
    assert_eq!(camel_dispatcher.uri(TOKEN_ID), "URI");
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_uri() {
    let dispatcher = setup_non_erc1155();
    dispatcher.uri(TOKEN_ID);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
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
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_balance_of() {
    let dispatcher = setup_non_erc1155();
    dispatcher.balance_of(OWNER(), TOKEN_ID);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
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
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_balance_of_batch() {
    let dispatcher = setup_non_erc1155();
    let (accounts, token_ids) = get_accounts_and_ids();
    dispatcher.balance_of_batch(accounts, token_ids);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_balance_of_batch_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_panic();
    let (accounts, token_ids) = get_accounts_and_ids();
    dispatcher.balance_of_batch(accounts, token_ids);
}

#[test]
fn test_dual_safe_transfer_from() {
    let (dispatcher, target, owner) = setup_snake();
    let receiver = setup_receiver();
    testing::set_contract_address(owner);
    dispatcher.safe_transfer_from(owner, receiver, TOKEN_ID, TOKEN_VALUE, DATA(true));
    assert_eq!(target.balance_of(receiver, TOKEN_ID), TOKEN_VALUE);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_safe_transfer_from() {
    let dispatcher = setup_non_erc1155();
    dispatcher.safe_transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, TOKEN_VALUE, DATA(true));
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_safe_transfer_from_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_panic();
    dispatcher.safe_transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, TOKEN_VALUE, DATA(true));
}

#[test]
fn test_dual_safe_batch_transfer_from() {
    let (dispatcher, target, owner) = setup_snake();
    let token_ids = array![TOKEN_ID, TOKEN_ID_2].span();
    let values = array![TOKEN_VALUE, 0].span();
    let receiver = setup_receiver();
    testing::set_contract_address(owner);

    dispatcher.safe_batch_transfer_from(owner, receiver, token_ids, values, DATA(true));
    assert_eq!(target.balance_of(receiver, TOKEN_ID), TOKEN_VALUE);
    assert!(target.balance_of(receiver, TOKEN_ID_2).is_zero());
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_safe_batch_transfer_from() {
    let dispatcher = setup_non_erc1155();
    let token_ids = array![TOKEN_ID, TOKEN_ID_2].span();
    let values = array![TOKEN_VALUE, 0].span();
    dispatcher.safe_batch_transfer_from(OWNER(), RECIPIENT(), token_ids, values, DATA(true));
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_safe_batch_transfer_from_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_panic();
    let token_ids = array![TOKEN_ID, TOKEN_ID_2].span();
    let values = array![TOKEN_VALUE, 0].span();
    dispatcher.safe_batch_transfer_from(OWNER(), RECIPIENT(), token_ids, values, DATA(true));
}

#[test]
fn test_dual_is_approved_for_all() {
    let (dispatcher, target, _) = setup_snake();
    testing::set_contract_address(OWNER());
    target.set_approval_for_all(OPERATOR(), true);

    let is_approved_for_all = dispatcher.is_approved_for_all(OWNER(), OPERATOR());
    assert!(is_approved_for_all);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_is_approved_for_all() {
    let dispatcher = setup_non_erc1155();
    dispatcher.is_approved_for_all(OWNER(), OPERATOR());
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_is_approved_for_all_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_panic();
    dispatcher.is_approved_for_all(OWNER(), OPERATOR());
}

#[test]
fn test_dual_set_approval_for_all() {
    let (dispatcher, target, _) = setup_snake();
    testing::set_contract_address(OWNER());
    dispatcher.set_approval_for_all(OPERATOR(), true);

    let is_approved_for_all = target.is_approved_for_all(OWNER(), OPERATOR());
    assert!(is_approved_for_all);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_set_approval_for_all() {
    let dispatcher = setup_non_erc1155();
    dispatcher.set_approval_for_all(OPERATOR(), true);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
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
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_supports_interface() {
    let dispatcher = setup_non_erc1155();
    dispatcher.supports_interface(IERC1155_ID);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_supports_interface_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_panic();
    dispatcher.supports_interface(IERC1155_ID);
}

//
// camelCase target
//

#[test]
fn test_dual_balanceOf() {
    let (dispatcher, _, owner) = setup_camel();
    assert_eq!(dispatcher.balance_of(owner, TOKEN_ID), TOKEN_VALUE);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_balanceOf_exists_and_panics() {
    let (_, dispatcher) = setup_erc1155_panic();
    dispatcher.balance_of(OWNER(), TOKEN_ID);
}

#[test]
fn test_dual_balanceOfBatch() {
    let (dispatcher, _, owner) = setup_camel();
    let accounts = array![owner, RECIPIENT()].span();
    let token_ids = array![TOKEN_ID, TOKEN_ID_2].span();

    let balances = dispatcher.balance_of_batch(accounts, token_ids);
    assert_eq!(*balances.at(0), TOKEN_VALUE);
    assert!((*balances.at(1)).is_zero());
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_balanceOfBatch_exists_and_panics() {
    let (_, dispatcher) = setup_erc1155_panic();
    let (accounts, token_ids) = get_accounts_and_ids();
    dispatcher.balance_of_batch(accounts, token_ids);
}

#[test]
fn test_dual_safeTransferFrom() {
    let (dispatcher, target, owner) = setup_camel();
    let receiver = setup_receiver();
    testing::set_contract_address(owner);
    dispatcher.safe_transfer_from(owner, receiver, TOKEN_ID, TOKEN_VALUE, DATA(true));
    assert_eq!(target.balanceOf(receiver, TOKEN_ID), TOKEN_VALUE);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_safeTransferFrom_exists_and_panics() {
    let (_, dispatcher) = setup_erc1155_panic();
    dispatcher.safe_transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, TOKEN_VALUE, DATA(true));
}

#[test]
fn test_dual_safeBatchTransferFrom() {
    let (dispatcher, target, owner) = setup_camel();
    let token_ids = array![TOKEN_ID, TOKEN_ID_2].span();
    let values = array![TOKEN_VALUE, 0].span();
    let receiver = setup_receiver();
    testing::set_contract_address(owner);

    dispatcher.safe_batch_transfer_from(owner, receiver, token_ids, values, DATA(true));
    assert_eq!(target.balanceOf(receiver, TOKEN_ID), TOKEN_VALUE);
    assert!(target.balanceOf(receiver, TOKEN_ID_2).is_zero());
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_safeBatchTransferFrom_exists_and_panics() {
    let (_, dispatcher) = setup_erc1155_panic();
    let token_ids = array![TOKEN_ID, TOKEN_ID_2].span();
    let values = array![TOKEN_VALUE, 0].span();
    dispatcher.safe_batch_transfer_from(OWNER(), RECIPIENT(), token_ids, values, DATA(true));
}

#[test]
fn test_dual_isApprovedForAll() {
    let (dispatcher, target, _) = setup_camel();
    testing::set_contract_address(OWNER());
    target.setApprovalForAll(OPERATOR(), true);

    let is_approved_for_all = dispatcher.is_approved_for_all(OWNER(), OPERATOR());
    assert!(is_approved_for_all);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_isApprovedForAll_exists_and_panics() {
    let (_, dispatcher) = setup_erc1155_panic();
    dispatcher.is_approved_for_all(OWNER(), OPERATOR());
}

#[test]
fn test_dual_setApprovalForAll() {
    let (dispatcher, target, _) = setup_camel();
    testing::set_contract_address(OWNER());
    dispatcher.set_approval_for_all(OPERATOR(), true);

    let is_approved_for_all = target.isApprovedForAll(OWNER(), OPERATOR());
    assert!(is_approved_for_all);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
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
