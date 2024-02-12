use openzeppelin::tests::utils::constants::SUCCESS;

#[starknet::contract]
mod DualCaseERC1155ReceiverMock {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::ERC1155ReceiverComponent;
    use starknet::ContractAddress;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(
        path: ERC1155ReceiverComponent, storage: erc1155_receiver, event: ERC1155ReceiverEvent
    );

    // ERC1155Receiver
    impl ERC1155ReceiverImpl = ERC1155ReceiverComponent::ERC1155ReceiverImpl<ContractState>;
    impl ERC1155ReceiverInternalImpl = ERC1155ReceiverComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc1155_receiver: ERC1155ReceiverComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC1155ReceiverEvent: ERC1155ReceiverComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc1155_receiver.initializer();
    }

    #[external(v0)]
    fn on_erc1155_received(
        self: @ContractState,
        operator: ContractAddress,
        from: ContractAddress,
        token_id: u256,
        value: u256,
        data: Span<felt252>
    ) -> felt252 {
        if *data.at(0) == super::SUCCESS {
            self.erc1155_receiver.on_erc1155_received(operator, from, token_id, value, data)
        } else {
            0
        }
    }

    #[external(v0)]
    fn on_erc1155_batch_received(
        self: @ContractState,
        operator: ContractAddress,
        from: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>
    ) -> felt252 {
        if *data.at(0) == super::SUCCESS {
            self.erc1155_receiver.on_erc1155_batch_received(operator, from, token_ids, values, data)
        } else {
            0
        }
    }
}

#[starknet::contract]
mod SnakeERC1155ReceiverMock {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::ERC1155ReceiverComponent;
    use starknet::ContractAddress;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(
        path: ERC1155ReceiverComponent, storage: erc1155_receiver, event: ERC1155ReceiverEvent
    );

    // ERC1155Receiver
    impl ERC1155ReceiverImpl = ERC1155ReceiverComponent::ERC1155ReceiverImpl<ContractState>;
    impl ERC1155ReceiverInternalImpl = ERC1155ReceiverComponent::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc1155_receiver: ERC1155ReceiverComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC1155ReceiverEvent: ERC1155ReceiverComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc1155_receiver.initializer();
    }

    #[external(v0)]
    fn on_erc1155_received(
        self: @ContractState,
        operator: ContractAddress,
        from: ContractAddress,
        token_id: u256,
        value: u256,
        data: Span<felt252>
    ) -> felt252 {
        if *data.at(0) == super::SUCCESS {
            self.erc1155_receiver.on_erc1155_received(operator, from, token_id, value, data)
        } else {
            0
        }
    }

    #[external(v0)]
    fn on_erc1155_batch_received(
        self: @ContractState,
        operator: ContractAddress,
        from: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>
    ) -> felt252 {
        if *data.at(0) == super::SUCCESS {
            self.erc1155_receiver.on_erc1155_batch_received(operator, from, token_ids, values, data)
        } else {
            0
        }
    }
}

#[starknet::contract]
mod CamelERC1155ReceiverMock {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::ERC1155ReceiverComponent;
    use starknet::ContractAddress;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(
        path: ERC1155ReceiverComponent, storage: erc1155_receiver, event: ERC1155ReceiverEvent
    );

    // ERC1155Receiver
    impl ERC1155ReceiverCamelImpl =
        ERC1155ReceiverComponent::ERC1155ReceiverCamelImpl<ContractState>;
    impl ERC1155ReceiverInternalImpl = ERC1155ReceiverComponent::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc1155_receiver: ERC1155ReceiverComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC1155ReceiverEvent: ERC1155ReceiverComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc1155_receiver.initializer();
    }

    #[external(v0)]
    fn onERC1155Received(
        self: @ContractState,
        operator: ContractAddress,
        from: ContractAddress,
        tokenId: u256,
        value: u256,
        data: Span<felt252>
    ) -> felt252 {
        if *data.at(0) == super::SUCCESS {
            self.erc1155_receiver.onERC1155Received(operator, from, tokenId, value, data)
        } else {
            0
        }
    }

    #[external(v0)]
    fn onERC1155BatchReceived(
        self: @ContractState,
        operator: ContractAddress,
        from: ContractAddress,
        tokenIds: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>
    ) -> felt252 {
        if *data.at(0) == super::SUCCESS {
            self.erc1155_receiver.onERC1155BatchReceived(operator, from, tokenIds, values, data)
        } else {
            0
        }
    }
}

#[starknet::contract]
mod SnakeERC1155ReceiverPanicMock {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn on_erc1155_received(
        self: @ContractState,
        operator: ContractAddress,
        from: ContractAddress,
        token_id: u256,
        value: u256,
        data: Span<felt252>
    ) -> felt252 {
        panic_with_felt252('Some error');
        3
    }
}

#[starknet::contract]
mod CamelERC1155ReceiverPanicMock {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn onERC1155Received(
        self: @ContractState,
        operator: ContractAddress,
        from: ContractAddress,
        tokenId: u256,
        value: u256,
        data: Span<felt252>
    ) -> felt252 {
        panic_with_felt252('Some error');
        3
    }
}
