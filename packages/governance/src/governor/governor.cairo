// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.17.0 (governance/governor/governor.cairo)

/// # Governor Component
///
/// Core of the governance system.
#[starknet::component]
pub mod GovernorComponent {
    use core::hash::{HashStateTrait, HashStateExTrait};
    use core::num::traits::Zero;
    use core::poseidon::{PoseidonTrait, poseidon_hash_span};
    use crate::governor::ProposalCore;
    use crate::governor::interface::{ProposalState, IGOVERNOR_ID};
    use openzeppelin_introspection::src5::SRC5Component::InternalImpl as SRC5InternalImpl;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc1155::interface::IERC1155_RECEIVER_ID;
    use openzeppelin_token::erc721::interface::IERC721_RECEIVER_ID;
    use openzeppelin_utils::structs::DoubleEndedQueue;
    use starknet::ContractAddress;
    use starknet::account::Call;
    use starknet::storage::{Map, StorageMapReadAccess};

    #[storage]
    pub struct Storage {
        proposals: Map<felt252, ProposalCore>,
        governance_call: DoubleEndedQueue
    }

    mod Errors {
        pub const EXECUTOR_ONLY: felt252 = 'Governor: executor only';
        pub const NONEXISTENT_PROPOSAL: felt252 = 'Governor: nonexistent proposal';
    }

    //
    // Extensions
    //

    pub trait GovernorCountingTrait<TContractState> {
        fn COUNTING_MODE(self: @ComponentState<TContractState>) -> ByteArray;
        fn has_voted(self: @ComponentState<TContractState>, proposal_id: felt252, account: ContractAddress) -> bool;
        fn quorum_reached(self: @ComponentState<TContractState>, proposal_id: felt252) -> bool;
        fn vote_succeeded(self: @ComponentState<TContractState>, proposal_id: felt252) -> bool;
        fn count_vote(
            ref self: ComponentState<TContractState>,
            proposal_id: felt252,
            account: ContractAddress,
            support: u8,
            total_weight: u256,
            params: Span<felt252>
        ) -> u256;
    }

    pub trait GovernorExecutorTrait<TContractState> {
        fn executor(self: @ComponentState<TContractState>) -> ContractAddress;
    }

    pub trait GovernorVotesTrait<TContractState> {
        fn clock(self: @ComponentState<TContractState>) -> u64;
        fn CLOCK_MODE(self: @ComponentState<TContractState>) -> ByteArray;
        fn get_votes(
            self: @ComponentState<TContractState>,
            account: ContractAddress,
            timepoint: u64,
            params: Span<felt252>
        ) -> u256;
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +GovernorCountingTrait<TContractState>,
        +GovernorExecutorTrait<TContractState>,
        +GovernorVotesTrait<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Initializes the contract by registering the supported interface Ids.
        fn initializer(ref self: ComponentState<TContractState>) {
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IGOVERNOR_ID);
            src5_component.register_interface(IERC721_RECEIVER_ID);
            src5_component.register_interface(IERC1155_RECEIVER_ID);
        }

        fn assert_only_governance(ref self: ComponentState<TContractState>) {
            let executor = self.executor();
            assert(executor == starknet::get_caller_address(), Errors::EXECUTOR_ONLY);

            // TODO: either check that the calldata matches the whitelist or assume the Executor
            // can't execute proposals not created from the Governor itself.
            ()
        }

        /// Hashing function used to (re)build the proposal id from the proposal details.
        fn hash_proposal(
            ref self: ComponentState<TContractState>, calls: Span<Call>, description_hash: felt252
        ) -> felt252 {
            let mut hashed_calls = array![];

            for call in calls {
                let hash_state = PoseidonTrait::new();
                let hash = hash_state
                    .update_with(*call.to)
                    .update_with(*call.selector)
                    .update_with(poseidon_hash_span(*call.calldata))
                    .finalize();

                hashed_calls.append(hash);
            };
            hashed_calls.append(description_hash);

            poseidon_hash_span(hashed_calls.span())
        }

        /// Returns the state of a proposal, given its id.
        fn state(self: @ComponentState<TContractState>, proposal_id: felt252) -> ProposalState {
            let proposal = self.proposals.read(proposal_id);

            if proposal.executed {
                return ProposalState::Executed;
            }

            if proposal.canceled {
                return ProposalState::Canceled;
            }

            let snapshot = self.proposal_snapshot(proposal_id);

            assert(snapshot.is_non_zero(), Errors::NONEXISTENT_PROPOSAL);

            let current_timepoint = self.clock();

            if current_timepoint < snapshot {
                return ProposalState::Pending;
            }

            let deadline = self.proposal_deadline(proposal_id);

            if current_timepoint < deadline {
                return ProposalState::Active;
            } else if !self.quorum_reached(proposal_id) || !self.vote_succeeded(proposal_id) {
                return ProposalState::Defeated;
            } else if self.proposal_eta(proposal_id).is_zero() {
                return ProposalState::Succeeded;
            } else {
                return ProposalState::Queued;
            }
        }

        /// Timepoint used to retrieve user's votes and quorum. If using block number, the snapshot
        /// is performed at the end of this block. Hence, voting for this proposal starts at the
        /// beginning of the following block.
        fn proposal_snapshot(self: @ComponentState<TContractState>, proposal_id: felt252) -> u64 {
            self.proposals.read(proposal_id).vote_start
        }

        /// Timepoint at which votes close. If using block number, votes close at the end of this
        /// block, so it is possible to cast a vote during this block.
        fn proposal_deadline(self: @ComponentState<TContractState>, proposal_id: felt252) -> u64 {
            let proposal = self.proposals.read(proposal_id);
            proposal.vote_start + proposal.vote_duration
        }

        /// The time when a queued proposal becomes executable ("ETA"). Unlike `proposal_snapshot` and
        /// `proposal_deadline`, this doesn't use the governor clock, and instead relies on the
        /// executor's clock which may be different. In most cases this will be a timestamp.
        fn proposal_eta(self: @ComponentState<TContractState>, proposal_id: felt252) -> u64 {
            self.proposals.read(proposal_id).eta_seconds
        }
    }
}
