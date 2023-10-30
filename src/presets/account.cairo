// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (account/presets/account.cairo)

/// # Account Preset
///
/// Openzeppelin's account contract.
#[starknet::contract]
mod Account {
    use openzeppelin::account::Account as account_component;
    use openzeppelin::introspection::src5::SRC5 as src5_component;

    component!(path: account_component, storage: account, event: AccountEvent);
    component!(path: src5_component, storage: src5, event: SRC5Event);

    // Account
    #[abi(embed_v0)]
    impl SRC6Impl = account_component::SRC6Impl<ContractState>;
    #[abi(embed_v0)]
    impl SRC6CamelOnlyImpl = account_component::SRC6CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl PublicKeyImpl = account_component::PublicKeyImpl<ContractState>;
    #[abi(embed_v0)]
    impl PublicKeyCamelImpl = account_component::PublicKeyCamelImpl<ContractState>;
    #[abi(embed_v0)]
    impl DeclarerImpl = account_component::DeclarerImpl<ContractState>;
    #[abi(embed_v0)]
    impl DeployableImpl = account_component::DeployableImpl<ContractState>;
    impl AccountInternalImpl = account_component::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = src5_component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        account: account_component::Storage,
        #[substorage(v0)]
        src5: src5_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccountEvent: account_component::Event,
        #[flat]
        SRC5Event: src5_component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, public_key: felt252) {
        self.account.initializer(public_key);
    }
}
