// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.12.0 (access/ownable/ownable.cairo)

/// # Ownable Component
///
/// The Ownable component provides a basic access control mechanism, where
/// there is an account (an owner) that can be granted exclusive access to
/// specific functions.
///
/// The initial owner can be set by using the `initializer` function in
/// construction time. This can later be changed with `transfer_ownership`.
///
/// The component also offers functionality for a two-step ownership
/// transfer where the new owner first has to accept their ownership to
/// finalize the transfer.
#[starknet::component]
mod OwnableComponent {
    use openzeppelin::access::ownable::interface::IOwnableTwoStep;
    use openzeppelin::access::ownable::interface;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        Ownable_owner: ContractAddress,
        Ownable_pending_owner: ContractAddress
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        OwnershipTransferred: OwnershipTransferred,
        OwnershipTransferStarted: OwnershipTransferStarted
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct OwnershipTransferred {
        #[key]
        previous_owner: ContractAddress,
        #[key]
        new_owner: ContractAddress,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct OwnershipTransferStarted {
        #[key]
        previous_owner: ContractAddress,
        #[key]
        new_owner: ContractAddress,
    }

    mod Errors {
        const NOT_OWNER: felt252 = 'Caller is not the owner';
        const NOT_PENDING_OWNER: felt252 = 'Caller is not the pending owner';
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
        ///
        /// Requirements:
        ///
        /// - `new_owner` is not the zero address.
        /// - The caller is the contract owner.
        ///
        /// Emits an `OwnershipTransferred` event.
        fn transfer_ownership(
            ref self: ComponentState<TContractState>, new_owner: ContractAddress
        ) {
            assert(!new_owner.is_zero(), Errors::ZERO_ADDRESS_OWNER);
            self.assert_only_owner();
            self._transfer_ownership(new_owner);
        }

        /// Leaves the contract without owner. It will not be possible to call `assert_only_owner`
        /// functions anymore. Can only be called by the current owner.
        ///
        /// Requirements:
        ///
        /// - The caller is the contract owner.
        ///
        /// Emits an `OwnershipTransferred` event.
        fn renounce_ownership(ref self: ComponentState<TContractState>) {
            self.assert_only_owner();
            self._transfer_ownership(Zeroable::zero());
        }
    }

    /// Adds support for two step ownership transfer.
    #[embeddable_as(OwnableTwoStepImpl)]
    impl OwnableTwoStep<
        TContractState, +HasComponent<TContractState>
    > of interface::IOwnableTwoStep<ComponentState<TContractState>> {
        /// Returns the address of the current owner.
        fn owner(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Ownable_owner.read()
        }

        /// Returns the address of the pending owner.
        fn pending_owner(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Ownable_pending_owner.read()
        }

        /// Finishes the two-step ownership transfer process by accepting the ownership.
        /// Can only be called by the pending owner.
        fn accept_ownership(ref self: ComponentState<TContractState>) {
            let caller = get_caller_address();
            let pending_owner = self.Ownable_pending_owner.read();
            assert(caller == pending_owner, Errors::NOT_PENDING_OWNER);
            self._accept_ownership();
        }

        /// Starts the two-step ownership transfer process by setting the pending owner.
        fn transfer_ownership(
            ref self: ComponentState<TContractState>, new_owner: ContractAddress
        ) {
            self.assert_only_owner();
            self._propose_owner(new_owner);
        }

        /// Leaves the contract without owner. It will not be possible to call `assert_only_owner`
        /// functions anymore. Can only be called by the current owner.
        fn renounce_ownership(ref self: ComponentState<TContractState>) {
            Ownable::renounce_ownership(ref self);
        }
    }

    /// Adds camelCase support for `IOwnable`.
    #[embeddable_as(OwnableCamelOnlyImpl)]
    impl OwnableCamelOnly<
        TContractState, +HasComponent<TContractState>
    > of interface::IOwnableCamelOnly<ComponentState<TContractState>> {
        fn transferOwnership(ref self: ComponentState<TContractState>, newOwner: ContractAddress) {
            Ownable::transfer_ownership(ref self, newOwner);
        }

        fn renounceOwnership(ref self: ComponentState<TContractState>) {
            Ownable::renounce_ownership(ref self);
        }
    }

    /// Adds camelCase support for `IOwnableTwoStep`.
    #[embeddable_as(OwnableTwoStepCamelOnlyImpl)]
    impl OwnableTwoStepCamelOnly<
        TContractState, +HasComponent<TContractState>
    > of interface::IOwnableTwoStepCamelOnly<ComponentState<TContractState>> {
        fn pendingOwner(self: @ComponentState<TContractState>) -> ContractAddress {
            OwnableTwoStep::pending_owner(self)
        }

        fn acceptOwnership(ref self: ComponentState<TContractState>) {
            self.accept_ownership();
        }

        fn transferOwnership(ref self: ComponentState<TContractState>, newOwner: ContractAddress) {
            OwnableTwoStep::transfer_ownership(ref self, newOwner);
        }

        fn renounceOwnership(ref self: ComponentState<TContractState>) {
            OwnableTwoStep::renounce_ownership(ref self);
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        /// Sets the contract's initial owner.
        ///
        /// This function should be called at construction time.
        fn initializer(ref self: ComponentState<TContractState>, owner: ContractAddress) {
            self._transfer_ownership(owner);
        }

        /// Panics if called by any account other than the owner. Use this
        /// to restrict access to certain functions to the owner.
        fn assert_only_owner(self: @ComponentState<TContractState>) {
            let owner = self.Ownable_owner.read();
            let caller = get_caller_address();
            assert(!caller.is_zero(), Errors::ZERO_ADDRESS_CALLER);
            assert(caller == owner, Errors::NOT_OWNER);
        }

        /// Transfers ownership to the pending owner.
        ///
        /// Internal function without access restriction.
        fn _accept_ownership(ref self: ComponentState<TContractState>) {
            let pending_owner = self.Ownable_pending_owner.read();
            self.Ownable_pending_owner.write(Zeroable::zero());
            self._transfer_ownership(pending_owner);
        }

        /// Sets a new pending owner.
        ///
        /// Internal function without access restriction.
        fn _propose_owner(ref self: ComponentState<TContractState>, new_owner: ContractAddress) {
            let previous_owner = self.Ownable_owner.read();
            self.Ownable_pending_owner.write(new_owner);
            self
                .emit(
                    OwnershipTransferStarted {
                        previous_owner: previous_owner, new_owner: new_owner
                    }
                );
        }

        /// Transfers ownership of the contract to a new address.
        ///
        /// Internal function without access restriction.
        ///
        /// Emits an `OwnershipTransferred` event.
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

    #[embeddable_as(OwnableMixinImpl)]
    impl OwnableMixin<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of interface::OwnableABI<ComponentState<TContractState>> {
        // IOwnable
        fn owner(self: @ComponentState<TContractState>) -> ContractAddress {
            Ownable::owner(self)
        }

        fn transfer_ownership(
            ref self: ComponentState<TContractState>, new_owner: ContractAddress
        ) {
            Ownable::transfer_ownership(ref self, new_owner);
        }

        fn renounce_ownership(ref self: ComponentState<TContractState>) {
            Ownable::renounce_ownership(ref self);
        }

        // IOwnableCamelOnly
        fn transferOwnership(ref self: ComponentState<TContractState>, newOwner: ContractAddress) {
            OwnableCamelOnly::transferOwnership(ref self, newOwner);
        }

        fn renounceOwnership(ref self: ComponentState<TContractState>) {
            OwnableCamelOnly::renounceOwnership(ref self);
        }
    }

    #[embeddable_as(OwnableTwoStepMixinImpl)]
    impl OwnableTwoStepMixin<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of interface::OwnableTwoStepABI<ComponentState<TContractState>> {
        // IOwnableTwoStep
        fn owner(self: @ComponentState<TContractState>) -> ContractAddress {
            OwnableTwoStep::owner(self)
        }

        fn pending_owner(self: @ComponentState<TContractState>) -> ContractAddress {
            OwnableTwoStep::pending_owner(self)
        }

        fn accept_ownership(ref self: ComponentState<TContractState>) {
            OwnableTwoStep::accept_ownership(ref self);
        }

        fn transfer_ownership(
            ref self: ComponentState<TContractState>, new_owner: ContractAddress
        ) {
            OwnableTwoStep::transfer_ownership(ref self, new_owner);
        }

        fn renounce_ownership(ref self: ComponentState<TContractState>) {
            OwnableTwoStep::renounce_ownership(ref self);
        }

        // IOwnableTwoStepCamelOnly
        fn pendingOwner(self: @ComponentState<TContractState>) -> ContractAddress {
            OwnableTwoStepCamelOnly::pendingOwner(self)
        }

        fn acceptOwnership(ref self: ComponentState<TContractState>) {
            OwnableTwoStepCamelOnly::acceptOwnership(ref self);
        }

        fn transferOwnership(ref self: ComponentState<TContractState>, newOwner: ContractAddress) {
            OwnableTwoStepCamelOnly::transferOwnership(ref self, newOwner);
        }

        fn renounceOwnership(ref self: ComponentState<TContractState>) {
            OwnableTwoStepCamelOnly::renounceOwnership(ref self);
        }
    }
}
