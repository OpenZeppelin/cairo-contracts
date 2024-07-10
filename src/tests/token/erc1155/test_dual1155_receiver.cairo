use openzeppelin::tests::utils::constants::{EMPTY_DATA, OPERATOR, OWNER, TOKEN_ID, TOKEN_VALUE};
use openzeppelin::tests::utils;
use openzeppelin::token::erc1155::dual1155_receiver::{
    DualCaseERC1155Receiver, DualCaseERC1155ReceiverTrait
};
use openzeppelin::token::erc1155::interface::IERC1155_RECEIVER_ID;
use openzeppelin::token::erc1155::interface::{
    IERC1155ReceiverCamelDispatcher, IERC1155ReceiverCamelDispatcherTrait
};
use openzeppelin::token::erc1155::interface::{
    IERC1155ReceiverDispatcher, IERC1155ReceiverDispatcherTrait
};

//
// Setup
//

fn setup_snake() -> (DualCaseERC1155Receiver, IERC1155ReceiverDispatcher) {
    let mut calldata = array![];
    let target = utils::declare_and_deploy("SnakeERC1155ReceiverMock", calldata);
    (
        DualCaseERC1155Receiver { contract_address: target },
        IERC1155ReceiverDispatcher { contract_address: target }
    )
}

fn setup_camel() -> (DualCaseERC1155Receiver, IERC1155ReceiverCamelDispatcher) {
    let mut calldata = array![];
    let target = utils::declare_and_deploy("CamelERC1155ReceiverMock", calldata);
    (
        DualCaseERC1155Receiver { contract_address: target },
        IERC1155ReceiverCamelDispatcher { contract_address: target }
    )
}

fn setup_non_erc1155_receiver() -> DualCaseERC1155Receiver {
    let calldata = array![];
    let target = utils::declare_and_deploy("NonImplementingMock", calldata);
    DualCaseERC1155Receiver { contract_address: target }
}

fn setup_erc1155_receiver_panic() -> (DualCaseERC1155Receiver, DualCaseERC1155Receiver) {
    let snake_target = utils::declare_and_deploy("SnakeERC1155ReceiverPanicMock", array![]);
    let camel_target = utils::declare_and_deploy("CamelERC1155ReceiverPanicMock", array![]);
    (
        DualCaseERC1155Receiver { contract_address: snake_target },
        DualCaseERC1155Receiver { contract_address: camel_target }
    )
}

//
// snake_case target
//

#[test]
#[ignore]
fn test_dual_on_erc1155_received() {
    let (dispatcher, _) = setup_snake();
    let result = dispatcher
        .on_erc1155_received(OPERATOR(), OWNER(), TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
    assert_eq!(result, IERC1155_RECEIVER_ID,);
}

#[test]
#[ignore]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_on_erc1155_received() {
    let dispatcher = setup_non_erc1155_receiver();
    dispatcher.on_erc1155_received(OPERATOR(), OWNER(), TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
}

#[test]
#[ignore]
#[should_panic(expected: ("Some error",))]
fn test_dual_on_erc1155_received_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_receiver_panic();
    dispatcher.on_erc1155_received(OPERATOR(), OWNER(), TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
}

#[test]
#[ignore]
fn test_dual_on_erc1155_batch_received() {
    let (dispatcher, _) = setup_snake();
    let (token_ids, values) = get_ids_and_values();

    let result = dispatcher
        .on_erc1155_batch_received(OPERATOR(), OWNER(), token_ids, values, EMPTY_DATA());
    assert_eq!(result, IERC1155_RECEIVER_ID);
}

#[test]
#[ignore]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_on_erc1155_batch_received() {
    let dispatcher = setup_non_erc1155_receiver();
    let (token_ids, values) = get_ids_and_values();
    dispatcher.on_erc1155_batch_received(OPERATOR(), OWNER(), token_ids, values, EMPTY_DATA());
}

#[test]
#[ignore]
#[should_panic(expected: ("Some error",))]
fn test_dual_on_erc1155_batch_received_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_receiver_panic();
    let (token_ids, values) = get_ids_and_values();
    dispatcher.on_erc1155_batch_received(OPERATOR(), OWNER(), token_ids, values, EMPTY_DATA());
}

//
// camelCase target
//

#[test]
#[ignore]
fn test_dual_onERC1155Received() {
    let (dispatcher, _) = setup_camel();
    let result = dispatcher
        .on_erc1155_received(OPERATOR(), OWNER(), TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
    assert_eq!(result, IERC1155_RECEIVER_ID);
}

#[test]
#[ignore]
#[should_panic(expected: ("Some error",))]
fn test_dual_onERC1155Received_exists_and_panics() {
    let (_, dispatcher) = setup_erc1155_receiver_panic();
    dispatcher.on_erc1155_received(OPERATOR(), OWNER(), TOKEN_ID, TOKEN_VALUE, EMPTY_DATA());
}

#[test]
#[ignore]
fn test_dual_onERC1155BatchReceived() {
    let (dispatcher, _) = setup_camel();
    let (token_ids, values) = get_ids_and_values();

    let result = dispatcher
        .on_erc1155_batch_received(OPERATOR(), OWNER(), token_ids, values, EMPTY_DATA());
    assert_eq!(result, IERC1155_RECEIVER_ID);
}

#[test]
#[ignore]
#[should_panic(expected: ("Some error",))]
fn test_dual_onERC1155BatchReceived_exists_and_panics() {
    let (_, dispatcher) = setup_erc1155_receiver_panic();
    let (token_ids, values) = get_ids_and_values();
    dispatcher.on_erc1155_batch_received(OPERATOR(), OWNER(), token_ids, values, EMPTY_DATA());
}

//
// Helpers
//

fn get_ids_and_values() -> (Span<u256>, Span<u256>) {
    let token_ids = array![TOKEN_ID, TOKEN_ID].span();
    let values = array![TOKEN_VALUE, TOKEN_VALUE].span();
    (token_ids, values)
}
