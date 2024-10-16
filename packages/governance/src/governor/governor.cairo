// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.17.0 (governance/governor/governor.cairo)

/// # Governor Component
///
/// Core of the governance system.
#[starknet::component]
pub mod GovernorComponent {
    use core::hash::{HashStateTrait, HashStateExTrait};
    use core::poseidon::{PoseidonTrait, poseidon_hash_span};
    use crate::governor::ProposalCore;
    use crate::governor::interface::IGOVERNOR_ID;
    use openzeppelin_introspection::src5::SRC5Component::InternalImpl as SRC5InternalImpl;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc1155::interface::IERC1155_RECEIVER_ID;
    use openzeppelin_token::erc721::interface::IERC721_RECEIVER_ID;
    use openzeppelin_utils::structs::DoubleEndedQueue;
    use starknet::ContractAddress;
    use starknet::account::Call;
    use starknet::storage::Map;

    #[storage]
    pub struct Storage {
        proposals: Map<felt252, ProposalCore>,
        governance_call: DoubleEndedQueue
    }

    mod Errors {
        pub const EXECUTOR_ONLY: felt252 = 'Governor: executor only';
    }

    //
    // Extensions
    //

    pub trait GovernorCountingTrait {
        fn COUNTING_MODE() -> ByteArray;
        fn has_voted(proposal_id: felt252, account: ContractAddress) -> bool;
        fn quorum_reached(proposal_id: felt252) -> bool;
        fn vote_succeeded(proposal_id: felt252) -> bool;
        fn count_vote(
            proposal_id: felt252,
            account: ContractAddress,
            support: u8,
            total_weight: u256,
            params: Span<felt252>
        ) -> u256;
    }

    pub trait GovernorVotesTrait {
        fn clock() -> u64;
        fn CLOCK_MODE() -> ByteArray;
        fn get_votes(account: ContractAddress, timepoint: u64, params: Span<felt252>) -> u256;
    }

    pub trait GovernorExecutorTrait<TContractState> {
        fn executor(self: @ComponentState<TContractState>) -> ContractAddress;
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +GovernorExecutorTrait<TContractState>,
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
    }
}
