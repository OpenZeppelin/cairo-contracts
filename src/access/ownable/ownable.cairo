// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (access/ownable/ownable.cairo)
//!
//! # Ownable Component
//!
//! The Ownable component provides basic authorization-control functions from a single owner.
#[starknet::component]
mod Ownable {
    use openzeppelin::access::ownable::interface;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        Ownable_owner: ContractAddress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        OwnershipTransferred: OwnershipTransferred
    }

    #[derive(Drop, starknet::Event)]
    struct OwnershipTransferred {
        previous_owner: ContractAddress,
        new_owner: ContractAddress,
    }

    mod Errors {
        const NOT_OWNER: felt252 = 'Caller is not the owner';
        const ZERO_ADDRESS_CALLER: felt252 = 'Caller is the zero address';
        const ZERO_ADDRESS_OWNER: felt252 = 'New owner is the zero address';
    }

    #[embeddable_as(OwnableImpl)]
    impl Ownable<
        TContractState, +HasComponent<TContractState>
    > of interface::IOwnable<ComponentState<TContractState>> {
        /// Returns the address of the current owner.
        fn owner(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Ownable_owner.read()
        }

        /// Transfers ownership of the contract to a new address.
        fn transfer_ownership(
            ref self: ComponentState<TContractState>, new_owner: ContractAddress
        ) {
            assert(!new_owner.is_zero(), Errors::ZERO_ADDRESS_OWNER);
            self.assert_only_owner();
            self._transfer_ownership(new_owner);
        }

        /// Leaves the contract without owner. It will not be possible to call `assert_only_owner`
        /// functions anymore. Can only be called by the current owner.
        fn renounce_ownership(ref self: ComponentState<TContractState>) {
            self.assert_only_owner();
            self._transfer_ownership(Zeroable::zero());
        }
    }

    #[embeddable_as(OwnableCamelOnlyImpl)]
    impl OwnableCamelOnly<
        TContractState, +HasComponent<TContractState>
    > of interface::IOwnableCamelOnly<ComponentState<TContractState>> {
        /// camelCase support for `transfer_ownership`.
        fn transferOwnership(ref self: ComponentState<TContractState>, newOwner: ContractAddress) {
            self.transfer_ownership(newOwner);
        }

        /// camelCase support for `renounce_ownership`.
        fn renounceOwnership(ref self: ComponentState<TContractState>) {
            self.renounce_ownership();
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        /// Sets the contract's initial owner. This function should be called at construction time.
        fn initializer(ref self: ComponentState<TContractState>, owner: ContractAddress) {
            self._transfer_ownership(owner);
        }

        /// Panics if called by any account other than the owner. Use this
        /// to restrict access to certain functions to the owner.
        fn assert_only_owner(self: @ComponentState<TContractState>) {
            let owner: ContractAddress = self.Ownable_owner.read();
            let caller: ContractAddress = get_caller_address();
            assert(!caller.is_zero(), Errors::ZERO_ADDRESS_CALLER);
            assert(caller == owner, Errors::NOT_OWNER);
        }

        /// Internal function that transfers ownership of the contract to a new address.
        /// It doesn't assert the caller.
        fn _transfer_ownership(
            ref self: ComponentState<TContractState>, new_owner: ContractAddress
        ) {
            let previous_owner: ContractAddress = self.Ownable_owner.read();
            self.Ownable_owner.write(new_owner);
            self
                .emit(
                    OwnershipTransferred { previous_owner: previous_owner, new_owner: new_owner }
                );
        }
    }
}
