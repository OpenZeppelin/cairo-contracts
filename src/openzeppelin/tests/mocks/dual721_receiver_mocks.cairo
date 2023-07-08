#[contract]
mod SnakeERC721ReceiverMock {
    use starknet::ContractAddress;
    use openzeppelin::token::erc721::erc721_holder::ERC721Holder;
    use openzeppelin::utils::serde::SpanSerde;

    #[view]
    fn on_erc721_received(
        operator: ContractAddress, from: ContractAddress, token_id: u256, data: Span<felt252>
    ) -> felt252 {
        ERC721Holder::on_erc721_received(operator, from, token_id, data)
    }

    #[view]
    fn supports_interface(interface_id: felt252) -> bool {
        ERC721Holder::supports_interface(interface_id)
    }
}

#[contract]
mod CamelERC721ReceiverMock {
    use starknet::ContractAddress;
    use openzeppelin::token::erc721::erc721_holder::ERC721Holder;
    use openzeppelin::utils::serde::SpanSerde;

    #[view]
    fn onERC721Received(
        operator: ContractAddress, from: ContractAddress, tokenId: u256, data: Span<felt252>
    ) -> felt252 {
        ERC721Holder::on_erc721_received(operator, from, tokenId, data)
    }
}

#[contract]
mod SnakeERC721ReceiverPanicMock {
    use starknet::ContractAddress;
    use openzeppelin::utils::serde::SpanSerde;

    #[view]
    fn on_erc721_received(
        operator: ContractAddress, from: ContractAddress, token_id: u256, data: Span<felt252>
    ) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[view]
    fn supports_interface(interface_id: felt252) -> bool {
        panic_with_felt252('Some error');
        false
    }
}

#[contract]
mod CamelERC721ReceiverPanicMock {
    use starknet::ContractAddress;
    use openzeppelin::utils::serde::SpanSerde;

    #[view]
    fn onERC721Received(
        operator: ContractAddress, from: ContractAddress, tokenId: u256, data: Span<felt252>
    ) -> felt252 {
        panic_with_felt252('Some error');
        3
    }
}
