#[starknet::contract]
pub mod DualCaseERC20Mock {
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;
    impl InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
    }
}

#[starknet::contract]
pub mod SnakeERC20Mock {
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    impl InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
    }
}

#[starknet::contract]
pub mod DualCaseERC20VotesMock {
    use openzeppelin_token::erc20::ERC20Component;
    use openzeppelin_token::erc20::extensions::ERC20VotesComponent::InternalTrait as ERC20VotesInternalTrait;
    use openzeppelin_token::erc20::extensions::ERC20VotesComponent;
    use openzeppelin_utils::cryptography::nonces::NoncesComponent;
    use openzeppelin_utils::cryptography::snip12::SNIP12Metadata;
    use starknet::ContractAddress;

    component!(path: ERC20VotesComponent, storage: erc20_votes, event: ERC20VotesEvent);
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: NoncesComponent, storage: nonces, event: NoncesEvent);

    // ERC20Votes
    #[abi(embed_v0)]
    impl ERC20VotesComponentImpl =
        ERC20VotesComponent::ERC20VotesImpl<ContractState>;

    // ERC20Mixin
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl InternalImpl = ERC20Component::InternalImpl<ContractState>;

    // Nonces
    #[abi(embed_v0)]
    impl NoncesImpl = NoncesComponent::NoncesImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc20_votes: ERC20VotesComponent::Storage,
        #[substorage(v0)]
        pub erc20: ERC20Component::Storage,
        #[substorage(v0)]
        pub nonces: NoncesComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20VotesEvent: ERC20VotesComponent::Event,
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        NoncesEvent: NoncesComponent::Event
    }

    /// Required for hash computation.
    pub impl SNIP12MetadataImpl of SNIP12Metadata {
        fn name() -> felt252 {
            'DAPP_NAME'
        }
        fn version() -> felt252 {
            'DAPP_VERSION'
        }
    }

    //
    // Hooks
    //

    impl ERC20VotesHooksImpl<
        TContractState,
        impl ERC20Votes: ERC20VotesComponent::HasComponent<TContractState>,
        impl HasComponent: ERC20Component::HasComponent<TContractState>,
        +NoncesComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of ERC20Component::ERC20HooksTrait<TContractState> {
        fn after_update(
            ref self: ERC20Component::ComponentState<TContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            let mut erc20_votes_component = get_dep_component_mut!(ref self, ERC20Votes);
            erc20_votes_component.transfer_voting_units(from, recipient, amount);
        }
    }

    /// Sets the token `name` and `symbol`.
    /// Mints `fixed_supply` tokens to `recipient`.
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        fixed_supply: u256,
        recipient: ContractAddress
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, fixed_supply);
    }
}
