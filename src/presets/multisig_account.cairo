// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.9.0 (presets/account.cairo)

/// # Account Preset
///
/// OpenZeppelin's basic account which can change its public key and declare, deploy, or call contracts.
#[starknet::contract(multisig_account)]
mod MultisigAccount {
    use openzeppelin::account::multisig_account::MultisigAccountComponent;
    use openzeppelin::introspection::src5::SRC5Component;

    component!(path: MultisigAccountComponent, storage: account, event: AccountEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Account
    #[abi(embed_v0)]
    impl SRC6Impl = MultisigAccountComponent::SRC6Impl<ContractState>;
    #[abi(embed_v0)]
    impl SRC6CamelOnlyImpl =
        MultisigAccountComponent::SRC6CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl PublicKeysImpl = MultisigAccountComponent::PublicKeysImpl<ContractState>;
    #[abi(embed_v0)]
    impl PublicKeysCamelImpl =
        MultisigAccountComponent::PublicKeysCamelImpl<ContractState>;
    #[abi(embed_v0)]
    impl DeclarerImpl = MultisigAccountComponent::DeclarerImpl<ContractState>;
    #[abi(embed_v0)]
    impl DeployableImpl = MultisigAccountComponent::DeployableImpl<ContractState>;
    impl AccountInternalImpl = MultisigAccountComponent::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        account: MultisigAccountComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccountEvent: MultisigAccountComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, public_key: felt252) {
        self.account.initializer(public_key);
    }
}
