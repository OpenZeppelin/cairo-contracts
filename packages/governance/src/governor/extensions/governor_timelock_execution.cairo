// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.18.0
// (governance/governor/extensions/governor_core_execution.cairo)

/// # GovernorTimelockExecution Component
///
/// Extension of GovernorComponent that binds the execution process to an instance of a contract
/// implementing TimelockControllerComponent. This adds a delay, enforced by the TimelockController
/// to all successful proposal (in addition to the voting duration). The Governor needs the proposer
/// (and ideally the executor and canceller) roles for the Governor to work properly.
///
/// Using this model means the proposal will be operated by the TimelockController and not by the
/// Governor. Thus, the assets and permissions must be attached to the TimelockController. Any asset
/// sent to the Governor will be inaccessible from a proposal, unless executed via
/// `Governor::relay`.
///
/// WARNING: Setting up the TimelockController to have additional proposers or cancellers besides
/// the governor is very risky, as it grants them the ability to: 1) execute operations as the
/// timelock, and thus possibly performing operations or accessing funds that are expected to only
/// be accessible through a vote, and 2) block governance proposals that have been approved by the
/// voters, effectively executing a Denial of Service attack.
#[starknet::component]
pub mod GovernorTimelockExecutionComponent {
    use core::num::traits::Zero;
    use crate::governor::GovernorComponent::{
        InternalExtendedTrait, ComponentState as GovernorComponentState
    };
    use crate::governor::GovernorComponent;
    use crate::governor::extensions::interface::ITimelockController;
    use crate::governor::interface::ProposalState;
    use crate::timelock::interface::{ITimelockDispatcher, ITimelockDispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use starknet::account::Call;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    type ProposalId = felt252;
    type TimelockProposalId = felt252;

    #[storage]
    pub struct Storage {
        Governor_timelock_controller: ContractAddress,
        Governor_timelock_ids: Map<ProposalId, TimelockProposalId>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TimelockUpdated: TimelockUpdated,
    }

    /// Emitted when the timelock controller used for proposal execution is modified.
    #[derive(Drop, starknet::Event)]
    pub struct TimelockUpdated {
        pub old_timelock: ContractAddress,
        pub new_timelock: ContractAddress
    }

    mod Errors {
        pub const INVALID_TIMELOCK_CONTROLLER: felt252 = 'Invalid timelock controller';
    }

    //
    // Extensions
    //

    pub impl GovernorExecution<
        TContractState,
        +GovernorComponent::HasComponent<TContractState>,
        +GovernorComponent::GovernorSettingsTrait<TContractState>,
        +GovernorComponent::GovernorCountingTrait<TContractState>,
        +GovernorComponent::GovernorVotesTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        impl GovernorCoreExecution: HasComponent<TContractState>,
        +Drop<TContractState>
    > of GovernorComponent::GovernorExecutionTrait<TContractState> {
        /// See `GovernorComponent::GovernorExecutionTrait::state`.
        fn state(
            self: @GovernorComponentState<TContractState>, proposal_id: felt252
        ) -> ProposalState {
            let current_state = self._state(proposal_id);

            if current_state != ProposalState::Queued {
                return current_state;
            }

            let contract = self.get_contract();
            let this_component = GovernorCoreExecution::get_component(contract);

            let queue_id = this_component.Governor_timelock_ids.read(proposal_id);
            let timelock_controller = this_component.timelock();
            let timelock_dispatcher = ITimelockDispatcher { contract_address: timelock_controller };

            if timelock_dispatcher.is_operation_pending(queue_id) {
                ProposalState::Queued
            } else if timelock_dispatcher.is_operation_done(queue_id) {
                // This can happen if the proposal is executed directly on the timelock.
                ProposalState::Executed
            } else {
                // This can happen if the proposal is canceled directly on the timelock.
                ProposalState::Canceled
            }
        }

        /// See `GovernorComponent::GovernorExecutionTrait::executor`.
        ///
        /// In this module, the executor is the timelock controller.
        fn executor(self: @GovernorComponentState<TContractState>) -> ContractAddress {
            let contract = self.get_contract();
            let this_component = GovernorCoreExecution::get_component(contract);

            this_component.timelock()
        }

        /// See `GovernorComponent::GovernorExecutionTrait::execute_operations`.
        ///
        /// Runs the already queued proposal through the timelock.
        fn execute_operations(
            ref self: GovernorComponentState<TContractState>,
            proposal_id: felt252,
            calls: Span<Call>,
            description_hash: felt252
        ) {
            let mut contract = self.get_contract_mut();
            let mut this_component = GovernorCoreExecution::get_component_mut(ref contract);

            let timelock_controller = this_component.Governor_timelock_controller.read();
            let timelock_dispatcher = ITimelockDispatcher { contract_address: timelock_controller };

            timelock_dispatcher
                .execute_batch(calls, 0, this_component.timelock_salt(description_hash));

            // Cleanup
            this_component.Governor_timelock_ids.write(proposal_id, 0);
        }

        /// See `GovernorComponent::GovernorExecutionTrait::queue_operations`.
        ///
        /// Queue a proposal to the timelock.
        fn queue_operations(
            ref self: GovernorComponentState<TContractState>,
            proposal_id: felt252,
            calls: Span<Call>,
            description_hash: felt252
        ) -> u64 {
            let mut contract = self.get_contract_mut();
            let mut this_component = GovernorCoreExecution::get_component_mut(ref contract);

            let timelock_controller = this_component.timelock();
            let timelock_dispatcher = ITimelockDispatcher { contract_address: timelock_controller };

            let delay = timelock_dispatcher.get_min_delay();
            let salt = this_component.timelock_salt(description_hash);

            let queue_id = timelock_dispatcher.hash_operation_batch(calls, 0, salt);
            this_component.Governor_timelock_ids.write(proposal_id, queue_id);

            timelock_dispatcher.schedule_batch(calls, 0, salt, delay);

            starknet::get_block_timestamp() + delay
        }

        /// See `GovernorComponent::GovernorExecutionTrait::proposal_needs_queuing`.
        fn proposal_needs_queuing(
            self: @GovernorComponentState<TContractState>, proposal_id: felt252
        ) -> bool {
            true
        }

        /// See `GovernorComponent::GovernorExecutionTrait::cancel_operations`.
        ///
        /// Cancels the timelocked proposal if it has already been queued.
        ///
        /// NOTE: This function can reenter through the external call to the timelock, but we assume
        /// the timelock is trusted and well behaved (according to TimelockController) and this will
        /// not happen.
        fn cancel_operations(
            ref self: GovernorComponentState<TContractState>,
            proposal_id: felt252,
            description_hash: felt252
        ) {
            self._cancel(proposal_id, description_hash);

            let mut contract = self.get_contract_mut();
            let mut this_component = GovernorCoreExecution::get_component_mut(ref contract);

            let timelock_id = this_component.Governor_timelock_ids.read(proposal_id);
            if timelock_id.is_non_zero() {
                let timelock_controller = this_component.timelock();
                let timelock_dispatcher = ITimelockDispatcher {
                    contract_address: timelock_controller
                };

                timelock_dispatcher.cancel(timelock_id);
                this_component.Governor_timelock_ids.write(proposal_id, 0);
            }
        }
    }

    //
    // External
    //

    #[embeddable_as(TimelockControllerImpl)]
    impl TimelockController<
        TContractState,
        +HasComponent<TContractState>,
        +GovernorComponent::GovernorSettingsTrait<TContractState>,
        +GovernorComponent::GovernorCountingTrait<TContractState>,
        +GovernorComponent::GovernorVotesTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +GovernorComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of ITimelockController<ComponentState<TContractState>> {
        /// Returns the token that voting power is sourced from.
        fn timelock(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Governor_timelock_controller.read()
        }

        /// Updates the associated timelock.
        ///
        /// Requirements:
        ///
        /// - Caller must be the governance.
        ///
        /// Emits a `TimelockUpdated` event.
        fn update_timelock(
            ref self: ComponentState<TContractState>, new_timelock: ContractAddress
        ) {
            self.assert_only_governance();
            self._update_timelock(new_timelock);
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +GovernorComponent::GovernorSettingsTrait<TContractState>,
        +GovernorComponent::GovernorCountingTrait<TContractState>,
        +GovernorComponent::GovernorVotesTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        impl Governor: GovernorComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Initializes the component by setting the timelock contract address.
        ///
        /// Requirements:
        ///
        /// - `timelock_controller` must not be zero.
        fn initializer(
            ref self: ComponentState<TContractState>, timelock_controller: ContractAddress
        ) {
            assert(timelock_controller.is_non_zero(), Errors::INVALID_TIMELOCK_CONTROLLER);
            self._update_timelock(timelock_controller);
        }

        /// Wrapper for `Governor::assert_only_governance`.
        fn assert_only_governance(self: @ComponentState<TContractState>) {
            let governor_component = get_dep_component!(self, Governor);
            governor_component.assert_only_governance();
        }

        /// Computes the `TimelockController` operation salt.
        ///
        /// It is computed with the governor address itself to avoid collisions across
        /// governor instances using the same timelock.
        fn timelock_salt(
            self: @ComponentState<TContractState>, description_hash: felt252
        ) -> felt252 {
            let description_hash: u256 = description_hash.into();
            let this: felt252 = starknet::get_contract_address().into();

            // Unwrap is safe since the u256 value came from a felt252.
            (this.into() ^ description_hash).try_into().unwrap()
        }

        /// Updates the timelock contract address.
        ///
        /// Emits a `TimelockUpdated` event.
        fn _update_timelock(
            ref self: ComponentState<TContractState>, new_timelock: ContractAddress
        ) {
            let old_timelock = self.Governor_timelock_controller.read();
            self.emit(TimelockUpdated { old_timelock, new_timelock });
            self.Governor_timelock_controller.write(new_timelock);
        }
    }
}
