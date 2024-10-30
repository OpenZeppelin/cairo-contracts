// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.18.0
// (governance/governor/extensions/governor_votes.cairo)

/// # GovernorVotes Component
///
/// Extension of GovernorComponent for voting weight extraction from a token with the Votes
/// extension.
#[starknet::component]
pub mod GovernorVotesComponent {
    use core::num::traits::Zero;
    use crate::governor::GovernorComponent::ComponentState as GovernorComponentState;
    use crate::governor::GovernorComponent;
    use crate::governor::extensions::interface::IVotesToken;
    use crate::votes::interface::{IVotesDispatcher, IVotesDispatcherTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
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

    impl GovernorVotes<
        TContractState,
        +GovernorComponent::HasComponent<TContractState>,
        +GovernorComponent::GovernorExecutionTrait<TContractState>,
        +GovernorComponent::GovernorCountingTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        impl GovernorVotesQuorumFraction: HasComponent<TContractState>,
        +Drop<TContractState>
    > of GovernorComponent::GovernorVotesTrait<TContractState> {
        /// See `GovernorComponent::GovernorVotesTrait::clock`.
        fn clock(self: @GovernorComponentState<TContractState>) -> u64 {
            // VotesComponent uses the block timestamp for tracking checkpoints.
            // That should be updated in order to allow for more flexible clock modes.
            starknet::get_block_timestamp()
        }

        /// See `GovernorComponent::GovernorVotesTrait::CLOCK_MODE`.
        fn clock_mode(self: @GovernorComponentState<TContractState>) -> ByteArray {
            "mode=timestamp&from=starknet::SN_MAIN"
        }

        /// See `GovernorComponent::GovernorVotesTrait::get_votes`.
        fn get_votes(
            self: @GovernorComponentState<TContractState>,
            account: ContractAddress,
            timepoint: u64,
            params: @ByteArray
        ) -> u256 {
            let contract = self.get_contract();
            let this_component = GovernorVotesQuorumFraction::get_component(contract);

            let token = this_component.Governor_token.read();
            let votes_dispatcher = IVotesDispatcher { contract_address: token };

            votes_dispatcher.get_past_votes(account, timepoint)
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
