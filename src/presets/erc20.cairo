// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0 (presets/erc20.cairo)

/// # ERC20 Preset
///
/// The ERC20 contract offers basic functionality and provides a
/// fixed-supply mechanism for token distribution. The fixed supply is
/// set in the constructor.
#[starknet::contract]
mod ERC20 {
    use openzeppelin::token::erc20::ERC20Component;
    use openzeppelin::token::erc20::mixins::ERC20MetadataSafeAllowanceMixin as ERC20Mixin;
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: ERC20Mixin, storage: erc20mixin, event: ERC20MixinEvent);

    #[abi(embed_v0)]
    impl ERC20MixinImpl =
        ERC20Mixin::ERC20MetadataSafeAllowanceMixinImpl<ContractState>;
    impl InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        erc20mixin: ERC20Mixin::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        ERC20MixinEvent: ERC20Mixin::Event
    }

    /// Sets the token `name` and `symbol`.
    /// Mints `fixed_supply` tokens to `recipient`.
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
        fixed_supply: u256,
        recipient: ContractAddress
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20._mint(recipient, fixed_supply);
    }
}
