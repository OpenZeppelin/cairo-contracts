use openzeppelin::introspection::src5::SRC5;
use openzeppelin::tests::mocks::erc721_receiver::ERC721Receiver;
use openzeppelin::tests::mocks::erc721_receiver::ERC721Receiver::IERC721_RECEIVER_ID;

#[contract]
mod SnakeERC721ReceiverMock {
    use openzeppelin::utils::serde::SpanSerde;
    use starknet::ContractAddress;
    use super::ERC721Receiver;
    use super::IERC721_RECEIVER_ID;
    use super::SRC5;

    #[constructor]
    fn constructor() {
        SRC5::register_interface(IERC721_RECEIVER_ID);
    }

    #[view]
    fn on_erc721_received(
        operator: ContractAddress, from: ContractAddress, token_id: u256, data: Span<felt252>
    ) -> felt252 {
        ERC721Receiver::on_erc721_received(operator, from, token_id, data)
    }

    #[view]
    fn supports_interface(interface_id: felt252) -> bool {
        ERC721Receiver::supports_interface(interface_id)
    }
}

#[contract]
mod CamelERC721ReceiverMock {
    use openzeppelin::utils::serde::SpanSerde;
    use starknet::ContractAddress;
    use super::ERC721Receiver;
    use super::IERC721_RECEIVER_ID;
    use super::SRC5;

    #[constructor]
    fn constructor() {
        SRC5::register_interface(IERC721_RECEIVER_ID);
    }

    #[view]
    fn onERC721Received(
        operator: ContractAddress, from: ContractAddress, tokenId: u256, data: Span<felt252>
    ) -> felt252 {
        ERC721Receiver::on_erc721_received(operator, from, tokenId, data)
    }

    #[view]
    fn supportsInterface(interfaceId: felt252) -> bool {
        ERC721Receiver::supportsInterface(interfaceId)
    }
}

#[contract]
mod SnakeERC721ReceiverPanicMock {
    use openzeppelin::utils::serde::SpanSerde;
    use starknet::ContractAddress;

    #[view]
    fn on_erc721_received(
        operator: ContractAddress, from: ContractAddress, token_id: u256, data: Span<felt252>
    ) -> felt252 {
        panic_with_felt252('Some error');
        3
    }
}

#[contract]
mod CamelERC721ReceiverPanicMock {
    use openzeppelin::utils::serde::SpanSerde;
    use starknet::ContractAddress;

    #[view]
    fn onERC721Received(
        operator: ContractAddress, from: ContractAddress, tokenId: u256, data: Span<felt252>
    ) -> felt252 {
        panic_with_felt252('Some error');
        3
    }
}
