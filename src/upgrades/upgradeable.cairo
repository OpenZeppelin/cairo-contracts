// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (upgrades/upgradeable.cairo)

/// # Upgradeable Component
///
/// The Upgradeable component provides a mechanism to make a contract upgradeable.
#[starknet::component]
mod Upgradeable {
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::ClassHash;

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Upgraded: Upgraded
    }

    /// Emitted when the contract is upgraded.
    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        class_hash: ClassHash
    }

    mod Errors {
        const INVALID_CLASS: felt252 = 'Class hash cannot be zero';
    }

    #[embeddable_as(UpgradeableImpl)]
    impl Upgradeable<
        TContractState, +HasComponent<TContractState>
    > of IUpgradeable<ComponentState<TContractState>> {
        /// Upgrades the contract to a new class.
        fn upgrade(ref self: ComponentState<TContractState>, new_class_hash: ClassHash) {
            self._upgrade(new_class_hash);
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn _upgrade(ref self: ComponentState<TContractState>, new_class_hash: ClassHash) {
            assert(!new_class_hash.is_zero(), Errors::INVALID_CLASS);
            starknet::replace_class_syscall(new_class_hash).unwrap();
            self.emit(Upgraded { class_hash: new_class_hash });
        }
    }
}
