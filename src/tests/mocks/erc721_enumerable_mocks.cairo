#[starknet::contract]
mod DualCaseERC721EnumerableMock {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component::ERC721HooksTrait;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::token::erc721::extensions::ERC721EnumerableComponent;
    use starknet::ContractAddress;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(
        path: ERC721EnumerableComponent, storage: erc721_enumerable, event: ERC721EnumerableEvent
    );
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721Impl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    // ERC721Enumerable
    #[abi(embed_v0)]
    impl ERC721EnumerableImpl =
        ERC721EnumerableComponent::ERC721EnumerableImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721EnumerableCamelImpl =
        ERC721EnumerableComponent::ERC721EnumerableCamelImpl<ContractState>;
    impl ERC721EnumerableInternalImpl = ERC721EnumerableComponent::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        erc721_enumerable: ERC721EnumerableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        ERC721EnumerableEvent: ERC721EnumerableComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    impl ERC721EnumerableHooksImpl<
        TContractState,
        impl ERC721Enumerable: ERC721EnumerableComponent::HasComponent<TContractState>,
        impl HasComponent: ERC721Component::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of ERC721Component::ERC721HooksTrait<TContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<TContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress
        ) {
            let mut erc721_enumerable_component = get_dep_component_mut!(
                ref self, ERC721Enumerable
            );
            erc721_enumerable_component.before_update(to, token_id);
        }

        fn after_update(
            ref self: ERC721Component::ComponentState<TContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress
        ) {}
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        recipient: ContractAddress,
        token_id: u256
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        self.erc721_enumerable.initializer();
        self.erc721._mint(recipient, token_id);
    }
}

#[starknet::contract]
mod SnakeERC721EnumerableMock {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component::ERC721HooksTrait;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::token::erc721::extensions::ERC721EnumerableComponent;

    use starknet::ContractAddress;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(
        path: ERC721EnumerableComponent, storage: erc721_enumerable, event: ERC721EnumerableEvent
    );
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    // ERC721Enumerable
    #[abi(embed_v0)]
    impl ERC721EnumerableImpl =
        ERC721EnumerableComponent::ERC721EnumerableImpl<ContractState>;
    impl ERC721EnumerableInternalImpl = ERC721EnumerableComponent::InternalImpl<ContractState>;

    // SRC5
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        erc721_enumerable: ERC721EnumerableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        ERC721EnumerableEvent: ERC721EnumerableComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    impl ERC721EnumerableHooksImpl<
        TContractState,
        impl ERC721Enumerable: ERC721EnumerableComponent::HasComponent<TContractState>,
        impl HasComponent: ERC721Component::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of ERC721Component::ERC721HooksTrait<TContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<TContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress
        ) {
            let mut erc721_enumerable_component = get_dep_component_mut!(
                ref self, ERC721Enumerable
            );
            erc721_enumerable_component.before_update(to, token_id);
        }

        fn after_update(
            ref self: ERC721Component::ComponentState<TContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress
        ) {}
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        recipient: ContractAddress,
        token_id: u256
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        self.erc721_enumerable.initializer();
        self.erc721._mint(recipient, token_id);
    }
}

#[starknet::contract]
mod CamelERC721EnumerableMock {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component::ERC721HooksTrait;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::token::erc721::extensions::ERC721EnumerableComponent;

    use starknet::ContractAddress;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(
        path: ERC721EnumerableComponent, storage: erc721_enumerable, event: ERC721EnumerableEvent
    );
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    // ERC721Enumerable
    #[abi(embed_v0)]
    impl ERC721EnumerableCamelImpl =
        ERC721EnumerableComponent::ERC721EnumerableCamelImpl<ContractState>;
    impl ERC721EnumerableInternalImpl = ERC721EnumerableComponent::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        erc721_enumerable: ERC721EnumerableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        ERC721EnumerableEvent: ERC721EnumerableComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    impl ERC721EnumerableHooksImpl<
        TContractState,
        impl ERC721Enumerable: ERC721EnumerableComponent::HasComponent<TContractState>,
        impl HasComponent: ERC721Component::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of ERC721Component::ERC721HooksTrait<TContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<TContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress
        ) {
            let mut erc721_enumerable_component = get_dep_component_mut!(
                ref self, ERC721Enumerable
            );
            erc721_enumerable_component.before_update(to, token_id);
        }

        fn after_update(
            ref self: ERC721Component::ComponentState<TContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress
        ) {}
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        recipient: ContractAddress,
        token_id: u256
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        self.erc721_enumerable.initializer();
        self.erc721._mint(recipient, token_id);
    }
}

#[starknet::contract]
mod SnakeERC721EnumerablePanicMock {
    use starknet::ContractAddress;
    use zeroable::Zeroable;

    #[storage]
    struct Storage {}

    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn total_supply(self: @ContractState) -> u256 {
            panic!("Some error");
            u256 { low: 3, high: 3 }
        }

        #[external(v0)]
        fn token_by_index(self: @ContractState, index: u256) -> u256 {
            panic!("Some error");
            u256 { low: 3, high: 3 }
        }

        #[external(v0)]
        fn token_of_owner_by_index(
            self: @ContractState, owner: ContractAddress, index: u256
        ) -> u256 {
            panic!("Some error");
            u256 { low: 3, high: 3 }
        }
    }
}

#[starknet::contract]
mod CamelERC721EnumerablePanicMock {
    use starknet::ContractAddress;
    use zeroable::Zeroable;

    #[storage]
    struct Storage {}

    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn totalSupply(self: @ContractState) -> u256 {
            panic!("Some error");
            u256 { low: 3, high: 3 }
        }

        #[external(v0)]
        fn tokenByIndex(self: @ContractState, index: u256) -> u256 {
            panic!("Some error");
            u256 { low: 3, high: 3 }
        }

        #[external(v0)]
        fn tokenOfOwnerByIndex(self: @ContractState, owner: ContractAddress, index: u256) -> u256 {
            panic!("Some error");
            u256 { low: 3, high: 3 }
        }
    }
}
