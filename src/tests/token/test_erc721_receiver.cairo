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
#[available_gas(20000000)]
fn test_initializer() {
    let mut state = STATE();
    state.erc721_receiver.initializer();
    assert(state.src5.supports_interface(IERC721_RECEIVER_ID), 'Missing interface ID');
    assert(state.src5.supports_interface(ISRC5_ID), 'Missing interface ID');
}

#[test]
#[available_gas(20000000)]
fn test_on_erc721_received() {
    let mut state = STATE();
    let data = array![];
    assert(
        state
            .erc721_receiver
            .on_erc721_received(OPERATOR(), OWNER(), TOKEN_ID, data.span()) == IERC721_RECEIVER_ID,
        'Should return receiver ID'
    );
    assert(
        state
            .erc721_receiver
            .onERC721Received(OPERATOR(), OWNER(), TOKEN_ID, data.span()) == IERC721_RECEIVER_ID,
        'Should return receiver ID'
    );
}
