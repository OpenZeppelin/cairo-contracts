use openzeppelin::tests::mocks::erc721_mocks::{CamelERC721Mock, SnakeERC721Mock};
use openzeppelin::tests::mocks::erc721_mocks::{CamelERC721PanicMock, SnakeERC721PanicMock};
use openzeppelin::tests::mocks::erc721_receiver_mocks::DualCaseERC721ReceiverMock;
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::utils::constants::{
    DATA, OWNER, RECIPIENT, SPENDER, OPERATOR, OTHER, NAME, SYMBOL, URI, TOKEN_ID
};
use openzeppelin::tests::utils;
use openzeppelin::token::erc721::dual721::{DualCaseERC721, DualCaseERC721Trait};
use openzeppelin::token::erc721::interface::IERC721_ID;
use openzeppelin::token::erc721::interface::{
    IERC721CamelOnlyDispatcher, IERC721CamelOnlyDispatcherTrait
};
use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::ContractAddress;
use starknet::testing::set_caller_address;
use starknet::testing::set_contract_address;

//
// Setup
//

fn setup_snake() -> (DualCaseERC721, IERC721Dispatcher) {
    let mut calldata = array![];
    calldata.append_serde(NAME);
    calldata.append_serde(SYMBOL);
    calldata.append_serde(OWNER());
    calldata.append_serde(TOKEN_ID);
    calldata.append_serde(URI);
    set_contract_address(OWNER());
    let target = utils::deploy(SnakeERC721Mock::TEST_CLASS_HASH, calldata);
    (DualCaseERC721 { contract_address: target }, IERC721Dispatcher { contract_address: target })
}

fn setup_camel() -> (DualCaseERC721, IERC721CamelOnlyDispatcher) {
    let mut calldata = array![];
    calldata.append_serde(NAME);
    calldata.append_serde(SYMBOL);
    calldata.append_serde(OWNER());
    calldata.append_serde(TOKEN_ID);
    calldata.append_serde(URI);
    set_contract_address(OWNER());
    let target = utils::deploy(CamelERC721Mock::TEST_CLASS_HASH, calldata);
    (
        DualCaseERC721 { contract_address: target },
        IERC721CamelOnlyDispatcher { contract_address: target }
    )
}

fn setup_non_erc721() -> DualCaseERC721 {
    let calldata = array![];
    let target = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, calldata);
    DualCaseERC721 { contract_address: target }
}

fn setup_erc721_panic() -> (DualCaseERC721, DualCaseERC721) {
    let snake_target = utils::deploy(SnakeERC721PanicMock::TEST_CLASS_HASH, array![]);
    let camel_target = utils::deploy(CamelERC721PanicMock::TEST_CLASS_HASH, array![]);
    (
        DualCaseERC721 { contract_address: snake_target },
        DualCaseERC721 { contract_address: camel_target }
    )
}

fn setup_receiver() -> ContractAddress {
    utils::deploy(DualCaseERC721ReceiverMock::TEST_CLASS_HASH, array![])
}

//
// Case agnostic methods
//

