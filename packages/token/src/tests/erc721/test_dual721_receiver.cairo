use crate::erc721::dual721_receiver::{DualCaseERC721Receiver, DualCaseERC721ReceiverTrait};
use crate::erc721::interface::{
    IERC721ReceiverDispatcher, IERC721ReceiverCamelDispatcher, IERC721_RECEIVER_ID
};
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{DATA, OPERATOR, OWNER, TOKEN_ID};

//
// Setup
//

fn setup_snake() -> (DualCaseERC721Receiver, IERC721ReceiverDispatcher) {
    let calldata = array![];
    let target = utils::declare_and_deploy("SnakeERC721ReceiverMock", calldata);
    (
        DualCaseERC721Receiver { contract_address: target },
        IERC721ReceiverDispatcher { contract_address: target }
    )
}

fn setup_camel() -> (DualCaseERC721Receiver, IERC721ReceiverCamelDispatcher) {
    let calldata = array![];
    let target = utils::declare_and_deploy("CamelERC721ReceiverMock", calldata);
    (
        DualCaseERC721Receiver { contract_address: target },
        IERC721ReceiverCamelDispatcher { contract_address: target }
    )
}

fn setup_non_erc721_receiver() -> DualCaseERC721Receiver {
    let calldata = array![];
    let target = utils::declare_and_deploy("NonImplementingMock", calldata);
    DualCaseERC721Receiver { contract_address: target }
}

fn setup_erc721_receiver_panic() -> (DualCaseERC721Receiver, DualCaseERC721Receiver) {
    let snake_target = utils::declare_and_deploy("SnakeERC721ReceiverPanicMock", array![]);
    let camel_target = utils::declare_and_deploy("CamelERC721ReceiverPanicMock", array![]);
    (
        DualCaseERC721Receiver { contract_address: snake_target },
        DualCaseERC721Receiver { contract_address: camel_target }
    )
}

//
// snake_case target
//

#[test]
fn test_dual_on_erc721_received() {
    let (dispatcher, _) = setup_snake();

    let on_erc721_received = dispatcher
        .on_erc721_received(OPERATOR(), OWNER(), TOKEN_ID, DATA(true));
    assert_eq!(on_erc721_received, IERC721_RECEIVER_ID);
}

#[test]
#[ignore] // REASON: should_panic attribute not fit for complex panic messages.
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_on_erc721_received() {
    let dispatcher = setup_non_erc721_receiver();
    dispatcher.on_erc721_received(OPERATOR(), OWNER(), TOKEN_ID, DATA(true));
}

#[test]
#[should_panic(expected: ("Some error",))]
fn test_dual_on_erc721_received_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_receiver_panic();
    dispatcher.on_erc721_received(OPERATOR(), OWNER(), TOKEN_ID, DATA(true));
}

//
// camelCase target
//

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
fn test_dual_onERC721Received() {
    let (dispatcher, _) = setup_camel();

    let on_erc721_received = dispatcher
        .on_erc721_received(OPERATOR(), OWNER(), TOKEN_ID, DATA(true));
    assert_eq!(on_erc721_received, IERC721_RECEIVER_ID);
}

#[test]
#[ignore] // REASON: foundry entrypoint_not_found error message inconsistent with mainnet.
#[should_panic(expected: ("Some error",))]
fn test_dual_onERC721Received_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_receiver_panic();
    dispatcher.on_erc721_received(OPERATOR(), OWNER(), TOKEN_ID, DATA(true));
}
