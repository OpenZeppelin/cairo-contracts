use starknet::ContractAddress;

const SUCCESS: felt252 = 'SUCCESS';

#[starknet::contract]
#[with_components(ERC721, SRC5)]
pub mod DualCaseERC721Mock {
    use openzeppelin_token::erc721::{ERC721HooksEmptyImpl, ERC721OwnerOfDefaultImpl};
    use starknet::ContractAddress;

    // ERC721
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721CamelOnly = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataCamelOnly =
        ERC721Component::ERC721MetadataCamelOnlyImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        recipient: ContractAddress,
        token_id: u256,
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        self.erc721.mint(recipient, token_id);
    }
}

#[starknet::contract]
#[with_components(ERC721, SRC5)]
pub mod SnakeERC721Mock {
    use openzeppelin_token::erc721::{ERC721HooksEmptyImpl, ERC721OwnerOfDefaultImpl};
    use starknet::ContractAddress;

    // ERC721
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        recipient: ContractAddress,
        token_id: u256,
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        self.erc721.mint(recipient, token_id);
    }
}

/// Similar as `SnakeERC721Mock`, but emits events for `before_update` and `after_update` hooks.
/// This is used to test that the hooks are called with the correct arguments.
#[starknet::contract]
#[with_components(ERC721, SRC5)]
pub mod SnakeERC721MockWithHooks {
    use openzeppelin_token::erc721::ERC721OwnerOfDefaultImpl;
    use starknet::ContractAddress;

    // ERC721
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        BeforeUpdate: BeforeUpdate,
        AfterUpdate: AfterUpdate,
    }

    /// Event used to test that `before_update` hook is called.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct BeforeUpdate {
        pub to: ContractAddress,
        pub token_id: u256,
        pub auth: ContractAddress,
    }

    /// Event used to test that `after_update` hook is called.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct AfterUpdate {
        pub to: ContractAddress,
        pub token_id: u256,
        pub auth: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        recipient: ContractAddress,
        token_id: u256,
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        self.erc721.mint(recipient, token_id);
    }

    impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.emit(BeforeUpdate { to, token_id, auth });
        }

        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.emit(AfterUpdate { to, token_id, auth });
        }
    }
}

#[starknet::contract]
#[with_components(ERC721Receiver, SRC5)]
pub mod DualCaseERC721ReceiverMock {
    use starknet::ContractAddress;

    // ERC721Receiver
    impl ERC721ReceiverImpl = ERC721ReceiverComponent::ERC721ReceiverImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {}

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
            data: Span<felt252>,
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
            data: Span<felt252>,
        ) -> felt252 {
            Self::on_erc721_received(self, operator, from, tokenId, data)
        }
    }
}

#[starknet::contract]
#[with_components(ERC721, ERC721Enumerable, SRC5)]
pub mod ERC721EnumerableMock {
    use openzeppelin_token::erc721::ERC721OwnerOfDefaultImpl;
    use starknet::ContractAddress;

    // ERC721
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721Impl<ContractState>;

    // ERC721Enumerable
    #[abi(embed_v0)]
    impl ERC721EnumerableImpl =
        ERC721EnumerableComponent::ERC721EnumerableImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {}

    impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.erc721_enumerable.before_update(to, token_id);
        }
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn all_tokens_of_owner(self: @ContractState, owner: ContractAddress) -> Span<u256> {
            self.erc721_enumerable.all_tokens_of_owner(owner)
        }
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        recipient: ContractAddress,
        token_id: u256,
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        self.erc721_enumerable.initializer();
        self.erc721.mint(recipient, token_id);
    }
}

#[starknet::interface]
pub trait IERC721Mintable<TState> {
    fn mint(ref self: TState, to: ContractAddress, token_id: u256);
}

#[starknet::interface]
pub trait IERC721WrapperRecoverer<TState> {
    fn recover(ref self: TState, account: ContractAddress, token_id: u256) -> u256;
}

#[starknet::contract]
#[with_components(ERC721, SRC5)]
pub mod ERC721MintableMock {
    use openzeppelin_token::erc721::{ERC721HooksEmptyImpl, ERC721OwnerOfDefaultImpl};
    use starknet::ContractAddress;
    use super::IERC721Mintable;

    // ERC721
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(
        ref self: ContractState, name: ByteArray, symbol: ByteArray, base_uri: ByteArray,
    ) {
        self.erc721.initializer(name, symbol, base_uri);
    }

    #[abi(embed_v0)]
    impl ERC721MintableImpl of IERC721Mintable<ContractState> {
        fn mint(ref self: ContractState, to: ContractAddress, token_id: u256) {
            self.erc721.mint(to, token_id);
        }
    }
}

#[starknet::contract]
#[with_components(ERC721, SRC5)]
pub mod ERC721WrapperMock {
    use openzeppelin_token::erc721::extensions::erc721_wrapper::ERC721WrapperComponent;
    use openzeppelin_token::erc721::extensions::erc721_wrapper::ERC721WrapperComponent::InternalImpl;
    use openzeppelin_token::erc721::{ERC721HooksEmptyImpl, ERC721OwnerOfDefaultImpl};
    use starknet::ContractAddress;
    use super::IERC721WrapperRecoverer;

    component!(path: ERC721WrapperComponent, storage: erc721_wrapper, event: ERC721WrapperEvent);

    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721WrapperImpl =
        ERC721WrapperComponent::ERC721WrapperImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721WrapperReceiverImpl =
        ERC721WrapperComponent::ERC721WrapperReceiverImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721_wrapper: ERC721WrapperComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721WrapperEvent: ERC721WrapperComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        underlying: ContractAddress,
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        self.erc721_wrapper.initializer(underlying);
    }

    #[abi(embed_v0)]
    impl ERC721WrapperRecovererImpl of IERC721WrapperRecoverer<ContractState> {
        fn recover(ref self: ContractState, account: ContractAddress, token_id: u256) -> u256 {
            self.erc721_wrapper.recover(account, token_id)
        }
    }
}

#[starknet::contract]
#[with_components(ERC721, SRC5)]
pub mod ERC721ConsecutiveMock {
    use openzeppelin_token::erc721::ERC721HooksEmptyImpl;
    use openzeppelin_token::erc721::extensions::erc721_consecutive::ERC721ConsecutiveComponent::InternalImpl;
    use openzeppelin_token::erc721::extensions::erc721_consecutive::{
        DefaultConfig, ERC721ConsecutiveComponent,
    };
    use starknet::ContractAddress;

    component!(
        path: ERC721ConsecutiveComponent,
        storage: erc721_consecutive,
        event: ERC721ConsecutiveEvent,
    );

    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721_consecutive: ERC721ConsecutiveComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721ConsecutiveEvent: ERC721ConsecutiveComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        recipient: ContractAddress,
        batch_size: u64,
    ) {
        self.erc721.initializer(name, symbol, base_uri);
        self.erc721_consecutive.mint_consecutive(recipient, batch_size);
    }
}