#[test]
fn test_dual_name() {
    let (snake_dispatcher, _) = setup_snake();
    let (camel_dispatcher, _) = setup_camel();
    assert_eq!(snake_dispatcher.name(), NAME);
    assert_eq!(camel_dispatcher.name(), NAME);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_name() {
    let dispatcher = setup_non_erc721();
    dispatcher.name();
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_name_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_panic();
    dispatcher.name();
}

#[test]
fn test_dual_symbol() {
    let (snake_dispatcher, _) = setup_snake();
    assert_eq!(snake_dispatcher.symbol(), SYMBOL);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_symbol() {
    let dispatcher = setup_non_erc721();
    dispatcher.symbol();
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_symbol_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_panic();
    dispatcher.symbol();
}

#[test]
fn test_dual_approve() {
    let (snake_dispatcher, snake_target) = setup_snake();
    set_contract_address(OWNER());
    snake_dispatcher.approve(SPENDER(), TOKEN_ID);
    assert_eq!(snake_target.get_approved(TOKEN_ID), SPENDER());

    let (camel_dispatcher, camel_target) = setup_camel();
    set_contract_address(OWNER());
    camel_dispatcher.approve(SPENDER(), TOKEN_ID);
    assert_eq!(camel_target.getApproved(TOKEN_ID), SPENDER());
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_approve() {
    let dispatcher = setup_non_erc721();
    dispatcher.approve(SPENDER(), TOKEN_ID);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
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
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_balance_of() {
    let dispatcher = setup_non_erc721();
    dispatcher.balance_of(OWNER());
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
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
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_owner_of() {
    let dispatcher = setup_non_erc721();
    dispatcher.owner_of(TOKEN_ID);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
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
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_transfer_from() {
    let dispatcher = setup_non_erc721();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
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
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_safe_transfer_from() {
    let dispatcher = setup_non_erc721();
    dispatcher.safe_transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, DATA(true));
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_safe_transfer_from_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_panic();
    dispatcher.safe_transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, DATA(true));
}

#[test]
fn test_dual_get_approved() {
    let (dispatcher, target) = setup_snake();
    set_contract_address(OWNER());
    target.approve(SPENDER(), TOKEN_ID);
    assert_eq!(dispatcher.get_approved(TOKEN_ID), SPENDER());
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_get_approved() {
    let dispatcher = setup_non_erc721();
    dispatcher.get_approved(TOKEN_ID);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_get_approved_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_panic();
    dispatcher.get_approved(TOKEN_ID);
}

#[test]
fn test_dual_set_approval_for_all() {
    let (dispatcher, target) = setup_snake();
    set_contract_address(OWNER());
    dispatcher.set_approval_for_all(OPERATOR(), true);

    let is_approved_for_all = target.is_approved_for_all(OWNER(), OPERATOR());
    assert!(is_approved_for_all);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_set_approval_for_all() {
    let dispatcher = setup_non_erc721();
    dispatcher.set_approval_for_all(OPERATOR(), true);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_set_approval_for_all_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_panic();
    dispatcher.set_approval_for_all(OPERATOR(), true);
}

#[test]
fn test_dual_is_approved_for_all() {
    let (dispatcher, target) = setup_snake();
    set_contract_address(OWNER());
    target.set_approval_for_all(OPERATOR(), true);

    let is_approved_for_all = dispatcher.is_approved_for_all(OWNER(), OPERATOR());
    assert!(is_approved_for_all);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_is_approved_for_all() {
    let dispatcher = setup_non_erc721();
    dispatcher.is_approved_for_all(OWNER(), OPERATOR());
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_is_approved_for_all_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_panic();
    dispatcher.is_approved_for_all(OWNER(), OPERATOR());
}

#[test]
fn test_dual_token_uri() {
    let (dispatcher, _) = setup_snake();
    assert_eq!(dispatcher.token_uri(TOKEN_ID), URI);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_token_uri() {
    let dispatcher = setup_non_erc721();
    dispatcher.token_uri(TOKEN_ID);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
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
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_supports_interface() {
    let dispatcher = setup_non_erc721();
    dispatcher.supports_interface(IERC721_ID);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_supports_interface_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_panic();
    dispatcher.supports_interface(IERC721_ID);
}

//
// camelCase target
//

#[test]
fn test_dual_balanceOf() {
    let (dispatcher, _) = setup_camel();
    assert_eq!(dispatcher.balance_of(OWNER()), 1);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_balanceOf_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_panic();
    dispatcher.balance_of(OWNER());
}

#[test]
fn test_dual_ownerOf() {
    let (dispatcher, _) = setup_camel();
    let current_owner = dispatcher.owner_of(TOKEN_ID);
    assert_eq!(current_owner, OWNER());
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_ownerOf_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_panic();
    dispatcher.owner_of(TOKEN_ID);
}

#[test]
fn test_dual_transferFrom() {
    let (dispatcher, target) = setup_camel();
    set_contract_address(OWNER());
    dispatcher.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID);

    let current_owner = target.ownerOf(TOKEN_ID);
    assert_eq!(current_owner, RECIPIENT());
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_transferFrom_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_panic();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), TOKEN_ID);
}

#[test]
fn test_dual_safeTransferFrom() {
    let (dispatcher, target) = setup_camel();
    let receiver = setup_receiver();
    dispatcher.safe_transfer_from(OWNER(), receiver, TOKEN_ID, DATA(true));

    let current_owner = target.ownerOf(TOKEN_ID);
    assert_eq!(current_owner, receiver);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_safeTransferFrom_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_panic();
    dispatcher.safe_transfer_from(OWNER(), RECIPIENT(), TOKEN_ID, DATA(true));
}

#[test]
fn test_dual_getApproved() {
    let (dispatcher, _) = setup_camel();
    set_contract_address(OWNER());
    dispatcher.approve(SPENDER(), TOKEN_ID);

    let approved = dispatcher.get_approved(TOKEN_ID);
    assert_eq!(approved, SPENDER());
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_getApproved_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_panic();
    dispatcher.get_approved(TOKEN_ID);
}

#[test]
fn test_dual_setApprovalForAll() {
    let (dispatcher, target) = setup_camel();
    set_contract_address(OWNER());
    dispatcher.set_approval_for_all(OPERATOR(), true);

    let is_approved_for_all = target.isApprovedForAll(OWNER(), OPERATOR());
    assert!(is_approved_for_all);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_setApprovalForAll_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_panic();
    dispatcher.set_approval_for_all(OPERATOR(), true);
}

#[test]
fn test_dual_isApprovedForAll() {
    let (dispatcher, target) = setup_camel();
    set_contract_address(OWNER());
    target.setApprovalForAll(OPERATOR(), true);

    let is_approved_for_all = dispatcher.is_approved_for_all(OWNER(), OPERATOR());
    assert!(is_approved_for_all);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_isApprovedForAll_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_panic();
    dispatcher.is_approved_for_all(OWNER(), OPERATOR());
}

#[test]
fn test_dual_tokenURI() {
    let (dispatcher, _) = setup_camel();
    let token_uri = dispatcher.token_uri(TOKEN_ID);
    assert_eq!(token_uri, URI);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_tokenURI_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_panic();
    dispatcher.token_uri(TOKEN_ID);
}

#[test]
fn test_dual_supportsInterface() {
    let (dispatcher, _) = setup_camel();
    let supports_ierc721 = dispatcher.supports_interface(IERC721_ID);
    assert!(supports_ierc721);
}

#[test]
#[should_panic(expected: ("Some error", 'ENTRYPOINT_FAILED',))]
fn test_dual_supportsInterface_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_panic();
    dispatcher.supports_interface(IERC721_ID);
}
