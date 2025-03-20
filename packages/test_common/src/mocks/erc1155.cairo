#[starknet::contract]
pub mod DualCaseERC1155Mock {
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc1155::{ERC1155Component, ERC1155HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC1155
    #[abi(embed_v0)]
    impl ERC1155Impl = ERC1155Component::ERC1155Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC1155MetadataURIImpl =
        ERC1155Component::ERC1155MetadataURIImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721Camel = ERC1155Component::ERC1155CamelImpl<ContractState>;
    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC1155Event: ERC1155Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        base_uri: ByteArray,
        recipient: ContractAddress,
        token_id: u256,
        value: u256,
    ) {
        self.erc1155.initializer(base_uri);
        self.erc1155.mint_with_acceptance_check(recipient, token_id, value, array![].span());
    }
}

#[starknet::contract]
pub mod SnakeERC1155Mock {
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc1155::{ERC1155Component, ERC1155HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC1155
    #[abi(embed_v0)]
    impl ERC1155Impl = ERC1155Component::ERC1155Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC1155MetadataURIImpl =
        ERC1155Component::ERC1155MetadataURIImpl<ContractState>;
    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC1155Event: ERC1155Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        base_uri: ByteArray,
        recipient: ContractAddress,
        token_id: u256,
        value: u256,
    ) {
        self.erc1155.initializer(base_uri);
        self.erc1155.mint_with_acceptance_check(recipient, token_id, value, array![].span());
    }
}

/// Similar to `SnakeERC1155Mock`, but emits events for `before_update` and `after_update` hooks.
/// This is used to test that the hooks are called with the correct arguments.
#[starknet::contract]
pub mod SnakeERC1155MockWithHooks {
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc1155::ERC1155Component;
    use starknet::ContractAddress;

    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC1155
    #[abi(embed_v0)]
    impl ERC1155Impl = ERC1155Component::ERC1155Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC1155MetadataURIImpl =
        ERC1155Component::ERC1155MetadataURIImpl<ContractState>;
    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ERC1155Event: ERC1155Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        BeforeUpdate: BeforeUpdate,
        AfterUpdate: AfterUpdate,
    }

    /// Event used to test that `before_update` hook is called.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct BeforeUpdate {
        pub from: ContractAddress,
        pub to: ContractAddress,
        pub token_ids: Span<u256>,
        pub values: Span<u256>,
    }

    /// Event used to test that `after_update` hook is called.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct AfterUpdate {
        pub from: ContractAddress,
        pub to: ContractAddress,
        pub token_ids: Span<u256>,
        pub values: Span<u256>,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        base_uri: ByteArray,
        recipient: ContractAddress,
        token_id: u256,
        value: u256,
    ) {
        self.erc1155.initializer(base_uri);
        self.erc1155.mint_with_acceptance_check(recipient, token_id, value, array![].span());
    }

    impl ERC1155HooksImpl of ERC1155Component::ERC1155HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC1155Component::ComponentState<ContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.emit(BeforeUpdate { from, to, token_ids, values });
        }

        fn after_update(
            ref self: ERC1155Component::ComponentState<ContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.emit(AfterUpdate { from, to, token_ids, values });
        }
    }
}

#[starknet::contract]
pub mod DualCaseERC1155ReceiverMock {
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc1155::ERC1155ReceiverComponent;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(
        path: ERC1155ReceiverComponent, storage: erc1155_receiver, event: ERC1155ReceiverEvent,
    );

    // ERC1155Receiver Mixin
    #[abi(embed_v0)]
    impl ERC1155ReceiverMixinImpl =
        ERC1155ReceiverComponent::ERC1155ReceiverMixinImpl<ContractState>;
    impl ERC1155ReceiverInternalImpl = ERC1155ReceiverComponent::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc1155_receiver: ERC1155ReceiverComponent::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC1155ReceiverEvent: ERC1155ReceiverComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc1155_receiver.initializer();
    }
}
