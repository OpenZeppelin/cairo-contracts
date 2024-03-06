use openzeppelin::tests::utils::constants::SUCCESS;

#[starknet::contract]
mod DualCaseERC721ReceiverMock {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721ReceiverComponent;
    use starknet::ContractAddress;

    component!(path: ERC721ReceiverComponent, storage: erc721_receiver, event: ERC721ReceiverEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721Receiver
    impl ERC721ReceiverImpl = ERC721ReceiverComponent::ERC721ReceiverImpl<ContractState>;
    impl ERC721ReceiverInternalImpl = ERC721ReceiverComponent::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721_receiver: ERC721ReceiverComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721ReceiverEvent: ERC721ReceiverComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc721_receiver.initializer();
    }

    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
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
            ExternalTrait::on_erc721_received(self, operator, from, tokenId, data)
        }
    }
}

#[starknet::contract]
mod SnakeERC721ReceiverMock {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721ReceiverComponent;
    use starknet::ContractAddress;

    component!(path: ERC721ReceiverComponent, storage: erc721_receiver, event: ERC721ReceiverEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721Receiver
    impl ERC721ReceiverImpl = ERC721ReceiverComponent::ERC721ReceiverImpl<ContractState>;
    impl ERC721ReceiverInternalImpl = ERC721ReceiverComponent::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721_receiver: ERC721ReceiverComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721ReceiverEvent: ERC721ReceiverComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc721_receiver.initializer();
    }

    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
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
}

#[starknet::contract]
mod CamelERC721ReceiverMock {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721ReceiverComponent;
    use starknet::ContractAddress;

    component!(path: ERC721ReceiverComponent, storage: erc721_receiver, event: ERC721ReceiverEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721Receiver
    impl ERC721ReceiverCamelImpl = ERC721ReceiverComponent::ERC721ReceiverCamelImpl<ContractState>;
    impl ERC721ReceiverInternalImpl = ERC721ReceiverComponent::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721_receiver: ERC721ReceiverComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721ReceiverEvent: ERC721ReceiverComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc721_receiver.initializer();
    }

    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
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
}

#[starknet::contract]
mod SnakeERC721ReceiverPanicMock {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn on_erc721_received(
            self: @ContractState,
            operator: ContractAddress,
            from: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) -> felt252 {
            panic!("Some error");
            3
        }
    }
}

#[starknet::contract]
mod CamelERC721ReceiverPanicMock {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn onERC721Received(
            self: @ContractState,
            operator: ContractAddress,
            from: ContractAddress,
            tokenId: u256,
            data: Span<felt252>
        ) -> felt252 {
            panic!("Some error");
            3
        }
    }
}
