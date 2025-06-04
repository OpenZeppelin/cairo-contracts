// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v2.0.0-alpha.1
// (governance/src/governor/extensions/governor_votes.cairo)

/// # GovernorVotes Component
///
/// Extension of GovernorComponent for voting weight extraction from a token with the Votes
/// extension.
#[starknet::component]
pub mod GovernorVotesComponent {
    use core::num::traits::Zero;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use crate::governor::GovernorComponent;
    use crate::governor::GovernorComponent::ComponentState as GovernorComponentState;
    use crate::governor::extensions::interface::IVotesToken;
    use crate::votes::interface::{IVotesDispatcher, IVotesDispatcherTrait};

    #[storage]
    pub struct Storage {
        pub Governor_token: ContractAddress,
    }

    pub mod Errors {
        pub const INVALID_TOKEN: felt252 = 'Invalid votes token';
    }

    //
    // Extensions
    //

    pub impl GovernorVotes<
        TContractState,
        +GovernorComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        impl GovernorVotes: HasComponent<TContractState>,
        +Drop<TContractState>,
    > of GovernorComponent::GovernorVotesTrait<TContractState> {
        /// See `GovernorComponent::GovernorVotesTrait::clock`.
        fn clock(self: @GovernorComponentState<TContractState>) -> u64 {
            let votes_dispatcher = IVotesDispatcher { contract_address: get_votes_token(self) };
            votes_dispatcher.clock()
        }

        /// See `GovernorComponent::GovernorVotesTrait::CLOCK_MODE`.
        fn CLOCK_MODE(self: @GovernorComponentState<TContractState>) -> ByteArray {
            let votes_dispatcher = IVotesDispatcher { contract_address: get_votes_token(self) };
            votes_dispatcher.CLOCK_MODE()
        }

        /// See `GovernorComponent::GovernorVotesTrait::get_votes`.
        fn get_votes(
            self: @GovernorComponentState<TContractState>,
            account: ContractAddress,
            timepoint: u64,
            params: Span<felt252>,
        ) -> u256 {
            let votes_dispatcher = IVotesDispatcher { contract_address: get_votes_token(self) };
            votes_dispatcher.get_past_votes(account, timepoint)
        }
    }

    fn get_votes_token<
        TContractState,
        +GovernorComponent::HasComponent<TContractState>,
        impl GovernorVotes: HasComponent<TContractState>,
    >(self: @GovernorComponentState<TContractState>) -> ContractAddress {
        let contract = self.get_contract();
        let this_component = GovernorVotes::get_component(contract);
        this_component.Governor_token.read()
    }

    //
    // External
    //

    #[embeddable_as(VotesTokenImpl)]
    impl VotesToken<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
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
        +GovernorComponent::HasComponent<TContractState>,
        +GovernorComponent::GovernorVotesTrait<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Initializes the component by setting the votes token.
        ///
        /// Requirements:
        ///
        /// - `votes_token` must not be zero.
        fn initializer(ref self: ComponentState<TContractState>, votes_token: ContractAddress) {
            assert(votes_token.is_non_zero(), Errors::INVALID_TOKEN);
            self.Governor_token.write(votes_token);
        }
    }
}
