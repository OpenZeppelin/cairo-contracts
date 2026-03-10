#[starknet::contract]
#[with_components(ERC6909, SRC5)]
pub mod ERC6909Mock {
    use openzeppelin_token::erc6909::ERC6909HooksEmptyImpl;
    use starknet::ContractAddress;

    #[abi(embed_v0)]
    impl ERC6909Impl = ERC6909Component::ERC6909Impl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState, recipient: ContractAddress, id: u256, amount: u256) {
        self.erc6909.initializer();
        self.erc6909.mint(recipient, id, amount);
    }
}

#[starknet::contract]
#[with_components(ERC6909, SRC5)]
pub mod ERC6909MockWithHooks {
    use starknet::ContractAddress;

    #[abi(embed_v0)]
    impl ERC6909Impl = ERC6909Component::ERC6909Impl<ContractState>;

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

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct BeforeUpdate {
        pub from: ContractAddress,
        pub recipient: ContractAddress,
        pub id: u256,
        pub amount: u256,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct AfterUpdate {
        pub from: ContractAddress,
        pub recipient: ContractAddress,
        pub id: u256,
        pub amount: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, recipient: ContractAddress, id: u256, amount: u256) {
        self.erc6909.initializer();
        self.erc6909.mint(recipient, id, amount);
    }

    impl ERC6909HooksImpl of ERC6909Component::ERC6909HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC6909Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            id: u256,
            amount: u256,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.emit(BeforeUpdate { from, recipient, id, amount });
        }

        fn after_update(
            ref self: ERC6909Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            id: u256,
            amount: u256,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.emit(AfterUpdate { from, recipient, id, amount });
        }
    }
}

#[starknet::contract]
#[with_components(ERC6909, ERC6909ContentURI, SRC5)]
pub mod ERC6909ContentURIMock {
    use openzeppelin_token::erc6909::ERC6909HooksEmptyImpl;
    use starknet::ContractAddress;

    #[abi(embed_v0)]
    impl ERC6909Impl = ERC6909Component::ERC6909Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909ContentURIImpl =
        ERC6909ContentURIComponent::ERC6909ContentURIImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(
        ref self: ContractState,
        contract_uri: ByteArray,
        recipient: ContractAddress,
        id: u256,
        amount: u256,
    ) {
        self.erc6909.initializer();
        self.erc6909_content_uri.initializer();
        self.erc6909_content_uri.set_contract_uri(contract_uri);
        self.erc6909.mint(recipient, id, amount);
    }
}

#[starknet::contract]
#[with_components(ERC6909, ERC6909Metadata, SRC5)]
pub mod ERC6909MetadataMock {
    use openzeppelin_token::erc6909::ERC6909HooksEmptyImpl;
    use starknet::ContractAddress;

    #[abi(embed_v0)]
    impl ERC6909Impl = ERC6909Component::ERC6909Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909MetadataImpl =
        ERC6909MetadataComponent::ERC6909MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
        recipient: ContractAddress,
        id: u256,
        amount: u256,
    ) {
        self.erc6909.initializer();
        self.erc6909_metadata.initializer(id, name, symbol, decimals);
        self.erc6909.mint(recipient, id, amount);
    }
}

#[starknet::contract]
#[with_components(ERC6909, ERC6909TokenSupply, SRC5)]
pub mod ERC6909TokenSupplyMock {
    use openzeppelin_token::erc6909::ERC6909HooksEmptyImpl;
    use starknet::ContractAddress;

    #[abi(embed_v0)]
    impl ERC6909Impl = ERC6909Component::ERC6909Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909TokenSupplyImpl =
        ERC6909TokenSupplyComponent::ERC6909TokenSupplyImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState, recipient: ContractAddress, id: u256, amount: u256) {
        self.erc6909.initializer();
        self.erc6909_token_supply.initializer();
        self.erc6909.mint(recipient, id, amount);
    }
}
