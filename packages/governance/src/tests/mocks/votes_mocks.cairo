#[starknet::contract]
pub(crate) mod ERC721VotesMock {
    use openzeppelin_governance::votes::votes::VotesComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::ERC721Component;
    // This is temporary - we should actually implement the hooks manually
    // and transfer the voting units in the hooks.
    use openzeppelin_token::erc721::ERC721HooksEmptyImpl;
    use openzeppelin_utils::cryptography::nonces::NoncesComponent;
    use openzeppelin_utils::cryptography::snip12::SNIP12Metadata;

    component!(path: VotesComponent, storage: erc721_votes, event: ERC721VotesEvent);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: NoncesComponent, storage: nonces, event: NoncesEvent);

    //Votes and ERC721Votes
    #[abi(embed_v0)]
    impl VotesImpl = VotesComponent::VotesImpl<ContractState>;
    impl InternalImpl = VotesComponent::InternalImpl<ContractState>;
    impl ERC721VotesInternalImpl = VotesComponent::ERC721VotesImpl<ContractState>;

    // ERC721
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    // Nonces
    #[abi(embed_v0)]
    impl NoncesImpl = NoncesComponent::NoncesImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721_votes: VotesComponent::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        nonces: NoncesComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721VotesEvent: VotesComponent::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        NoncesEvent: NoncesComponent::Event
    }

    /// Required for hash computation.
    pub(crate) impl SNIP12MetadataImpl of SNIP12Metadata {
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

    // impl ERC721VotesHooksImpl<
    //     TContractState,
    //     impl Votes: VotesComponent::HasComponent<TContractState>,
    //     impl HasComponent: VotesComponent::HasComponent<TContractState>,
    //     +NoncesComponent::HasComponent<TContractState>,
    //     +Drop<TContractState>
    // > of ERC721Component::ERC721HooksTrait<TContractState> {
    //     fn after_update(
    //         ref self: ERC721Component::ComponentState<TContractState>,
    //         to: ContractAddress,
    //         token_id: u256,
    //         auth: ContractAddress
    //     ) {
    //         let mut erc721_votes_component = get_dep_component_mut!(ref self, Votes);
    //         erc721_votes_component.transfer_voting_units(auth, to, 1);
    //     }
    // }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc721.initializer("MyToken", "MTK", "");
    }
}

#[starknet::contract]
pub(crate) mod ERC20VotesMock {
    use openzeppelin_governance::votes::votes::VotesComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc20::ERC20Component;
    // This is temporary - we should actually implement the hooks manually
    // and transfer the voting units in the hooks.
    use openzeppelin_token::erc20::ERC20HooksEmptyImpl;
    use openzeppelin_utils::cryptography::nonces::NoncesComponent;
    use openzeppelin_utils::cryptography::snip12::SNIP12Metadata;

    component!(path: VotesComponent, storage: erc20_votes, event: ERC20VotesEvent);
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: NoncesComponent, storage: nonces, event: NoncesEvent);

    // Votes and ERC20Votes
    #[abi(embed_v0)]
    impl VotesImpl = VotesComponent::VotesImpl<ContractState>;
    impl InternalImpl = VotesComponent::InternalImpl<ContractState>;
    impl ERC20VotesInternalImpl = VotesComponent::ERC20VotesImpl<ContractState>;

    // ERC20
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    // Nonces
    #[abi(embed_v0)]
    impl NoncesImpl = NoncesComponent::NoncesImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20_votes: VotesComponent::Storage,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        nonces: NoncesComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20VotesEvent: VotesComponent::Event,
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        NoncesEvent: NoncesComponent::Event
    }

    /// Required for hash computation.
    pub(crate) impl SNIP12MetadataImpl of SNIP12Metadata {
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

    // Uncomment and modify this section if you need ERC20 hooks
    // impl ERC20VotesHooksImpl<
    //     TContractState,
    //     impl Votes: VotesComponent::HasComponent<TContractState>,
    //     impl HasComponent: VotesComponent::HasComponent<TContractState>,
    //     +NoncesComponent::HasComponent<TContractState>,
    //     +Drop<TContractState>
    // > of ERC20Component::ERC20HooksTrait<TContractState> {
    //     fn after_transfer(
    //         ref self: ERC20Component::ComponentState<TContractState>,
    //         from: ContractAddress,
    //         to: ContractAddress,
    //         amount: u256
    //     ) {
    //         let mut erc20_votes_component = get_dep_component_mut!(ref self, Votes);
    //         erc20_votes_component.transfer_voting_units(from, to, amount);
    //     }
    // }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc20.initializer("MyToken", "MTK");
    }
}

