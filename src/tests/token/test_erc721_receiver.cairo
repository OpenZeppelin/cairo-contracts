use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::introspection::src5::SRC5Component::SRC5Impl;
use openzeppelin::tests::mocks::erc721_receiver_mocks::DualCaseERC721ReceiverMock;
use openzeppelin::tests::utils::constants::{OWNER, OPERATOR, TOKEN_ID, DATA};
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
    assert(state.src5.supports_interface(IERC721_RECEIVER_ID), 'Missing interface ID');
    assert(state.src5.supports_interface(ISRC5_ID), 'Missing interface ID');
}

#[test]
fn test_on_erc721_received() {
    let mut state = STATE();
    //let data: ByteArray = "";
    assert(
        state
            .erc721_receiver
            .on_erc721_received(OPERATOR(), OWNER(), TOKEN_ID, DATA(true)) == IERC721_RECEIVER_ID,
        'Should return receiver ID'
    );
    assert(
        state
            .erc721_receiver
            .onERC721Received(OPERATOR(), OWNER(), TOKEN_ID, DATA(true)) == IERC721_RECEIVER_ID,
        'Should return receiver ID'
    );
}
