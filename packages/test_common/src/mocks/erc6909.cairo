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
        self.erc6909_content_uri._set_contract_uri(contract_uri);
        self.erc6909.mint(recipient, id, amount);
    }
}

#[starknet::contract]
#[with_components(ERC6909, ERC6909ContentURI, SRC5, Ownable)]
pub mod ERC6909ContentURIOwnableMock {
    use openzeppelin_token::erc6909::ERC6909HooksEmptyImpl;
    use starknet::ContractAddress;

    #[abi(embed_v0)]
    impl ERC6909Impl = ERC6909Component::ERC6909Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909ContentURIImpl =
        ERC6909ContentURIComponent::ERC6909ContentURIImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909ContentURIAdminOwnableImpl =
        ERC6909ContentURIComponent::ERC6909ContentURIAdminOwnableImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc6909.initializer();
        self.erc6909_content_uri.initializer();
        self.ownable.initializer(owner);
    }
}

#[starknet::contract]
#[with_components(ERC6909, ERC6909ContentURI, SRC5, AccessControl)]
pub mod ERC6909ContentURIAccessControlMock {
    use openzeppelin_access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin_token::erc6909::ERC6909HooksEmptyImpl;
    use openzeppelin_token::erc6909::extensions::erc6909_content_uri::ERC6909ContentURIComponent::CONTENT_URI_ADMIN_ROLE;
    use starknet::ContractAddress;

    #[abi(embed_v0)]
    impl ERC6909Impl = ERC6909Component::ERC6909Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909ContentURIImpl =
        ERC6909ContentURIComponent::ERC6909ContentURIImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909ContentURIAdminAccessControlImpl =
        ERC6909ContentURIComponent::ERC6909ContentURIAdminAccessControlImpl<ContractState>;
    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc6909.initializer();
        self.erc6909_content_uri.initializer();
        self.access_control.initializer();
        self.access_control._grant_role(DEFAULT_ADMIN_ROLE, owner);
        self.access_control._grant_role(CONTENT_URI_ADMIN_ROLE, owner);
    }
}

#[starknet::contract]
#[with_components(ERC6909, ERC6909ContentURI, SRC5, AccessControlDefaultAdminRules)]
pub mod ERC6909ContentURIAccessControlDefaultAdminRulesMock {
    use openzeppelin_access::accesscontrol::extensions::DefaultConfig as AccessControlDefaultAdminRulesDefaultConfig;
    use openzeppelin_token::erc6909::ERC6909HooksEmptyImpl;
    use openzeppelin_token::erc6909::extensions::erc6909_content_uri::ERC6909ContentURIComponent::CONTENT_URI_ADMIN_ROLE;
    use starknet::ContractAddress;

    #[abi(embed_v0)]
    impl ERC6909Impl = ERC6909Component::ERC6909Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909ContentURIImpl =
        ERC6909ContentURIComponent::ERC6909ContentURIImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909ContentURIAdminAccessControlDefaultAdminRulesImpl =
        ERC6909ContentURIComponent::ERC6909ContentURIAdminAccessControlDefaultAdminRulesImpl<
            ContractState,
        >;
    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlDefaultAdminRulesComponent::AccessControlImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    pub const INITIAL_DELAY: u64 = 3600; // 1 hour

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc6909.initializer();
        self.erc6909_content_uri.initializer();
        self.access_control_dar.initializer(INITIAL_DELAY, owner);
        self.access_control_dar._grant_role(CONTENT_URI_ADMIN_ROLE, owner);
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
        self.erc6909_metadata.initializer();
        self.erc6909_metadata._set_token_name(id, name);
        self.erc6909_metadata._set_token_symbol(id, symbol);
        self.erc6909_metadata._set_token_decimals(id, decimals);
        self.erc6909.mint(recipient, id, amount);
    }
}

#[starknet::contract]
#[with_components(ERC6909, ERC6909Metadata, SRC5, Ownable)]
pub mod ERC6909MetadataOwnableMock {
    use openzeppelin_token::erc6909::ERC6909HooksEmptyImpl;
    use starknet::ContractAddress;

    #[abi(embed_v0)]
    impl ERC6909Impl = ERC6909Component::ERC6909Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909MetadataImpl =
        ERC6909MetadataComponent::ERC6909MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909MetadataAdminOwnableImpl =
        ERC6909MetadataComponent::ERC6909MetadataAdminOwnableImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc6909.initializer();
        self.erc6909_metadata.initializer();
        self.ownable.initializer(owner);
    }
}

#[starknet::contract]
#[with_components(ERC6909, ERC6909Metadata, SRC5, AccessControl)]
pub mod ERC6909MetadataAccessControlMock {
    use openzeppelin_access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin_token::erc6909::ERC6909HooksEmptyImpl;
    use openzeppelin_token::erc6909::extensions::erc6909_metadata::ERC6909MetadataComponent::METADATA_ADMIN_ROLE;
    use starknet::ContractAddress;

    #[abi(embed_v0)]
    impl ERC6909Impl = ERC6909Component::ERC6909Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909MetadataImpl =
        ERC6909MetadataComponent::ERC6909MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909MetadataAdminAccessControlImpl =
        ERC6909MetadataComponent::ERC6909MetadataAdminAccessControlImpl<ContractState>;
    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc6909.initializer();
        self.erc6909_metadata.initializer();
        self.access_control.initializer();
        self.access_control._grant_role(DEFAULT_ADMIN_ROLE, owner);
        self.access_control._grant_role(METADATA_ADMIN_ROLE, owner);
    }
}

#[starknet::contract]
#[with_components(ERC6909, ERC6909Metadata, SRC5, AccessControlDefaultAdminRules)]
pub mod ERC6909MetadataAccessControlDefaultAdminRulesMock {
    use openzeppelin_access::accesscontrol::extensions::DefaultConfig as AccessControlDefaultAdminRulesDefaultConfig;
    use openzeppelin_token::erc6909::ERC6909HooksEmptyImpl;
    use openzeppelin_token::erc6909::extensions::erc6909_metadata::ERC6909MetadataComponent::METADATA_ADMIN_ROLE;
    use starknet::ContractAddress;

    #[abi(embed_v0)]
    impl ERC6909Impl = ERC6909Component::ERC6909Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909MetadataImpl =
        ERC6909MetadataComponent::ERC6909MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC6909MetadataAdminAccessControlDefaultAdminRulesImpl =
        ERC6909MetadataComponent::ERC6909MetadataAdminAccessControlDefaultAdminRulesImpl<
            ContractState,
        >;
    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlDefaultAdminRulesComponent::AccessControlImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    pub const INITIAL_DELAY: u64 = 3600; // 1 hour

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc6909.initializer();
        self.erc6909_metadata.initializer();
        self.access_control_dar.initializer(INITIAL_DELAY, owner);
        self.access_control_dar._grant_role(METADATA_ADMIN_ROLE, owner);
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
