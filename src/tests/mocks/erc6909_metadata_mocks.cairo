#[starknet::contract]
pub(crate) mod DualCaseERC6909MetadataMock {
    use openzeppelin::token::erc6909::ERC6909Component;
    use openzeppelin::token::erc6909::extensions::ERC6909MetadataComponent;
    use starknet::ContractAddress;

    component!(
        path: ERC6909MetadataComponent, storage: erc6909_metadata, event: ERC6909MetadataEvent
    );
    component!(path: ERC6909Component, storage: erc6909, event: ERC6909Event);

    // ERC6909Metadata
    #[abi(embed_v0)]
    impl ERC6909MetadataComponentImpl = ERC6909MetadataComponent::ERC6909MetadataImpl<ContractState>;

    // ERC6909Mixin
    #[abi(embed_v0)]
    impl ERC6909MixinImpl = ERC6909Component::ERC6909MixinImpl<ContractState>;

    impl ERC6909InternalImpl = ERC6909Component::InternalImpl<ContractState>;
    impl ERC6909MetadataInternalImpl = ERC6909MetadataComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc6909_metadata: ERC6909MetadataComponent::Storage,
        #[substorage(v0)]
        erc6909: ERC6909Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC6909MetadataEvent: ERC6909MetadataComponent::Event,
        #[flat]
        ERC6909Event: ERC6909Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, receiver: ContractAddress, id: u256, amount: u256) {
        self.erc6909.mint(receiver, id, amount);
    }

    impl ERC6909MetadataHooksImpl<
        TContractState,
        impl ERC6909Metadata: ERC6909MetadataComponent::HasComponent<TContractState>,
        impl HasComponent: ERC6909Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of ERC6909Component::ERC6909HooksTrait<TContractState> {
        fn before_update(
            ref self: ERC6909Component::ComponentState<TContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            id: u256,
            amount: u256
        ) {}

        /// Update after any transfer
        fn after_update(
            ref self: ERC6909Component::ComponentState<TContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            id: u256,
            amount: u256
        ) {
            let mut erc6909_metadata_component = get_dep_component_mut!(ref self, ERC6909Metadata);
            let name = "MyERC6909Token";
            let symbol = "MET";
            let decimals = 18;
            erc6909_metadata_component._update_token_metadata(from, id, name, symbol, decimals);
        }
    }
}
