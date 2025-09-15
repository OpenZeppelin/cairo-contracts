#[starknet::contract]
#[with_components(AccessControl, SRC5)]
pub mod DualCaseAccessControlMock {
    use openzeppelin_access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use starknet::ContractAddress;

    // AccessControlMixin
    #[abi(embed_v0)]
    impl AccessControlMixinImpl =
        AccessControlComponent::AccessControlMixinImpl<ContractState>;

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.access_control.initializer();
        self.access_control._grant_role(DEFAULT_ADMIN_ROLE, admin);
    }
}

#[starknet::contract]
#[with_components(SRC5, AccessControlDefaultAdminRules)]
pub mod DualCaseAccessControlDefaultAdminRulesMock {
    use openzeppelin_access::accesscontrol::extensions::DefaultConfig;
    use starknet::ContractAddress;

    pub const INITIAL_DELAY: u64 = 3600; // 1 hour

    #[abi(embed_v0)]
    impl AccessControlMixinImpl =
        AccessControlDefaultAdminRulesComponent::AccessControlMixinImpl<ContractState>;

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState, initial_default_admin: ContractAddress) {
        self.access_control_dar.initializer(INITIAL_DELAY, initial_default_admin);
    }
}

#[starknet::contract]
#[with_components(Ownable)]
pub mod DualCaseOwnableMock {
    use starknet::ContractAddress;

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    #[storage]
    pub struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }
}

#[starknet::contract]
#[with_components(Ownable)]
pub mod DualCaseTwoStepOwnableMock {
    use starknet::ContractAddress;

    #[abi(embed_v0)]
    impl OwnableTwoStepMixinImpl =
        OwnableComponent::OwnableTwoStepMixinImpl<ContractState>;

    #[storage]
    pub struct Storage {}


    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }
}
