// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v4.0.0-alpha.1
// (presets/src/falcon_512_shake_account.cairo)

/// # Falcon512ShakeAccount Preset
///
/// OpenZeppelin's upgradeable Falcon-512 account using SHAKE-256 hash-to-point and a
/// verifier-checked polynomial-product hint. Supports outside execution by implementing SRC9.
/// Its public-key and signature formats are contract-specific encodings for the FALCON submission
/// verification relation, rather than FN-DSA (FIPS 206) encodings.
#[starknet::contract(account)]
pub mod Falcon512ShakeAccountUpgradeable {
    use openzeppelin_account::extensions::SRC9Component;
    use openzeppelin_account::{Falcon512AccountComponent, Falcon512ShakeVerifier};
    use openzeppelin_interfaces::upgrades::IUpgradeable;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_upgrades::UpgradeableComponent;
    use starknet::ClassHash;

    component!(path: Falcon512AccountComponent, storage: account, event: AccountEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: SRC9Component, storage: src9, event: SRC9Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // Falcon512Account Mixin
    #[abi(embed_v0)]
    pub(crate) impl Falcon512AccountMixinImpl =
        Falcon512AccountComponent::Falcon512AccountMixinImpl<ContractState, Falcon512ShakeVerifier>;
    impl Falcon512AccountInternalImpl = Falcon512AccountComponent::InternalImpl<ContractState>;

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
        pub account: Falcon512AccountComponent::Storage,
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
        AccountEvent: Falcon512AccountComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        SRC9Event: SRC9Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    pub fn constructor(ref self: ContractState, public_key: Array<felt252>) {
        self.account.initializer::<Falcon512ShakeVerifier>(public_key);
        self.src9.initializer();
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.account.assert_only_self();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
