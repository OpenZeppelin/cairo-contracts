// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.1 (presets/src/multisig_account.cairo)

/// # MultisigAccount Preset
///
/// Upgradeable account authorized by a quorum of Stark-curve signer keys. The account can manage
/// its signer set, declare and deploy contracts, execute calls, and perform outside execution
/// through SRC9.
#[starknet::contract(account)]
pub mod MultisigAccountUpgradeable {
    use openzeppelin_account::MultisigAccountComponent;
    use openzeppelin_account::extensions::SRC9Component;
    use openzeppelin_interfaces::upgrades::IUpgradeable;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_upgrades::UpgradeableComponent;
    use starknet::ClassHash;

    component!(
        path: MultisigAccountComponent, storage: multisig_account, event: MultisigAccountEvent,
    );
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: SRC9Component, storage: src9, event: SRC9Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // MultisigAccount Mixin
    #[abi(embed_v0)]
    pub(crate) impl MultisigAccountMixinImpl =
        MultisigAccountComponent::MultisigAccountMixinImpl<ContractState>;
    impl MultisigAccountInternalImpl = MultisigAccountComponent::InternalImpl<ContractState>;

    // SRC9
    #[abi(embed_v0)]
    impl OutsideExecutionV2Impl =
        SRC9Component::OutsideExecutionV2Impl<ContractState>;
    impl OutsideExecutionInternalImpl = SRC9Component::InternalImpl<ContractState>;

    // Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub multisig_account: MultisigAccountComponent::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage,
        #[substorage(v0)]
        pub src9: SRC9Component::Storage,
        #[substorage(v0)]
        pub upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        MultisigAccountEvent: MultisigAccountComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        SRC9Event: SRC9Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    pub fn constructor(ref self: ContractState, quorum: u32, signers: Span<felt252>) {
        self.multisig_account.initializer(quorum, signers);
        self.src9.initializer();
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.multisig_account.assert_only_self();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
