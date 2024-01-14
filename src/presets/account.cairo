// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0 (presets/account.cairo)

/// # Account Preset
///
/// OpenZeppelin's basic account which can change its public key and declare, deploy, or call contracts.
#[starknet::contract]
mod Account {
    use openzeppelin::account::AccountComponent;
    use openzeppelin::account::mixins::SRC6PubKeyDeclarerDeployerMixin as AccountMixin;
    use openzeppelin::introspection::src5::SRC5Component;

    component!(path: AccountComponent, storage: account, event: AccountEvent);
    component!(path: AccountMixin, storage: accountmixin, event: AccountMixinEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Account
    #[abi(embed_v0)]
    impl AccountMixinImpl =
        AccountMixin::SRC6PubKeyDeclarerDeployerMixinImpl<ContractState>;
    impl AccountInternalImpl = AccountComponent::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        account: AccountComponent::Storage,
        #[substorage(v0)]
        accountmixin: AccountMixin::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccountEvent: AccountComponent::Event,
        #[flat]
        AccountMixinEvent: AccountMixin::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, public_key: felt252) {
        self.account.initializer(public_key);
    }
}
