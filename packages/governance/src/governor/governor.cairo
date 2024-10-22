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
    use crate::governor::interface::{ProposalState, IGovernor, IGOVERNOR_ID};
    use openzeppelin_introspection::src5::SRC5Component::InternalImpl as SRC5InternalImpl;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc1155::interface::IERC1155_RECEIVER_ID;
    use openzeppelin_token::erc721::interface::IERC721_RECEIVER_ID;
    use openzeppelin_utils::bytearray::ByteArrayExtTrait;
    use openzeppelin_utils::structs::{DoubleEndedQueue, DoubleEndedQueueTrait};
    use starknet::ContractAddress;
    use starknet::account::Call;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use openzeppelin_utils::cryptography::snip12::SNIP12Metadata;

    #[storage]
    pub struct Storage {
        proposals: Map<felt252, ProposalCore>,
        governance_call: DoubleEndedQueue
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ProposalCreated: ProposalCreated,
        ProposalQueued: ProposalQueued,
        ProposalExecuted: ProposalExecuted,
        ProposalCanceled: ProposalCanceled
    }

    // TODO: Maybe add indexed keys and rename members since we don't have the GovernorBravo BC
    // restriction.
    /// Emitted when `call` is scheduled as part of operation `id`.
    #[derive(Drop, starknet::Event)]
    pub struct ProposalCreated {
        pub proposal_id: felt252,
        pub proposer: ContractAddress,
        pub calls: Span<Call>,
        pub signatures: Span<Span<felt252>>,
        pub vote_start: u64,
        pub vote_end: u64,
        pub description: ByteArray
    }

    // TODO: Maybe add indexed keys and rename members since we don't have the GovernorBravo BC
    // restriction.
    /// Emitted when a proposal is queued.
    #[derive(Drop, starknet::Event)]
    pub struct ProposalQueued {
        pub proposal_id: felt252,
        pub eta_seconds: u64
    }

    // TODO: Maybe add indexed keys and rename members since we don't have the GovernorBravo BC
    // restriction.
    /// Emitted when a proposal is executed.
    #[derive(Drop, starknet::Event)]
    pub struct ProposalExecuted {
        pub proposal_id: felt252
    }

    // TODO: Maybe add indexed keys and rename members since we don't have the GovernorBravo BC
    // restriction.
    /// Emitted when a proposal is canceled.
    #[derive(Drop, starknet::Event)]
    pub struct ProposalCanceled {
        pub proposal_id: felt252
    }

    // TODO: check prefix for errors
    mod Errors {
        pub const EXECUTOR_ONLY: felt252 = 'Gov: executor only';
        pub const PROPOSER_ONLY: felt252 = 'Gov: proposer only';
        pub const NONEXISTENT_PROPOSAL: felt252 = 'Gov: nonexistent proposal';
        pub const EXISTENT_PROPOSAL: felt252 = 'Gov: existent proposal';
        pub const RESTRICTED_PROPOSER: felt252 = 'Gov: restricted proposer';
        pub const INSUFFICIENT_PROPOSER_VOTES: felt252 = 'Gov: insufficient votes';
        pub const UNEXPECTED_PROPOSAL_STATE: felt252 = 'Gov: unexpected proposal state';
        pub const QUEUE_NOT_IMPLEMENTED: felt252 = 'Gov: queue not implemented';
    }

    //
    // Extensions traits
    //

    pub trait GovernorCountingTrait<TContractState> {
        fn counting_mode(self: @ComponentState<TContractState>) -> ByteArray;
        fn count_vote(
            ref self: ComponentState<TContractState>,
            proposal_id: felt252,
            account: ContractAddress,
            support: u8,
            total_weight: u256,
            params: Span<felt252>
        ) -> u256;
        fn has_voted(
            self: @ComponentState<TContractState>, proposal_id: felt252, account: ContractAddress
        ) -> bool;
        fn quorum_reached(self: @ComponentState<TContractState>, proposal_id: felt252) -> bool;
        fn vote_succeeded(self: @ComponentState<TContractState>, proposal_id: felt252) -> bool;
    }

    pub trait GovernorVotesTrait<TContractState> {
        fn clock(self: @ComponentState<TContractState>) -> u64;
        fn CLOCK_MODE(self: @ComponentState<TContractState>) -> ByteArray;
        fn voting_delay(self: @ComponentState<TContractState>) -> u64;
        fn voting_period(self: @ComponentState<TContractState>) -> u64;
        fn get_votes(
            self: @ComponentState<TContractState>,
            account: ContractAddress,
            timepoint: u64,
            params: Span<felt252>
        ) -> u256;
    }

    pub trait GovernorExecuteTrait<TContractState> {
        /// Address through which the governor executes action.
        /// Should be used to specify whether the module execute actions through another contract
        /// such as a timelock.
        fn executor(self: @ComponentState<TContractState>) -> ContractAddress;

        /// Execution mechanism. Can be used to modify the way execution is
        /// performed (for example adding a vault/timelock).
        fn execute_operations(
            ref self: ComponentState<TContractState>,
            proposal_id: felt252,
            calls: Span<Call>,
            description_hash: felt252
        );
    }

    pub trait GovernorQueueTrait<TContractState> {
        /// Queuing mechanism. Can be used to modify the way queuing is
        /// performed (for example adding a vault/timelock).
        ///
        /// Requirements:
        ///
        /// - Must return a timestamp that describes the expected ETA for execution. If the returned
        /// value is 0, the core will consider queueing did not succeed, and the public `queue`
        /// function will revert.
        fn queue_operations(
            ref self: ComponentState<TContractState>,
            proposal_id: felt252,
            calls: Span<Call>,
            description_hash: felt252
        ) -> u64;

        /// Whether a proposal needs to be queued before execution.
        ///
        /// Requirements:
        ///
        /// - Must return true if the proposal needs to be queued before execution.
        fn proposal_needs_queuing(
            self: @ComponentState<TContractState>, proposal_id: felt252
        ) -> bool;
    }

    //
    // External
    //

    #[embeddable_as(GovernorImpl)]
    impl Governor<
        TContractState, +HasComponent<TContractState>,
        +GovernorCountingTrait<TContractState>,
        impl Metadata: SNIP12Metadata,
        +Drop<TContractState>,
    > of IGovernor<ComponentState<TContractState>> {
        /// Name of the governor instance (used in building the SNIP-12 domain separator).
        fn name(self: @ComponentState<TContractState>) -> felt252 {
            Metadata::name()
        }

        /// Version of the governor instance (used in building SNIP-12 domain separator).
        fn version(self: @ComponentState<TContractState>) -> felt252 {
            Metadata::version()
        }

        /// A description of the possible `support` values for `cast_vote` and the way these votes are
        /// counted, meant to be consumed by UIs to show correct vote options and interpret the results.
        /// The string is a URL-encoded sequence of key-value pairs that each describe one aspect, for
        /// example `support=bravo&quorum=for,abstain`.
        ///
        /// There are 2 standard keys: `support` and `quorum`.
        ///
        /// - `support=bravo` refers to the vote options 0 = Against, 1 = For, 2 = Abstain, as in
        /// `GovernorBravo`.
        /// - `quorum=bravo` means that only For votes are counted towards quorum.
        /// - `quorum=for,abstain` means that both For and Abstain votes are counted towards quorum.
        ///
        /// If a counting module makes use of encoded `params`, it should  include this under a `params`
        /// key with a unique name that describes the behavior. For example:
        ///
        /// - `params=fractional` might refer to a scheme where votes are divided fractionally between
        /// for/against/abstain.
        /// - `params=erc721` might refer to a scheme where specific NFTs are delegated to vote.
        ///
        /// NOTE: The string can be decoded by the standard
        /// https://developer.mozilla.org/en-US/docs/Web/API/URLSearchParams[`URLSearchParams`]
        /// JavaScript class.
        fn COUNTING_MODE(self: @ComponentState<TContractState>) -> ByteArray {
            self.counting_mode()
        }

        /// Hashing function used to (re)build the proposal id from the proposal details.
        fn hash_proposal(
            self: @ComponentState<TContractState>, calls: Span<Call>, description_hash: felt252
        ) -> felt252 {
            self._hash_proposal(calls, description_hash)
        }

        fn state(self: @ComponentState<TContractState>, proposal_id: felt252) -> ProposalState {
            ProposalState::Pending
        }

        fn proposal_threshold(self: @ComponentState<TContractState>, proposal_id: felt252) -> u256 {
            1
        }

        fn proposal_snapshot(self: @ComponentState<TContractState>, proposal_id: felt252) -> u64 {
            1
        }

        fn proposal_deadline(self: @ComponentState<TContractState>, proposal_id: felt252) -> u64 {
            1
        }

        fn proposal_proposer(
            self: @ComponentState<TContractState>, proposal_id: felt252
        ) -> ContractAddress {
            Default::default()
        }

        fn proposal_eta(self: @ComponentState<TContractState>, proposal_id: felt252) -> u64 {
            1
        }

        fn proposal_needs_queuing(
            self: @ComponentState<TContractState>, proposal_id: felt252
        ) -> bool {
            false
        }

        fn voting_delay(self: @ComponentState<TContractState>) -> u64 {
            1
        }

        fn voting_period(self: @ComponentState<TContractState>) -> u64 {
            1
        }

        fn quorum(self: @ComponentState<TContractState>, timepoint: u64) -> u256 {
            1
        }

        fn get_votes(
            self: @ComponentState<TContractState>, account: ContractAddress, timepoint: u64
        ) -> u256 {
            1
        }

        fn get_votes_with_params(
            self: @ComponentState<TContractState>,
            account: ContractAddress,
            timepoint: u64,
            params: Span<felt252>
        ) -> u256 {
            1
        }

        fn has_voted(
            self: @ComponentState<TContractState>, proposal_id: felt252, account: ContractAddress
        ) -> bool {
            false
        }

        fn propose(
            ref self: ComponentState<TContractState>, calls: Span<Call>, description: ByteArray
        ) -> felt252 {
            1
        }

        fn queue(
            ref self: ComponentState<TContractState>, calls: Span<Call>, description_hash: felt252
        ) -> felt252 {
            1
        }

        fn execute(
            ref self: ComponentState<TContractState>, calls: Span<Call>, description_hash: felt252
        ) -> felt252 {
            1
        }

        fn cancel(
            ref self: ComponentState<TContractState>, calls: Span<Call>, description_hash: felt252
        ) -> felt252 {
            1
        }

        fn cast_vote(
            ref self: ComponentState<TContractState>, proposal_id: felt252, support: u8
        ) -> u256 {
            1
        }

        fn cast_vote_with_reason(
            ref self: ComponentState<TContractState>,
            proposal_id: felt252,
            support: u8,
            reason: ByteArray
        ) -> u256 {
            1
        }

        fn cast_vote_with_reason_and_params(
            ref self: ComponentState<TContractState>,
            proposal_id: felt252,
            support: u8,
            reason: ByteArray,
            params: Span<felt252>
        ) -> u256 {
            1
        }

        fn cast_vote_by_sig(
            ref self: ComponentState<TContractState>,
            proposal_id: felt252,
            support: u8,
            voter: ContractAddress,
            signature: Span<felt252>
        ) -> u256 {
            1
        }

        fn cast_vote_with_reason_and_params_by_sig(
            ref self: ComponentState<TContractState>,
            proposal_id: felt252,
            support: u8,
            voter: ContractAddress,
            reason: ByteArray,
            params: Span<felt252>,
            signature: Span<felt252>
        ) -> u256 {
            1
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +GovernorCountingTrait<TContractState>,
        +GovernorExecuteTrait<TContractState>,
        +GovernorVotesTrait<TContractState>,
        +GovernorQueueTrait<TContractState>,
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

        /// Returns a hash of the proposal using the Poseidon algorithm.
        /// TODO: check if we should be using Pedersen hash instead of Poseidon.
        fn _hash_proposal(
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
        fn proposal_threshold(self: @ComponentState<TContractState>) -> u256 {
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

        /// Creates a new proposal. Vote start after a delay specified by `voting_delay` and
        /// lasts for a duration specified by `voting_period`. Returns the id of the proposal.
        ///
        /// This function has opt-in frontrunning protection, described in
        /// `is_valid_description_for_proposer`.
        ///
        /// NOTE: The state of the Governor and `targets` may change between the proposal creation
        /// and its execution. This may be the result of third party actions on the targeted
        /// contracts, or other governor proposals. For example, the balance of this contract could
        /// be updated or its access control permissions may be modified, possibly compromising the
        /// proposal's ability to execute successfully (e.g. the governor doesn't have enough value
        /// to cover a proposal with multiple transfers).
        ///
        /// Requirements:
        ///
        /// - The proposer must be authorized to submit the proposal.
        /// - The proposer must have enough votes to submit the proposal if `proposal_threshold` is
        /// greater than zero.
        /// - The proposal must not already exist.
        ///
        /// Emits a `ProposalCreated` event.
        fn propose(
            ref self: ComponentState<TContractState>, calls: Span<Call>, description: ByteArray
        ) -> felt252 {
            let proposer = starknet::get_caller_address();

            // Check descrption for restricted proposer
            assert(
                self.is_valid_description_for_proposer(proposer, @description),
                Errors::RESTRICTED_PROPOSER
            );

            // Check proposal threshold
            let vote_threshold = self.proposal_threshold();
            if vote_threshold > 0 {
                let votes = self.get_votes(proposer, self.clock() - 1, array![].span());
                assert(votes >= vote_threshold, Errors::INSUFFICIENT_PROPOSER_VOTES);
            }

            self._propose(calls, @description, proposer)
        }

        /// Internal propose mechanism. Returns the proposal id.
        ///
        /// Requirements:
        ///
        /// - The proposal must not already exist.
        ///
        /// Emits a `ProposalCreated` event.
        fn _propose(
            ref self: ComponentState<TContractState>,
            calls: Span<Call>,
            description: @ByteArray,
            proposer: ContractAddress
        ) -> felt252 {
            let proposal_id = self.hash_proposal(calls, description.hash());

            assert(self.proposals.read(proposal_id).vote_start == 0, Errors::EXISTENT_PROPOSAL);

            let snapshot = self.clock() + self.voting_delay();
            let duration = self.voting_period();

            let proposal = ProposalCore {
                proposer,
                vote_start: snapshot,
                vote_duration: duration,
                executed: false,
                canceled: false,
                eta_seconds: 0
            };

            self.proposals.write(proposal_id, proposal);

            self
                .emit(
                    ProposalCreated {
                        proposal_id,
                        proposer,
                        calls,
                        signatures: array![].span(),
                        vote_start: snapshot,
                        vote_end: snapshot + duration,
                        description: description.clone()
                    }
                );

            proposal_id
        }

        /// Queues a proposal. Some governors require this step to be performed before execution can
        /// happen. If queuing is not necessary, this function may revert.
        /// Queuing a proposal requires the quorum to be reached, the vote to be successful, and the
        /// deadline to be reached.
        ///
        /// Returns the id of the proposal.
        ///
        /// Requirements:
        ///
        /// - The proposal must be in the `Succeeded` state.
        /// - The queue operation must return a non-zero ETA.
        ///
        /// Emits a `ProposalQueued` event.
        fn queue(
            ref self: ComponentState<TContractState>, calls: Span<Call>, description_hash: felt252
        ) -> felt252 {
            let proposal_id = self.hash_proposal(calls, description_hash);
            self.validate_state(proposal_id, array![ProposalState::Succeeded].span());

            let eta_seconds = self.queue_operations(proposal_id, calls, description_hash);
            assert(eta_seconds > 0, Errors::QUEUE_NOT_IMPLEMENTED);

            let mut proposal = self.proposals.read(proposal_id);
            proposal.eta_seconds = eta_seconds;
            self.proposals.write(proposal_id, proposal);

            self.emit(ProposalQueued { proposal_id, eta_seconds });

            proposal_id
        }

        /// Executes a successful proposal. This requires the quorum to be reached, the vote to be
        /// successful, and the deadline to be reached. Depending on the governor it might also be
        /// required that the proposal was queued and that some delay passed.
        ///
        /// NOTE: Some modules can modify the requirements for execution, for example by adding an
        /// additional timelock (See `timelock_controller`).
        ///
        /// Returns the id of the proposal.
        ///
        /// Requirements:
        ///
        /// - The proposal must be in the `Succeeded` or `Queued` state.
        ///
        /// Emits a `ProposalExecuted` event.
        fn execute(
            ref self: ComponentState<TContractState>, calls: Span<Call>, description_hash: felt252
        ) -> felt252 {
            let proposal_id = self.hash_proposal(calls, description_hash);
            self
                .validate_state(
                    proposal_id, array![ProposalState::Succeeded, ProposalState::Queued].span()
                );

            // Mark proposal as executed to avoid reentrancy
            let mut proposal = self.proposals.read(proposal_id);
            proposal.executed = true;
            self.proposals.write(proposal_id, proposal);

            let self_executor = self.executor() == starknet::get_contract_address();
            // Register governance call in queue before execution
            if self_executor { // TODO: Save the calldatas in the governance_call queue
            }

            self.execute_operations(proposal_id, calls, description_hash);

            // Clean up the governance call queue
            if self_executor
                && (@self).governance_call.deref().len() > 0 { // TODO: Clean up the queue
            }

            self.emit(ProposalExecuted { proposal_id });

            proposal_id
        }

        /// Cancels a proposal. A proposal is cancellable by the proposer, but only while it is
        /// Pending state, i.e. before the vote starts.
        ///
        /// Returns the id of the proposal.
        ///
        /// Requirements:
        ///
        /// - The proposal must be in the `Pending` state.
        ///
        /// Emits a `ProposalCanceled` event.
        fn cancel(
            ref self: ComponentState<TContractState>, calls: Span<Call>, description_hash: felt252
        ) -> felt252 {
            let proposal_id = self.hash_proposal(calls, description_hash);
            self.validate_state(proposal_id, array![ProposalState::Pending].span());

            assert(
                starknet::get_caller_address() == self.proposal_proposer(proposal_id),
                Errors::PROPOSER_ONLY
            );

            self._cancel(proposal_id, calls, description_hash)
        }

        /// Internal cancel mechanism with minimal restrictions. Returns the id of the proposal.
        ///
        /// Requirements:
        ///
        /// - A proposal can be cancelled in any state other than
        /// Canceled, Expired, or Executed. Once cancelled a proposal can't be re-submitted.
        ///
        /// Emits a `ProposalCanceled` event.
        fn _cancel(
            ref self: ComponentState<TContractState>,
            proposal_id: felt252,
            calls: Span<Call>,
            description_hash: felt252
        ) -> felt252 {
            let valid_states = array![
                ProposalState::Pending,
                ProposalState::Active,
                ProposalState::Defeated,
                ProposalState::Succeeded,
                ProposalState::Queued
            ];
            self.validate_state(proposal_id, valid_states.span());

            let mut proposal = self.proposals.read(proposal_id);
            proposal.canceled = true;
            self.proposals.write(proposal_id, proposal);

            self.emit(ProposalCanceled { proposal_id });

            proposal_id
        }

        /// Cast a vote.
        fn cast_vote(
            ref self: ComponentState<TContractState>, proposal_id: felt252, support: u8
        ) -> u256 {
            1
        }

        /// Cast a vote with a reason.
        fn cast_vote_with_reason(
            ref self: ComponentState<TContractState>,
            proposal_id: felt252,
            support: u8,
            reason: ByteArray
        ) -> u256 {
            1
        }

        /// Cast a vote with a reason and additional serialized parameters.
        fn cast_vote_with_reason_and_params(
            ref self: ComponentState<TContractState>,
            proposal_id: felt252,
            support: u8,
            reason: ByteArray,
            params: Span<felt252>
        ) -> u256 {
            1
        }

        fn _cast_vote(
            ref self: ComponentState<TContractState>,
            proposal_id: felt252,
            account: ContractAddress,
            support: u8,
            reason: ByteArray,
        ) -> u256 {
            1
        }

        fn _cast_vote_with_params(
            ref self: ComponentState<TContractState>,
            proposal_id: felt252,
            account: ContractAddress,
            support: u8,
            reason: ByteArray,
            params: Span<felt252>
        ) -> u256 {
            self.validate_state(proposal_id, array![ProposalState::Active].span());

            // let total_weight = self.get_votes(account, self.clock() - 1);

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
            self: @ComponentState<TContractState>,
            proposer: ContractAddress,
            description: @ByteArray
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
            proposer.to_byte_array(16, 64) == expected_address
        }

        /// Validates that the proposal is in one of the expected states.
        fn validate_state(
            self: @ComponentState<TContractState>,
            proposal_id: felt252,
            allowed_states: Span<ProposalState>
        ) {
            let current_state = self.state(proposal_id);
            let mut found = false;
            for state in allowed_states {
                if current_state == *state {
                    found = true;
                    break;
                }
            };
            assert(found, Errors::UNEXPECTED_PROPOSAL_STATE);
        }
    }
}
