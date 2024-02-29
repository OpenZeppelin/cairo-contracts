use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin::tests::mocks::erc721_receiver_mocks::DualCaseERC721ReceiverMock;
use openzeppelin::tests::utils::constants::{OWNER, OPERATOR, TOKEN_ID};
use openzeppelin::token::erc721::ERC721ReceiverComponent::{
    ERC721ReceiverImpl, ERC721ReceiverCamelImpl, InternalImpl
};
use openzeppelin::token::erc721::interface::IERC721_RECEIVER_ID;

fn STATE() -> DualCaseERC721ReceiverMock::ContractState {
    DualCaseERC721ReceiverMock::contract_state_for_testing()
}

#[test]
fn test_initializer() {
    let mut state = STATE();
    state.erc721_receiver.initializer();

    let supports_ierc721_receiver = state.src5.supports_interface(IERC721_RECEIVER_ID);
    assert!(supports_ierc721_receiver);

    let supports_isrc5 = state.src5.supports_interface(ISRC5_ID);
    assert!(supports_isrc5);
}

#[test]
fn test_on_erc721_received() {
    let mut state = STATE();
    let data = array![];

    let on_erc721_received = state
        .erc721_receiver
        .on_erc721_received(OPERATOR(), OWNER(), TOKEN_ID, data.span());
    assert_eq!(on_erc721_received, IERC721_RECEIVER_ID, "Should return receiver ID");

    let onERC721Received = state
        .erc721_receiver
        .onERC721Received(OPERATOR(), OWNER(), TOKEN_ID, data.span());
    assert_eq!(onERC721Received, IERC721_RECEIVER_ID, "Should return receiver ID");
}
