use openzeppelin::tests::utils::constants::SUCCESS;

#[starknet::contract]
mod DualCaseERC721ReceiverMock {
    use openzeppelin::introspection::src5::SRC5 as src5_component;
    use openzeppelin::token::erc721::ERC721Receiver as erc721_receiver_component;
    use starknet::ContractAddress;

    component!(path: erc721_receiver_component, storage: erc721_receiver, event: ERC721ReceiverEvent);
    component!(path: src5_component, storage: src5, event: SRC5Event);

    // ERC721Receiver
    impl ERC721ReceiverImpl = erc721_receiver_component::ERC721ReceiverImpl<ContractState>;
    impl ERC721ReceiverInternalImpl = erc721_receiver_component::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = src5_component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721_receiver: erc721_receiver_component::Storage,
        #[substorage(v0)]
        src5: src5_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721ReceiverEvent: erc721_receiver_component::Event,
        #[flat]
        SRC5Event: src5_component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc721_receiver.initializer();
    }

    #[external(v0)]
    fn on_erc721_received(
        self: @ContractState,
        operator: ContractAddress,
        from: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    ) -> felt252 {
        if *data.at(0) == super::SUCCESS {
            self.erc721_receiver.on_erc721_received(operator, from, token_id, data)
        } else {
            0
        }
    }

    #[external(v0)]
    fn onERC721Received(
        self: @ContractState,
        operator: ContractAddress,
        from: ContractAddress,
        tokenId: u256,
        data: Span<felt252>
    ) -> felt252 {
        self.on_erc721_received(operator, from, tokenId, data)
    }
}

#[starknet::contract]
mod SnakeERC721ReceiverMock {
    use openzeppelin::introspection::src5::SRC5 as src5_component;
    use openzeppelin::token::erc721::ERC721Receiver as erc721_receiver_component;
    use starknet::ContractAddress;

    component!(path: erc721_receiver_component, storage: erc721_receiver, event: ERC721ReceiverEvent);
    component!(path: src5_component, storage: src5, event: SRC5Event);

    // ERC721Receiver
    impl ERC721ReceiverImpl = erc721_receiver_component::ERC721ReceiverImpl<ContractState>;
    impl ERC721ReceiverInternalImpl = erc721_receiver_component::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = src5_component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721_receiver: erc721_receiver_component::Storage,
        #[substorage(v0)]
        src5: src5_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721ReceiverEvent: erc721_receiver_component::Event,
        #[flat]
        SRC5Event: src5_component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc721_receiver.initializer();
    }

    #[external(v0)]
    fn on_erc721_received(
        self: @ContractState,
        operator: ContractAddress,
        from: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    ) -> felt252 {
        if *data.at(0) == super::SUCCESS {
            self.erc721_receiver.on_erc721_received(operator, from, token_id, data)
        } else {
            0
        }
    }
}

#[starknet::contract]
mod CamelERC721ReceiverMock {
    use openzeppelin::introspection::src5::SRC5 as src5_component;
    use openzeppelin::token::erc721::ERC721Receiver as erc721_receiver_component;
    use starknet::ContractAddress;

    component!(path: erc721_receiver_component, storage: erc721_receiver, event: ERC721ReceiverEvent);
    component!(path: src5_component, storage: src5, event: SRC5Event);

    // ERC721Receiver
    impl ERC721ReceiverCamelImpl = erc721_receiver_component::ERC721ReceiverCamelImpl<ContractState>;
    impl ERC721ReceiverInternalImpl = erc721_receiver_component::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = src5_component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721_receiver: erc721_receiver_component::Storage,
        #[substorage(v0)]
        src5: src5_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721ReceiverEvent: erc721_receiver_component::Event,
        #[flat]
        SRC5Event: src5_component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc721_receiver.initializer();
    }

    #[external(v0)]
    fn onERC721Received(
        self: @ContractState,
        operator: ContractAddress,
        from: ContractAddress,
        tokenId: u256,
        data: Span<felt252>
    ) -> felt252 {
        if *data.at(0) == super::SUCCESS {
            self.erc721_receiver.onERC721Received(operator, from, tokenId, data)
        } else {
            0
        }
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



