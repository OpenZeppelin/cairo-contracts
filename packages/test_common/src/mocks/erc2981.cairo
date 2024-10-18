#[starknet::contract]
pub mod ERC2981Mock {
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::common::erc2981::{ERC2981Component, DefaultConfig};
    use starknet::ContractAddress;

    component!(path: ERC2981Component, storage: erc2981, event: ERC2981Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl ERC2981Impl = ERC2981Component::ERC2981Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC2981InfoImpl =
        ERC2981Component::ERC2981InfoImpl<ContractState>;
    impl ERC2981InternalImpl = ERC2981Component::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc2981: ERC2981Component::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC2981Event: ERC2981Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        default_receiver: ContractAddress,
        default_royalty_fraction: u128
    ) {
        self.erc2981.initializer(default_receiver, default_royalty_fraction);
    }
}

#[starknet::contract]
pub mod ERC2981OwnableMock {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::common::erc2981::{ERC2981Component, DefaultConfig};
    use starknet::ContractAddress;

    component!(path: ERC2981Component, storage: erc2981, event: ERC2981Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // ERC2981
    #[abi(embed_v0)]
    impl ERC2981Impl = ERC2981Component::ERC2981Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC2981InfoImpl =
        ERC2981Component::ERC2981InfoImpl<ContractState>;
    #[abi(embed_v0)]
    impl IERC2981AdminOwnableImpl =
        ERC2981Component::IERC2981AdminOwnableImpl<ContractState>;
    impl ERC2981InternalImpl = ERC2981Component::InternalImpl<ContractState>;

    // Ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc2981: ERC2981Component::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage,
        #[substorage(v0)]
        pub ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC2981Event: ERC2981Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        default_receiver: ContractAddress,
        default_royalty_fraction: u128
    ) {
        self.erc2981.initializer(default_receiver, default_royalty_fraction);
        self.ownable.initializer(owner);
    }
}

#[starknet::contract]
pub mod ERC2981AccessControlMock {
    use AccessControlComponent::InternalTrait;
    use openzeppelin_access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::common::erc2981::ERC2981Component::ROYALTY_ADMIN_ROLE;
    use openzeppelin_token::common::erc2981::{ERC2981Component, DefaultConfig};
    use starknet::ContractAddress;

    component!(path: ERC2981Component, storage: erc2981, event: ERC2981Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);

    // ERC2981
    #[abi(embed_v0)]
    impl ERC2981Impl = ERC2981Component::ERC2981Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC2981InfoImpl =
        ERC2981Component::ERC2981InfoImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC2981AdminAccessControlImpl =
        ERC2981Component::ERC2981AdminAccessControlImpl<ContractState>;
    impl ERC2981InternalImpl = ERC2981Component::InternalImpl<ContractState>;

    // AccessControl
    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc2981: ERC2981Component::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage,
        #[substorage(v0)]
        pub accesscontrol: AccessControlComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC2981Event: ERC2981Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        default_receiver: ContractAddress,
        default_royalty_fraction: u128
    ) {
        self.erc2981.initializer(default_receiver, default_royalty_fraction);
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, owner);
        self.accesscontrol._grant_role(ROYALTY_ADMIN_ROLE, owner);
    }
}
