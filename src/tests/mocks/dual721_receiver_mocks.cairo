use openzeppelin::introspection::src5::SRC5;
use openzeppelin::tests::mocks::erc721_receiver::ERC721Receiver::IERC721_RECEIVER_ID;
use openzeppelin::tests::mocks::erc721_receiver::ERC721Receiver;

#[starknet::contract]
mod SnakeERC721ReceiverMock {
    use openzeppelin::introspection::src5::SRC5 as src5_component;
    use starknet::ContractAddress;
    use super::ERC721Receiver;
    use super::IERC721_RECEIVER_ID;

    component!(path: src5_component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC5Impl = src5_component::SRC5Impl<ContractState>;
    impl InternalImpl = src5_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: src5_component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: src5_component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.src5.register_interface(IERC721_RECEIVER_ID);
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
}

#[starknet::contract]
mod CamelERC721ReceiverMock {
    use openzeppelin::introspection::src5::SRC5 as src5_component;
    use starknet::ContractAddress;
    use super::ERC721Receiver;
    use super::IERC721_RECEIVER_ID;

    component!(path: src5_component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC5CamelImpl = src5_component::SRC5CamelImpl<ContractState>;
    impl InternalImpl = src5_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: src5_component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: src5_component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.src5.register_interface(IERC721_RECEIVER_ID);
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
