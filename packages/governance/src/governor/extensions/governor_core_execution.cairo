// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.18.0
// (governance/governor/extensions/governor_core_execution.cairo)

/// # GovernorCoreExecution Component
///
/// Extension of GovernorComponent providing an execution mechanism directly through
/// the Governor itself. For a timelocked execution mechanism, see
/// GovernorTimelockExecutionComponent.
#[starknet::component]
pub mod GovernorCoreExecutionComponent {
    use core::num::traits::Zero;
    use crate::governor::GovernorComponent::{
        InternalImpl as GovernorInternalImpl, ComponentState as GovernorComponentState
    };
    use crate::governor::GovernorComponent;
    use crate::governor::extensions::interface::IVotesToken;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use starknet::SyscallResultTrait;
    use starknet::account::Call;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    pub struct Storage {
        Governor_token: ContractAddress
    }

    mod Errors {
        pub const INVALID_TOKEN: felt252 = 'Invalid votes token';
    }

    //
    // Extensions
    //

    impl GovernorExecution<
        TContractState,
        +GovernorComponent::HasComponent<TContractState>,
        +GovernorComponent::GovernorCountingTrait<TContractState>,
        +GovernorComponent::GovernorSettingsTrait<TContractState>,
        +GovernorComponent::GovernorVotesTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +GovernorComponent::ImmutableConfig,
        impl GovernorCoreExecution: HasComponent<TContractState>,
        +Drop<TContractState>
    > of GovernorComponent::GovernorExecutionTrait<TContractState> {
        /// See `GovernorComponent::GovernorExecutionTrait::executor`.
        fn executor(self: @GovernorComponentState<TContractState>) -> ContractAddress {
            starknet::get_contract_address()
        }

        /// See `GovernorComponent::GovernorExecutionTrait::execute_operations`.
        fn execute_operations(
            ref self: GovernorComponentState<TContractState>,
            proposal_id: felt252,
            calls: Span<Call>,
            description_hash: felt252
        ) {
            for call in calls {
                let Call { to, selector, calldata } = *call;
                starknet::syscalls::call_contract_syscall(to, selector, calldata).unwrap_syscall();
            };
        }

        /// See `GovernorComponent::GovernorExecutionTrait::queue_operations`.
        fn queue_operations(
            ref self: GovernorComponentState<TContractState>,
            proposal_id: felt252,
            calls: Span<Call>,
            description_hash: felt252
        ) -> u64 {
            0
        }

        /// See `GovernorComponent::GovernorExecutionTrait::proposal_needs_queuing`.
        fn proposal_needs_queuing(
            self: @GovernorComponentState<TContractState>, proposal_id: felt252
        ) -> bool {
            false
        }

        /// See `GovernorComponent::GovernorExecutionTrait::cancel_operations`.
        fn cancel_operations(
            ref self: GovernorComponentState<TContractState>,
            proposal_id: felt252,
            description_hash: felt252
        ) {
            self._cancel(proposal_id, description_hash);
        }
    }

    //
    // External
    //

    #[embeddable_as(VotesTokenImpl)]
    impl VotesToken<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of IVotesToken<ComponentState<TContractState>> {
        /// Returns the token that voting power is sourced from.
        fn token(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Governor_token.read()
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
        /// Initializes the component by setting the votes token.
        ///
        /// Requirements:
        ///
        /// - `votes_token` must not be zero.
        fn initialize(ref self: ComponentState<TContractState>, votes_token: ContractAddress) {
            assert(votes_token.is_non_zero(), Errors::INVALID_TOKEN);
            self.Governor_token.write(votes_token);
        }
    }
}
