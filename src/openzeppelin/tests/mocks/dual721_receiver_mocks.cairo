use openzeppelin::introspection::src5::SRC5;
use openzeppelin::tests::mocks::erc721_receiver::ERC721Receiver;
use openzeppelin::tests::mocks::erc721_receiver::ERC721Receiver::IERC721_RECEIVER_ID;

#[starknet::contract]
mod SnakeERC721ReceiverMock {
    use starknet::ContractAddress;
    use super::ERC721Receiver;
    use super::IERC721_RECEIVER_ID;
    use super::SRC5;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState) {
        let mut unsafe_state = SRC5::unsafe_new_contract_state();
        SRC5::InternalImpl::register_interface(ref unsafe_state, IERC721_RECEIVER_ID);
    }

    #[external(v0)]
    fn on_erc721_received(
        self: @ContractState,
        operator: ContractAddress,
        from: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    ) -> felt252 {
        let unsafe_state = ERC721Receiver::unsafe_new_contract_state();
        ERC721Receiver::on_erc721_received(@unsafe_state, operator, from, token_id, data)
    }

    #[external(v0)]
    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
        let unsafe_state = ERC721Receiver::unsafe_new_contract_state();
        ERC721Receiver::supports_interface(@unsafe_state, interface_id)
    }
}

#[starknet::contract]
mod CamelERC721ReceiverMock {
    use starknet::ContractAddress;
    use super::ERC721Receiver;
    use super::IERC721_RECEIVER_ID;
    use super::SRC5;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState) {
        let mut unsafe_state = SRC5::unsafe_new_contract_state();
        SRC5::InternalImpl::register_interface(ref unsafe_state, IERC721_RECEIVER_ID);
    }

    #[external(v0)]
    fn onERC721Received(
        self: @ContractState,
        operator: ContractAddress,
        from: ContractAddress,
        tokenId: u256,
        data: Span<felt252>
    ) -> felt252 {
        let unsafe_state = ERC721Receiver::unsafe_new_contract_state();
        ERC721Receiver::on_erc721_received(@unsafe_state, operator, from, tokenId, data)
    }

    #[external(v0)]
    fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
        let unsafe_state = ERC721Receiver::unsafe_new_contract_state();
        ERC721Receiver::supportsInterface(@unsafe_state, interfaceId)
    }
}

#[starknet::contract]
mod SnakeERC721ReceiverPanicMock {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn on_erc721_received(
        self: @ContractState,
        operator: ContractAddress,
        from: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    ) -> felt252 {
        panic_with_felt252('Some error');
        3
    }
}

#[starknet::contract]
mod CamelERC721ReceiverPanicMock {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn onERC721Received(
        self: @ContractState,
        operator: ContractAddress,
        from: ContractAddress,
        tokenId: u256,
        data: Span<felt252>
    ) -> felt252 {
        panic_with_felt252('Some error');
        3
    }
}
