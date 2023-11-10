use openzeppelin::tests::mocks::erc721_receiver_mocks::{
    CamelERC721ReceiverMock, CamelERC721ReceiverPanicMock
};
use openzeppelin::tests::mocks::erc721_receiver_mocks::{
    SnakeERC721ReceiverMock, SnakeERC721ReceiverPanicMock
};
use openzeppelin::tests::mocks::non_implementing_mock::NonImplementingMock;
use openzeppelin::tests::utils::constants::{DATA, OPERATOR, OWNER, TOKEN_ID};
use openzeppelin::tests::utils;
use openzeppelin::token::erc721::dual721_receiver::{
    DualCaseERC721Receiver, DualCaseERC721ReceiverTrait
};
use openzeppelin::token::erc721::interface::IERC721_RECEIVER_ID;
use openzeppelin::token::erc721::interface::{
    IERC721ReceiverCamelDispatcher, IERC721ReceiverCamelDispatcherTrait
};
use openzeppelin::token::erc721::interface::{
    IERC721ReceiverDispatcher, IERC721ReceiverDispatcherTrait
};

//
// Setup
//

fn setup_snake() -> (DualCaseERC721Receiver, IERC721ReceiverDispatcher) {
    let mut calldata = ArrayTrait::new();
    let target = utils::deploy(SnakeERC721ReceiverMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseERC721Receiver { contract_address: target },
        IERC721ReceiverDispatcher { contract_address: target }
    )
}

fn setup_camel() -> (DualCaseERC721Receiver, IERC721ReceiverCamelDispatcher) {
    let mut calldata = ArrayTrait::new();
    let target = utils::deploy(CamelERC721ReceiverMock::TEST_CLASS_HASH, calldata);
    (
        DualCaseERC721Receiver { contract_address: target },
        IERC721ReceiverCamelDispatcher { contract_address: target }
    )
}

fn setup_non_erc721_receiver() -> DualCaseERC721Receiver {
    let calldata = ArrayTrait::new();
    let target = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, calldata);
    DualCaseERC721Receiver { contract_address: target }
}

fn setup_erc721_receiver_panic() -> (DualCaseERC721Receiver, DualCaseERC721Receiver) {
    let snake_target = utils::deploy(
        SnakeERC721ReceiverPanicMock::TEST_CLASS_HASH, ArrayTrait::new()
    );
    let camel_target = utils::deploy(
        CamelERC721ReceiverPanicMock::TEST_CLASS_HASH, ArrayTrait::new()
    );
    (
        DualCaseERC721Receiver { contract_address: snake_target },
        DualCaseERC721Receiver { contract_address: camel_target }
    )
}

//
// snake_case target
//

#[test]
#[available_gas(2000000)]
fn test_dual_on_erc721_received() {
    let (dispatcher, _) = setup_snake();
    assert(
        dispatcher
            .on_erc721_received(OPERATOR(), OWNER(), TOKEN_ID, DATA(true)) == IERC721_RECEIVER_ID,
        'Should return interface id'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_dual_no_on_erc721_received() {
    let dispatcher = setup_non_erc721_receiver();
    dispatcher.on_erc721_received(OPERATOR(), OWNER(), TOKEN_ID, DATA(true));
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED',))]
fn test_dual_on_erc721_received_exists_and_panics() {
    let (dispatcher, _) = setup_erc721_receiver_panic();
    dispatcher.on_erc721_received(OPERATOR(), OWNER(), TOKEN_ID, DATA(true));
}

//
// camelCase target
//

#[test]
#[available_gas(2000000)]
fn test_dual_onERC721Received() {
    let (dispatcher, _) = setup_camel();
    assert(
        dispatcher
            .on_erc721_received(OPERATOR(), OWNER(), TOKEN_ID, DATA(true)) == IERC721_RECEIVER_ID,
        'Should return interface id'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Some error', 'ENTRYPOINT_FAILED',))]
fn test_dual_onERC721Received_exists_and_panics() {
    let (_, dispatcher) = setup_erc721_receiver_panic();
    dispatcher.on_erc721_received(OPERATOR(), OWNER(), TOKEN_ID, DATA(true));
}
