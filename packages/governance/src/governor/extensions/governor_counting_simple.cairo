// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.18.0
// (governance/governor/extensions/governor_counting_simple.cairo)

/// # GovernorCountingSimple Component
///
/// Extension of GovernorComponent for simple, 3 options, vote counting.
#[starknet::component]
pub mod GovernorCountingSimpleComponent {
    use crate::governor::GovernorComponent::{
        InternalImpl, ComponentState as GovernorComponentState
    };
    use crate::governor::GovernorComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    type ProposalId = felt252;

    #[storage]
    pub struct Storage {
        Governor_proposals_votes: Map<ProposalId, ProposalVote>,
    }

    /// Supported vote types.
    enum VoteType {
        Against,
        For,
        Abstain,
    }

    impl U8TryIntoVoteType of TryInto<u8, VoteType> {
        fn try_into(self: u8) -> Option<VoteType> {
            match self {
                0 => Option::Some(VoteType::Against),
                1 => Option::Some(VoteType::For),
                2 => Option::Some(VoteType::Abstain),
                _ => Option::None,
            }
        }
    }

    #[starknet::storage_node]
    struct ProposalVote {
        against_votes: u256,
        for_votes: u256,
        abstain_votes: u256,
        has_voted: Map<ContractAddress, bool>
    }

    mod Errors {
        pub const ALREADY_CAST_VOTE: felt252 = 'Already cast vote';
        pub const INVALID_VOTE_TYPE: felt252 = 'Invalid vote type';
    }

    //
    // Extensions
    //

    impl GovernorCounting<
        TContractState,
        +GovernorComponent::ImmutableConfig,
        +GovernorComponent::HasComponent<TContractState>,
        +GovernorComponent::GovernorSettingsTrait<TContractState>,
        +GovernorComponent::GovernorQuorumTrait<TContractState>,
        +GovernorComponent::GovernorExecuteTrait<TContractState>,
        +GovernorComponent::GovernorQueueTrait<TContractState>,
        +GovernorComponent::GovernorVotesTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        impl GovernorCountingSimple: HasComponent<TContractState>,
        +Drop<TContractState>
    > of GovernorComponent::GovernorCountingTrait<TContractState> {
        /// See `GovernorComponent::GovernorCountingTrait::counting_mode`.
        fn counting_mode(self: @GovernorComponentState<TContractState>) -> ByteArray {
            return "support=bravo&quorum=for,abstain";
        }

        /// See `GovernorComponent::GovernorCountingTrait::count_vote`.
        ///
        /// In this module, the support follows the `VoteType` enum (from Governor Bravo).
        fn count_vote(
            ref self: GovernorComponentState<TContractState>,
            proposal_id: felt252,
            account: ContractAddress,
            support: u8,
            total_weight: u256,
            params: @ByteArray
        ) -> u256 {
            let mut contract = self.get_contract_mut();
            let mut this_component = GovernorCountingSimple::get_component_mut(ref contract);

            let proposal_votes = this_component.Governor_proposals_votes.entry(proposal_id);
            assert(!proposal_votes.has_voted.read(account), Errors::ALREADY_CAST_VOTE);

            proposal_votes.has_voted.write(account, true);

            let support: VoteType = support.try_into().expect(Errors::INVALID_VOTE_TYPE);
            match support {
                VoteType::Against => {
                    let current_votes = proposal_votes.against_votes.read();
                    proposal_votes.against_votes.write(current_votes + total_weight);
                },
                VoteType::For => {
                    let current_votes = proposal_votes.for_votes.read();
                    proposal_votes.for_votes.write(current_votes + total_weight);
                },
                VoteType::Abstain => {
                    let current_votes = proposal_votes.abstain_votes.read();
                    proposal_votes.abstain_votes.write(current_votes + total_weight);
                }
            }
            total_weight
        }

        /// See `GovernorComponent::GovernorCountingTrait::has_voted`.
        fn has_voted(
            self: @GovernorComponentState<TContractState>,
            proposal_id: felt252,
            account: ContractAddress
        ) -> bool {
            let contract = self.get_contract();
            let this_component = GovernorCountingSimple::get_component(contract);
            let proposal_votes = this_component.Governor_proposals_votes.entry(proposal_id);

            proposal_votes.has_voted.read(account)
        }

        /// See `GovernorComponent::GovernorCountingTrait::quorum_reached`.
        fn quorum_reached(
            self: @GovernorComponentState<TContractState>, proposal_id: felt252
        ) -> bool {
            let contract = self.get_contract();
            let this_component = GovernorCountingSimple::get_component(contract);

            let proposal_votes = this_component.Governor_proposals_votes.entry(proposal_id);
            let snapshot = self._proposal_snapshot(proposal_id);

            self.quorum(snapshot) <= proposal_votes.for_votes.read()
                + proposal_votes.abstain_votes.read()
        }

        /// See `GovernorComponent::GovernorCountingTrait::vote_succeeded`.
        ///
        /// In this module, the `for_votes` must be strictly over the `against_votes`.
        fn vote_succeeded(
            self: @GovernorComponentState<TContractState>, proposal_id: felt252
        ) -> bool {
            let contract = self.get_contract();
            let this_component = GovernorCountingSimple::get_component(contract);
            let proposal_votes = this_component.Governor_proposals_votes.entry(proposal_id);

            proposal_votes.for_votes.read() > proposal_votes.against_votes.read()
        }
    }
}
