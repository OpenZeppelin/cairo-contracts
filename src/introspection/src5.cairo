// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.12.0 (introspection/src5.cairo)

/// # SRC5 Component
///
/// The SRC5 component allows contracts to expose the interfaces they implement.
#[starknet::component]
mod SRC5Component {
    use openzeppelin::introspection::interface;

    #[storage]
    struct Storage {
        SRC5_supported_interfaces: LegacyMap<felt252, bool>
    }

    mod Errors {
        const INVALID_ID: felt252 = 'SRC5: invalid id';
    }

    #[embeddable_as(SRC5Impl)]
    impl SRC5<
        TContractState, +HasComponent<TContractState>
    > of interface::ISRC5<ComponentState<TContractState>> {
        /// Returns whether the contract implements the given interface.
        fn supports_interface(
            self: @ComponentState<TContractState>, interface_id: felt252
        ) -> bool {
            if interface_id == interface::ISRC5_ID {
                return true;
            }
            self.SRC5_supported_interfaces.read(interface_id)
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        /// Registers the given interface as supported by the contract.
        fn register_interface(ref self: ComponentState<TContractState>, interface_id: felt252) {
            self.SRC5_supported_interfaces.write(interface_id, true);
        }

        /// Deregisters the given interface as supported by the contract.
        ///
        /// Requirements:
        ///
        /// - `interface_id` is not `ISRC5_ID`
        fn deregister_interface(ref self: ComponentState<TContractState>, interface_id: felt252) {
            assert(interface_id != interface::ISRC5_ID, Errors::INVALID_ID);
            self.SRC5_supported_interfaces.write(interface_id, false);
        }
    }
}
