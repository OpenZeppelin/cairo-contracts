// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.18.0
// (governance/governor/extensions/governor_votes_quorum_fractional.cairo)

/// # GovernorVotesQuorumFraction Component
///
/// Extension of GovernorComponent for voting weight extraction from an ERC20 token with the Votes
/// extension and a quorum expressed as a fraction of the total supply.
#[starknet::component]
pub mod GovernorVotesQuorumFractionComponent {
    use crate::governor::GovernorComponent::{
        InternalImpl as GovernorInternalImpl, ComponentState as GovernorComponentState
    };
    use crate::governor::GovernorComponent;
    use crate::governor::extensions::interface::IQuorumFraction;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_utils::structs::checkpoint::{Trace, TraceTrait};
    use starknet::ContractAddress;

    #[storage]
    pub struct Storage {
        Governor_quorum_numerator_history: Trace,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        QuorumNumeratorUpdated: QuorumNumeratorUpdated
    }

    /// Emitted when the quorum numerator is updated.
    #[derive(Drop, starknet::Event)]
    pub struct QuorumNumeratorUpdated {
        pub old_quorum_numerator: u256,
        pub new_quorum_numerator: u256
    }

    mod Errors {
        pub const INVALID_QUORUM_FRACTION: felt252 = 'Invalid quorum fraction';
    }

    //
    // Extensions
    //

    impl GovernorVotes<
        TContractState,
        +GovernorComponent::HasComponent<TContractState>,
        +GovernorComponent::GovernorQuorumTrait<TContractState>,
        +GovernorComponent::GovernorSettingsTrait<TContractState>,
        +GovernorComponent::GovernorExecuteTrait<TContractState>,
        +GovernorComponent::GovernorQueueTrait<TContractState>,
        +GovernorComponent::GovernorProposeTrait<TContractState>,
        +GovernorComponent::GovernorCountingTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        impl GovernorVotesQuorumFraction: HasComponent<TContractState>,
        +Drop<TContractState>
    > of GovernorComponent::GovernorVotesTrait<TContractState> {
        /// See `GovernorComponent::GovernorVotesTrait::clock`.
        fn clock(self: @GovernorComponentState<TContractState>) -> u64 {
            1
        }

        /// See `GovernorComponent::GovernorVotesTrait::CLOCK_MODE`.
        fn clock_mode(self: @GovernorComponentState<TContractState>) -> ByteArray {
            ""
        }

        /// See `GovernorComponent::GovernorVotesTrait::voting_delay`.
        fn voting_delay(self: @GovernorComponentState<TContractState>) -> u64 {
            1
        }

        /// See `GovernorComponent::GovernorVotesTrait::voting_period`.
        fn voting_period(self: @GovernorComponentState<TContractState>) -> u64 {
            1
        }

        /// See `GovernorComponent::GovernorVotesTrait::get_votes`.
        fn get_votes(
            self: @GovernorComponentState<TContractState>,
            account: ContractAddress,
            timepoint: u64,
            params: Span<felt252>
        ) -> u256 {
            1
        }
    }

    //
    // External
    //

    #[embeddable_as(QuorumFractionImpl)]
    impl QuorumFraction<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of IQuorumFraction<ComponentState<TContractState>> {
        /// Returns the current quorum numerator.
        fn current_quorum_numerator(self: @ComponentState<TContractState>) -> u256 {
            self.Governor_quorum_numerator_history.deref().latest()
        }

        /// Returns the quorum numerator at a specific timepoint.
        fn quorum_numerator(self: @ComponentState<TContractState>, timepoint: u64) -> u256 {
            // Optimistic search: check the latest checkpoint.
            // The initializer call ensures that there is at least one checkpoint in the history.
            //
            // NOTE: This optimization is specially helpful when the supply is not updated often.
            let (_, key, value) = self
                .Governor_quorum_numerator_history
                .deref()
                .latest_checkpoint();

            if key <= timepoint {
                return value;
            }

            // Fallback to the binary search
            self.Governor_quorum_numerator_history.deref().upper_lookup(timepoint)
        }

        /// Returns the quorum denominator.
        fn quorum_denominator(self: @ComponentState<TContractState>) -> u256 {
            100
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +GovernorComponent::GovernorVotesTrait<TContractState>,
        impl Governor: GovernorComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Initializes the component by setting the initial quorum numerator value.
        ///
        /// Requirements:
        ///
        /// - `quorum_numerator` must be less than `quorum_denominator`.
        ///
        /// Emits a `QuorumNumeratorUpdated` event.
        fn initialize(ref self: ComponentState<TContractState>, quorum_numerator: u256) {
            self.update_quorum_numerator(quorum_numerator);
        }

        /// Updates the quorum numerator.
        ///
        /// Requirements:
        ///
        /// - `new_quorum_numerator` must be less than `quorum_denominator`.
        ///
        /// Emits a `QuorumNumeratorUpdated` event.
        fn update_quorum_numerator(
            ref self: ComponentState<TContractState>, new_quorum_numerator: u256
        ) {
            let denominator = self.quorum_denominator();

            assert(new_quorum_numerator <= denominator, Errors::INVALID_QUORUM_FRACTION);

            let old_quorum_numerator = self.current_quorum_numerator();
            let governor_component = get_dep_component_mut!(ref self, Governor);
            let clock = governor_component.clock();

            self.Governor_quorum_numerator_history.deref().push(clock, new_quorum_numerator);

            self.emit(QuorumNumeratorUpdated { old_quorum_numerator, new_quorum_numerator });
        }
    }
}
