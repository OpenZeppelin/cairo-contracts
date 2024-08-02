// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.15.0-rc.0 (presets/eth_account.cairo)

/// # EthAccount Preset
///
/// OpenZeppelin's upgradeable account which can change its public key and declare,
/// deploy, or call contracts, using Ethereum signing keys.
#[starknet::contract(account)]
pub(crate) mod EthAccountUpgradeable {
    use openzeppelin_account::EthAccountComponent;
    use openzeppelin_account::interface::EthPublicKey;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_upgrades::UpgradeableComponent;
    use openzeppelin_upgrades::interface::IUpgradeable;
    use starknet::ClassHash;

    component!(path: EthAccountComponent, storage: eth_account, event: EthAccountEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // EthAccount Mixin
    #[abi(embed_v0)]
    pub(crate) impl EthAccountMixinImpl =
        EthAccountComponent::EthAccountMixinImpl<ContractState>;
    impl EthAccountInternalImpl = EthAccountComponent::InternalImpl<ContractState>;

    // Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        eth_account: EthAccountComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        EthAccountEvent: EthAccountComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event
    }

    #[constructor]
    pub(crate) fn constructor(ref self: ContractState, public_key: EthPublicKey) {
        self.eth_account.initializer(public_key);
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.eth_account.assert_only_self();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
