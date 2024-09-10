#[starknet::contract]
pub(crate) mod DualCaseERC20PermitMock {
    use crate::erc20::extensions::ERC20PermitComponent;
    use crate::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin_utils::cryptography::nonces::NoncesComponent;
    use openzeppelin_utils::cryptography::snip12::SNIP12Metadata;
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: ERC20PermitComponent, storage: erc20_permit, event: ERC20PermitEvent);
    component!(path: NoncesComponent, storage: nonces, event: NoncesEvent);

    // ERC20Mixin
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl InternalImpl = ERC20Component::InternalImpl<ContractState>;

    // ERC20Permit
    #[abi(embed_v0)]
    impl ERC20PermitComponentImpl =
        ERC20PermitComponent::ERC20PermitImpl<ContractState>;

    // SNIP12Metadata
    #[abi(embed_v0)]
    impl SNIP12MetadataExternalImpl =
        ERC20PermitComponent::SNIP12MetadataExternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        erc20_permit: ERC20PermitComponent::Storage,
        #[substorage(v0)]
        nonces: NoncesComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        ERC20PermitEvent: ERC20PermitComponent::Event,
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

    /// Sets the token `name` and `symbol`.
    /// Mints `fixed_supply` tokens to `recipient`.
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
