// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v2.0.0-alpha.0
// (governance/src/governor/extensions/governor_votes_super_quorum_fraction.cairo)

/// # GovernorVotesSuperQuorumFraction Component
///
/// Extension of GovernorVotesQuorumFraction with a super quorum expressed as a
/// fraction of the total supply. Proposals that meet the super quorum (and have a majority of for votes)
/// advance to the `Succeeded` state before the proposal deadline.
#[starknet::component]
pub mod GovernorVotesSuperQuorumFractionComponent {
    use core::num::traits::Zero;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_utils::structs::checkpoint::{Trace, TraceTrait};
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use crate::governor::GovernorComponent;
    use crate::governor::GovernorComponent::ComponentState as GovernorComponentState;
    use crate::governor::extensions::interface::{ISuperQuorumFraction, IQuorumFraction};
    use crate::governor::extensions::governor_votes_quorum_fraction::GovernorVotesQuorumFractionComponent;
    use crate::votes::interface::{IVotesDispatcher, IVotesDispatcherTrait};

    #[storage]
    pub struct Storage {
        pub Governor_super_quorum_numerator_history: Trace,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        SuperQuorumNumeratorUpdated: SuperQuorumNumeratorUpdated,
    }

    /// Emitted when the super quorum numerator is updated.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct SuperQuorumNumeratorUpdated {
        pub old_super_quorum_numerator: u256,
        pub new_super_quorum_numerator: u256,
    }

    pub mod Errors {
        pub const INVALID_SUPER_QUORUM_FRACTION: felt252 = 'Invalid super quorum fraction';
        pub const INVALID_SUPER_QUORUM_TOO_SMALL: felt252 = 'Super quorum too small';
        pub const INVALID_QUORUM_TOO_LARGE: felt252 = 'Quorum too large';
    }

    //
    // External
    //

    #[embeddable_as(SuperQuorumFractionImpl)]
    impl SuperQuorumFraction<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of ISuperQuorumFraction<ComponentState<TContractState>> {
        /// Returns the current super quorum numerator.
        fn super_quorum_numerator(self: @ComponentState<TContractState>) -> u256 {
            self.Governor_super_quorum_numerator_history.deref().latest()
        }

        /// Returns the super quorum numerator at a specific timepoint.
        fn super_quorum_numerator(self: @ComponentState<TContractState>, timepoint: u64) -> u256 {
            // Optimistic search: check the latest checkpoint
            let history = self.Governor_super_quorum_numerator_history.deref();
            let (_, key, value) = history.latest_checkpoint();

            if key <= timepoint {
                return value;
            }

            // Fallback to binary search
            history.upper_lookup(timepoint)
        }
        
        /// Returns the super quorum for a timepoint as number of votes.
        fn super_quorum(self: @ComponentState<TContractState>, timepoint: u64) -> u256 {
            // Get the contract instance 
            let contract = self.contract();
            
            // Get the quorum fraction component to access token and denominator
            let quorum_fraction_component = GovernorVotesQuorumFractionComponent::get_component(contract);
            
            // Get the token address and create a dispatcher
            let token = quorum_fraction_component.token();
            let votes_dispatcher = IVotesDispatcher { contract_address: token };
            
            // Get past total supply from the token
            let past_total_supply = votes_dispatcher.get_past_total_supply(timepoint);
            
            // Get super quorum numerator for this timepoint
            let super_quorum_numerator = self.super_quorum_numerator(timepoint);
            
            // Get quorum denominator
            let quorum_denominator = quorum_fraction_component.quorum_denominator();
            
            // Calculate super quorum
            past_total_supply * super_quorum_numerator / quorum_denominator
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +GovernorComponent::HasComponent<TContractState>,
        +GovernorVotesQuorumFractionComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initializes the component with the initial super quorum numerator value.
        ///
        /// Requirements:
        ///
        /// - `super_quorum_numerator` must be less than or equal to `quorum_denominator`.
        /// - `super_quorum_numerator` must be greater than `quorum_numerator`.
        ///
        /// Emits a `SuperQuorumNumeratorUpdated` event.
        fn initializer(
            ref self: ComponentState<TContractState>,
            super_quorum_numerator: u256,
        ) {
            self.update_super_quorum_numerator(super_quorum_numerator);
        }

        /// Updates the super quorum numerator.
        ///
        /// Requirements:
        ///
        /// - `new_super_quorum_numerator` must be less than or equal to `quorum_denominator`.
        /// - `new_super_quorum_numerator` must be greater than `quorum_numerator`.
        ///
        /// May emit a `SuperQuorumNumeratorUpdated` event.
        fn update_super_quorum_numerator(
            ref self: ComponentState<TContractState>, 
            new_super_quorum_numerator: u256,
        ) {
            // Get the contract instance
            let contract = self.contract();
            
            // Get the quorum fraction component to access quorum settings
            let quorum_fraction_component = GovernorVotesQuorumFractionComponent::get_component(contract);
            
            // Get quorum denominator and current quorum numerator
            let denominator = quorum_fraction_component.quorum_denominator();
            let quorum_numerator = quorum_fraction_component.current_quorum_numerator();
            
            // Validate new super quorum numerator
            assert(new_super_quorum_numerator <= denominator, Errors::INVALID_SUPER_QUORUM_FRACTION);
            assert(new_super_quorum_numerator > quorum_numerator, Errors::INVALID_SUPER_QUORUM_TOO_SMALL);

            // Check if we need to update
            let old_super_quorum_numerator = match self.Governor_super_quorum_numerator_history.deref().length() {
                0 => 0, // If no checkpoint exists yet, return 0
                _ => self.super_quorum_numerator(), // Otherwise return the latest value
            };

            // Only update if the value changes
            if old_super_quorum_numerator != new_super_quorum_numerator {
                // Get governor component to access clock
                let governor_component = GovernorComponent::get_component(contract);
                
                // Get current clock value
                let clock = governor_component.clock();
                
                // Update the checkpoint
                self.Governor_super_quorum_numerator_history.deref().push(clock, new_super_quorum_numerator);

                // Emit event
                self.emit(SuperQuorumNumeratorUpdated { 
                    old_super_quorum_numerator, 
                    new_super_quorum_numerator 
                });
            }
        }
        
        /// Checks if the given proposal has reached super quorum with the provided for votes.
        /// Returns true if the for votes are greater than or equal to the super quorum.
        fn has_reached_super_quorum(
            self: @ComponentState<TContractState>,
            snapshot_timepoint: u64,
            for_votes: u256
        ) -> bool {
            let required_super_quorum = self.super_quorum(snapshot_timepoint);
            for_votes >= required_super_quorum
        }
    }
} 