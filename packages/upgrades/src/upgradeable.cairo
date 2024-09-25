// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.17.0 (upgrades/upgradeable.cairo)

/// # Upgradeable Component
///
/// The Upgradeable component provides a mechanism to make a contract upgradeable.
#[starknet::component]
pub mod UpgradeableComponent {
    use core::num::traits::Zero;
    use starknet::ClassHash;
    use starknet::SyscallResultTrait;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        Upgraded: Upgraded
    }

    /// Emitted when the contract is upgraded.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Upgraded {
        pub class_hash: ClassHash
    }

    pub mod Errors {
        pub const INVALID_CLASS: felt252 = 'Class hash cannot be zero';
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        /// Replaces the contract's class hash with `new_class_hash`.
        ///
        /// Requirements:
        ///
        /// - `new_class_hash` is not zero.
        ///
        /// Emits an `Upgraded` event.
        fn upgrade(ref self: ComponentState<TContractState>, new_class_hash: ClassHash) {
            assert(!new_class_hash.is_zero(), Errors::INVALID_CLASS);
            starknet::syscalls::replace_class_syscall(new_class_hash).unwrap_syscall();
            self.emit(Upgraded { class_hash: new_class_hash });
        }
    }
}
