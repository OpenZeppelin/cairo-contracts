use core::array::ArrayTrait;
use openzeppelin::tests::mocks::erc1155_receiver_mocks::{
    CamelERC1155ReceiverMock, CamelERC1155ReceiverPanicMock, SnakeERC1155ReceiverMock,
    SnakeERC1155ReceiverPanicMock
};
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::utils::constants::{DATA, OPERATOR, OWNER, TOKEN_ID, TOKEN_VALUE};
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
    let mut calldata = ArrayTrait::new();
    let target = utils::deploy(SnakeERC1155ReceiverMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseERC1155Receiver { contract_address: target },
        IERC1155ReceiverDispatcher { contract_address: target }
    )
}

fn setup_camel() -> (DualCaseERC1155Receiver, IERC1155ReceiverCamelDispatcher) {
    let mut calldata = ArrayTrait::new();
    let target = utils::deploy(CamelERC1155ReceiverMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseERC1155Receiver { contract_address: target },
        IERC1155ReceiverCamelDispatcher { contract_address: target }
    )
}

fn setup_non_erc1155_receiver() -> DualCaseERC1155Receiver {
    let calldata = ArrayTrait::new();
    let target = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, calldata);
    DualCaseERC1155Receiver { contract_address: target }
}

fn setup_erc1155_receiver_panic() -> (DualCaseERC1155Receiver, DualCaseERC1155Receiver) {
    let snake_target = utils::deploy(
        SnakeERC1155ReceiverPanicMock::TEST_CLASS_HASH, ArrayTrait::new()
    );
    let camel_target = utils::deploy(
        CamelERC1155ReceiverPanicMock::TEST_CLASS_HASH, ArrayTrait::new()
    );
    (
        DualCaseERC1155Receiver { contract_address: snake_target },
        DualCaseERC1155Receiver { contract_address: camel_target }
    )
}

//
// snake_case target
//

#[test]
#[available_gas(2000000)]
fn test_dual_on_erc1155_received() {
    let (dispatcher, _) = setup_snake();
    assert(
        dispatcher
            .on_erc1155_received(
                OPERATOR(), OWNER(), TOKEN_ID, TOKEN_VALUE, DATA(true)
            ) == IERC1155_RECEIVER_ID,
        'Should return interface id'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_on_erc1155_received() {
    let dispatcher = setup_non_erc1155_receiver();
    dispatcher.on_erc1155_received(OPERATOR(), OWNER(), TOKEN_ID, TOKEN_VALUE, DATA(true));
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED',))]
fn test_dual_on_erc1155_received_exists_and_panics() {
    let (dispatcher, _) = setup_erc1155_receiver_panic();
    dispatcher.on_erc1155_received(OPERATOR(), OWNER(), TOKEN_ID, TOKEN_VALUE, DATA(true));
}

#[test]
#[available_gas(2000000)]
fn test_dual_on_erc1155_batch_received() {
    let (dispatcher, _) = setup_snake();
    let token_ids = array![TOKEN_ID, TOKEN_ID];
    let values = array![TOKEN_VALUE, TOKEN_VALUE];
    assert(
        dispatcher
            .on_erc1155_batch_received(
                OPERATOR(), OWNER(), token_ids.span(), values.span(), DATA(true)
            ) == IERC1155_RECEIVER_ID,
        'Should return interface id'
    );
}


//
// camelCase target
//

#[test]
#[available_gas(2000000)]
fn test_dual_onERC1155Received() {
    let (dispatcher, _) = setup_camel();
    assert(
        dispatcher
            .on_erc1155_received(
                OPERATOR(), OWNER(), TOKEN_ID, TOKEN_VALUE, DATA(true)
            ) == IERC1155_RECEIVER_ID,
        'Should return interface id'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED',))]
fn test_dual_onERC1155Received_exists_and_panics() {
    let (_, dispatcher) = setup_erc1155_receiver_panic();
    dispatcher.on_erc1155_received(OPERATOR(), OWNER(), TOKEN_ID, TOKEN_VALUE, DATA(true));
}

#[test]
#[available_gas(2000000)]
fn test_dual_onERC1155BatchReceived() {
    let (dispatcher, _) = setup_camel();
    let token_ids = array![TOKEN_ID, TOKEN_ID];
    let values = array![TOKEN_VALUE, TOKEN_VALUE];
    assert(
        dispatcher
            .on_erc1155_batch_received(
                OPERATOR(), OWNER(), token_ids.span(), values.span(), DATA(true)
            ) == IERC1155_RECEIVER_ID,
        'Should return interface id'
    );
}

