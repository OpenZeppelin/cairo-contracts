// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.16.0 (presets/erc20_permit.cairo)

/// # ERC20Permit Preset
///
/// The ERC20Permit preset integrates standard ERC20 token functionality with the ERC20Permit
/// extension, as defined by EIP-2612. This preset allows for token approvals via off-chain
/// signatures, thus enhancing transaction efficiency by reducing the need for on-chain approval
/// transactions.
///
/// This implementation features a fixed-supply model and the initial owner is specified in the
/// constructor.
///
/// The preset implements SNIP12Metadata with hardcoded values. These values are part of a
/// signature (following SNIP-12 standard) used for ERC20Permit functionality. It's crucial that the
/// SNIP12Metadata name remains unique to avoid confusion and potential security issues.
///
/// For more complex or custom contracts, use Wizard for Cairo
/// https://wizard.openzeppelin.com/cairo
#[starknet::contract]
pub mod ERC20Permit {
    use openzeppelin_token::erc20::extensions::ERC20PermitComponent;
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin_utils::cryptography::nonces::NoncesComponent;
    use openzeppelin_utils::cryptography::snip12::SNIP12Metadata;
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: ERC20PermitComponent, storage: erc20_permit, event: ERC20PermitEvent);
    component!(path: NoncesComponent, storage: nonces, event: NoncesEvent);

    // ERC20Mixin
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    // ERC20Permit
    #[abi(embed_v0)]
    impl ERC20PermitImpl = ERC20PermitComponent::ERC20PermitImpl<ContractState>;

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

    impl SNIP12MetadataImpl of SNIP12Metadata {
        /// Returns token name to be used for SNIP-12 signature.
        fn name() -> felt252 {
            'My unique token name'
        }

        /// Returns token version to be used for SNIP-12 signature.
        fn version() -> felt252 {
            'v1'
        }
    }
}
