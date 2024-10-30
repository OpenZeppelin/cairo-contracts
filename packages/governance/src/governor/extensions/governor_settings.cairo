// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.18.0
// (governance/governor/extensions/governor_settings.cairo)

/// # GovernorSettings Component
///
/// Extension of GovernorComponent for settings updatable through governance.
#[starknet::component]
pub mod GovernorSettingsComponent {
    use crate::governor::GovernorComponent::{
        InternalImpl, ComponentState as GovernorComponentState
    };
    use crate::governor::GovernorComponent;
    use crate::governor::extensions::interface::ISetSettings;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    pub struct Storage {
        Governor_voting_delay: u64,
        Governor_voting_period: u64,
        Governor_proposal_threshold: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        VotingDelayUpdated: VotingDelayUpdated,
        VotingPeriodUpdated: VotingPeriodUpdated,
        ProposalThresholdUpdated: ProposalThresholdUpdated
    }

    /// Emitted when `Governor_voting_delay` is updated.
    #[derive(Drop, starknet::Event)]
    pub struct VotingDelayUpdated {
        pub old_voting_delay: u64,
        pub new_voting_delay: u64
    }

    /// Emitted when `Governor_voting_period` is updated.
    #[derive(Drop, starknet::Event)]
    pub struct VotingPeriodUpdated {
        pub old_voting_period: u64,
        pub new_voting_period: u64
    }

    /// Emitted when `Governor_proposal_threshold` is updated.
    #[derive(Drop, starknet::Event)]
    pub struct ProposalThresholdUpdated {
        pub old_proposal_threshold: u256,
        pub new_proposal_threshold: u256
    }

    mod Errors {
        pub const INVALID_VOTING_PERIOD: felt252 = 'Invalid voting period';
    }

    //
    // Extensions
    //

    impl GovernorSettings<
        TContractState,
        +GovernorComponent::ImmutableConfig,
        +GovernorComponent::HasComponent<TContractState>,
        +GovernorComponent::GovernorQuorumTrait<TContractState>,
        +GovernorComponent::GovernorCountingTrait<TContractState>,
        +GovernorComponent::GovernorVotesTrait<TContractState>,
        +GovernorComponent::GovernorExecuteTrait<TContractState>,
        +GovernorComponent::GovernorQueueTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        impl GovernorSettings: HasComponent<TContractState>,
        +Drop<TContractState>
    > of GovernorComponent::GovernorSettingsTrait<TContractState> {
        /// See `GovernorComponent::GovernorSettingsTrait::voting_delay`.
        fn voting_delay(self: @GovernorComponentState<TContractState>) -> u64 {
            let contract = self.get_contract();
            let this_component = GovernorSettings::get_component(contract);

            this_component.Governor_voting_delay.read()
        }

        /// See `GovernorComponent::GovernorSettingsTrait::voting_period`.
        fn voting_period(self: @GovernorComponentState<TContractState>) -> u64 {
            let contract = self.get_contract();
            let this_component = GovernorSettings::get_component(contract);

            this_component.Governor_voting_period.read()
        }

        /// See `GovernorComponent::GovernorSettingsTrait::proposal_threshold`.
        fn proposal_threshold(self: @GovernorComponentState<TContractState>) -> u256 {
            let contract = self.get_contract();
            let this_component = GovernorSettings::get_component(contract);

            this_component.Governor_proposal_threshold.read()
        }
    }

    //
    // External
    //

    #[embeddable_as(SetSettingsImpl)]
    impl SetSettings<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of ISetSettings<ComponentState<TContractState>> {
        /// Sets the voting delay.
        ///
        /// Emits a `VotingDelayUpdated` event.
        fn set_voting_delay(ref self: ComponentState<TContractState>, voting_delay: u64) {
            self
                .emit(
                    VotingDelayUpdated {
                        old_voting_delay: self.Governor_voting_delay.read(),
                        new_voting_delay: voting_delay
                    }
                );
            self.Governor_voting_delay.write(voting_delay);
        }

        /// Sets the voting period.
        ///
        /// Requirements:
        ///
        /// - `voting_period` must be greater than 0.
        ///
        /// Emits a `VotingPeriodUpdated` event.
        fn set_voting_period(ref self: ComponentState<TContractState>, voting_period: u64) {
            assert(voting_period > 0, Errors::INVALID_VOTING_PERIOD);

            self
                .emit(
                    VotingPeriodUpdated {
                        old_voting_period: self.Governor_voting_period.read(),
                        new_voting_period: voting_period
                    }
                );
            self.Governor_voting_period.write(voting_period);
        }

        /// Sets the proposal threshold.
        ///
        /// Emits a `ProposalThresholdUpdated` event.
        fn set_proposal_threshold(
            ref self: ComponentState<TContractState>, proposal_threshold: u256
        ) {
            self
                .emit(
                    ProposalThresholdUpdated {
                        old_proposal_threshold: self.Governor_proposal_threshold.read(),
                        new_proposal_threshold: proposal_threshold
                    }
                );
            self.Governor_proposal_threshold.write(proposal_threshold);
        }
    }
}
