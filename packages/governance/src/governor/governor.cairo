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
    use openzeppelin_utils::bytearray::ByteArrayExtTrait;
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
        fn has_voted(
            self: @ComponentState<TContractState>, proposal_id: felt252, account: ContractAddress
        ) -> bool;
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
        /// TODO: check if we should be using Pedersen hash instead of Poseidon.
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

        /// The number of votes required in order for a voter to become a proposer.
        fn proposal_threshold(self: @ComponentState<TContractState>, proposal_id: felt252) -> u256 {
            0
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

        /// The account that created a proposal.
        fn proposal_proposer(
            self: @ComponentState<TContractState>, proposal_id: felt252
        ) -> ContractAddress {
            self.proposals.read(proposal_id).proposer
        }

        /// The time when a queued proposal becomes executable ("ETA"). Unlike `proposal_snapshot`
        /// and `proposal_deadline`, this doesn't use the governor clock, and instead relies on the
        /// executor's clock which may be different. In most cases this will be a timestamp.
        fn proposal_eta(self: @ComponentState<TContractState>, proposal_id: felt252) -> u64 {
            self.proposals.read(proposal_id).eta_seconds
        }

        /// Whether a proposal needs to be queued before execution.
        fn proposal_needs_queuing(
            self: @ComponentState<TContractState>, proposal_id: felt252
        ) -> bool {
            false
        }

        /// Creates a new proposal. Vote start after a delay specified by `voting_delay` and
        /// lasts for a duration specified by `voting_period`.
        ///
        /// NOTE: The state of the Governor and `targets` may change between the proposal creation
        /// and its execution. This may be the result of third party actions on the targeted
        /// contracts, or other governor proposals. For example, the balance of this contract could
        /// be updated or its access control permissions may be modified, possibly compromising the
        /// proposal's ability to execute successfully (e.g. the governor doesn't have enough value
        /// to cover a proposal with multiple transfers).
        ///
        /// Returns the id of the proposal.
        fn propose(
            ref self: ComponentState<TContractState>, calls: Span<Call>, description: ByteArray
        ) -> felt252 {
            let proposer = starknet::get_caller_address();
            1
        }

        /// Checks if the proposer is authorized to submit a proposal with the given description.
        ///
        /// If the proposal description ends with `#proposer=0x???`, where `0x???` is an address
        /// written as a hex string (case insensitive), then the submission of this proposal will
        /// only be authorized to said address.
        ///
        /// This is used for frontrunning protection. By adding this pattern at the end of their
        /// proposal, one can ensure that no other address can submit the same proposal. An attacker
        /// would have to either remove or change that part, which would result in a different
        /// proposal id.
        ///
        /// If the description does not match this pattern, it is unrestricted and anyone can submit
        /// it. This includes:
        /// - If the `0x???` part is not a valid hex string.
        /// - If the `0x???` part is a valid hex string, but does not contain exactly 40 hex digits.
        /// - If it ends with the expected suffix followed by newlines or other whitespace.
        /// - If it ends with some other similar suffix, e.g. `#other=abc`.
        /// - If it does not end with any such suffix.
        fn is_valid_description_for_proposer(
            self: @ComponentState<TContractState>, proposer: ContractAddress, description: ByteArray
        ) -> bool {
            let length = description.len();

            // Length is too short to contain a valid proposer suffix
            if description.len() < 52 {
                return true;
            }

            // Extract what would be the `#proposer=` marker beginning the suffix
            let marker = description.read_n_bytes(length - 52, 10);

            // If the marker is not found, there is no proposer suffix to check
            if marker != "#proposer=" {
                return true;
            }

            let expected_address = description.read_n_bytes(length - 42, 42);
            let proposer: felt252 = proposer.into();
            proposer.to_byte_array(16, 64) == expected_address
        }
    }
}
