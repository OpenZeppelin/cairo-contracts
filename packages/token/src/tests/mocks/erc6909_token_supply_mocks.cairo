#[starknet::contract]
pub(crate) mod DualCaseERC6909TokenSupplyMock {
    use openzeppelin::token::erc6909::ERC6909Component;
    use openzeppelin::token::erc6909::extensions::ERC6909TokenSupplyComponent;
    use starknet::ContractAddress;

    component!(
        path: ERC6909TokenSupplyComponent,
        storage: erc6909_token_supply,
        event: ERC6909TokenSupplyEvent
    );
    component!(path: ERC6909Component, storage: erc6909, event: ERC6909Event);

    // ERC6909TokenSupply
    #[abi(embed_v0)]
    impl ERC6909TokenSupplyComponentImpl =
        ERC6909TokenSupplyComponent::ERC6909TokenSupplyImpl<ContractState>;

    // ERC6909Mixin
    #[abi(embed_v0)]
    impl ERC6909MixinImpl = ERC6909Component::ERC6909MixinImpl<ContractState>;

    impl ERC6909InternalImpl = ERC6909Component::InternalImpl<ContractState>;
    impl ERC6909TokenSupplyInternalImpl = ERC6909TokenSupplyComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc6909_token_supply: ERC6909TokenSupplyComponent::Storage,
        #[substorage(v0)]
        erc6909: ERC6909Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC6909TokenSupplyEvent: ERC6909TokenSupplyComponent::Event,
        #[flat]
        ERC6909Event: ERC6909Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, receiver: ContractAddress, id: u256, amount: u256) {
        self.erc6909.mint(receiver, id, amount);
    }

    impl ERC6909TokenSupplyHooksImpl<
        TContractState,
        impl ERC6909TokenSupply: ERC6909TokenSupplyComponent::HasComponent<TContractState>,
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
            let mut erc6909_token_supply_component = get_dep_component_mut!(
                ref self, ERC6909TokenSupply
            );
            erc6909_token_supply_component._update_token_supply(from, recipient, id, amount);
        }
    }
}
