// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.15.1 (governance/votes/votes.cairo)
use core::hash::{HashStateTrait, HashStateExTrait};
use core::poseidon::PoseidonTrait;
use openzeppelin_utils::cryptography::snip12::{OffchainMessageHash, StructHash, SNIP12Metadata};
use starknet::ContractAddress;


#[starknet::component]
pub mod VotesComponent {
    // We should not use Checkpoints or StorageArray as they are for ERC721Vote
    // Instead we can rely on Vec
    use core::num::traits::Zero;
    use openzeppelin_account::dual_account::{DualCaseAccount, DualCaseAccountTrait};
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_governance::votes::interface::{IVotes, IVotesToken};
    use openzeppelin_governance::votes::utils::{Delegation};
    use openzeppelin_token::erc721::ERC721Component;
    use openzeppelin_token::erc721::interface::IERC721;
    use openzeppelin_utils::nonces::NoncesComponent::InternalTrait as NoncesInternalTrait;
    use openzeppelin_utils::nonces::NoncesComponent;
    use openzeppelin_utils::structs::checkpoint::{Checkpoint, Trace, TraceTrait};
    use starknet::ContractAddress;
    use starknet::storage::Map;
    use super::{OffchainMessageHash, SNIP12Metadata};

    #[storage]
    struct Storage {
        Votes_delegatee: Map::<ContractAddress, ContractAddress>,
        Votes_delegate_checkpoints: Map::<ContractAddress, Trace>,
        Votes_total_checkpoints: Trace,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        DelegateChanged: DelegateChanged,
        DelegateVotesChanged: DelegateVotesChanged,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct DelegateChanged {
        #[key]
        pub delegator: ContractAddress,
        #[key]
        pub from_delegate: ContractAddress,
        #[key]
        pub to_delegate: ContractAddress
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct DelegateVotesChanged {
        #[key]
        pub delegate: ContractAddress,
        pub previous_votes: u256,
        pub new_votes: u256
    }

    pub mod Errors {
        pub const FUTURE_LOOKUP: felt252 = 'Votes: future Lookup';
        pub const EXPIRED_SIGNATURE: felt252 = 'Votes: expired signature';
        pub const INVALID_SIGNATURE: felt252 = 'Votes: invalid signature';
    }

    #[embeddable_as(VotesImpl)]
    impl Votes<
        TContractState,
        +HasComponent<TContractState>,
        impl Nonces: NoncesComponent::HasComponent<TContractState>,
        impl TokenTrait: IVotesToken<ComponentState<TContractState>>,
        +SNIP12Metadata,
        +Drop<TContractState>
    > of IVotes<ComponentState<TContractState>> {
        // Common implementation for both ERC20 and ERC721
        fn get_votes(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            self.Votes_delegate_checkpoints.read(account).latest()
        }

        fn get_past_votes(
            self: @ComponentState<TContractState>, account: ContractAddress, timepoint: u64
        ) -> u256 {
            let current_timepoint = starknet::get_block_timestamp();
            assert(timepoint < current_timepoint, Errors::FUTURE_LOOKUP);
            self.Votes_delegate_checkpoints.read(account).upper_lookup_recent(timepoint)
        }

        fn get_past_total_supply(self: @ComponentState<TContractState>, timepoint: u64) -> u256 {
            let current_timepoint = starknet::get_block_timestamp();
            assert(timepoint < current_timepoint, Errors::FUTURE_LOOKUP);
            self.Votes_total_checkpoints.read().upper_lookup_recent(timepoint)
        }

        fn delegates(
            self: @ComponentState<TContractState>, account: ContractAddress
        ) -> ContractAddress {
            self.Votes_delegatee.read(account)
        }

        fn delegate(ref self: ComponentState<TContractState>, delegatee: ContractAddress) {
            let sender = starknet::get_caller_address();
            self._delegate(sender, delegatee);
        }

        fn delegate_by_sig(
            ref self: ComponentState<TContractState>,
            delegator: ContractAddress,
            delegatee: ContractAddress,
            nonce: felt252,
            expiry: u64,
            signature: Array<felt252>
        ) {
            assert(starknet::get_block_timestamp() <= expiry, Errors::EXPIRED_SIGNATURE);

            // Check and increase nonce.
            let mut nonces_component = get_dep_component_mut!(ref self, Nonces);
            nonces_component.use_checked_nonce(delegator, nonce);

            // Build hash for calling `is_valid_signature`.
            let delegation = Delegation { delegatee, nonce, expiry };
            let hash = delegation.get_message_hash(delegator);

            let is_valid_signature_felt = DualCaseAccount { contract_address: delegator }
                .is_valid_signature(hash, signature);

            // Check either 'VALID' or True for backwards compatibility.
            let is_valid_signature = is_valid_signature_felt == starknet::VALIDATED
                || is_valid_signature_felt == 1;

            assert(is_valid_signature, Errors::INVALID_SIGNATURE);

            // Delegate votes.
            self._delegate(delegator, delegatee);
        }
    }

    //
    // Internal for ERC721Votes
    //

    // Should we also use a trait bound to make sure that the Votes trait is implemented?
    impl ERC721Votes<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        +Drop<TContractState>
    > of IVotesToken<ComponentState<TContractState>> {
        // ERC721-specific implementation
        fn get_voting_units(
            self: @ComponentState<TContractState>, account: ContractAddress
        ) -> u256 {
            let mut erc721_component = get_dep_component!(self, ERC721);
            erc721_component.balance_of(account).into()
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl TokenTrait: IVotesToken<ComponentState<TContractState>>,
        +NoncesComponent::HasComponent<TContractState>,
        +SNIP12Metadata,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        // Common internal functions
        fn _delegate(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            delegatee: ContractAddress
        ) {
            let from_delegate = self.delegates(account);
            self.Votes_delegatee.write(account, delegatee);
            self
                .emit(
                    DelegateChanged { delegator: account, from_delegate, to_delegate: delegatee }
                );
            self
                .move_delegate_votes(
                    from_delegate, delegatee, TokenTrait::get_voting_units(@self, account)
                );
        }

        fn move_delegate_votes(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) {
            let zero_address = Zero::zero();
            let block_timestamp = starknet::get_block_timestamp();
            if (from != to && amount > 0) {
                if (from != zero_address) {
                    let mut trace = self.Votes_delegate_checkpoints.read(from);
                    let (previous_votes, new_votes) = trace
                        .push(block_timestamp, trace.latest() - amount);
                    self.emit(DelegateVotesChanged { delegate: from, previous_votes, new_votes });
                }
                if (to != zero_address) {
                    let mut trace = self.Votes_delegate_checkpoints.read(to);
                    let (previous_votes, new_votes) = trace
                        .push(block_timestamp, trace.latest() + amount);
                    self.emit(DelegateVotesChanged { delegate: to, previous_votes, new_votes });
                }
            }
        }

        fn transfer_voting_units(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) {
            let zero_address = Zero::zero();
            let block_timestamp = starknet::get_block_timestamp();
            if (from == zero_address) {
                let mut trace = self.Votes_total_checkpoints.read();
                trace.push(block_timestamp, trace.latest() + amount);
            }
            if (to == zero_address) {
                let mut trace = self.Votes_total_checkpoints.read();
                trace.push(block_timestamp, trace.latest() - amount);
            }
            self.move_delegate_votes(self.delegates(from), self.delegates(to), amount);
        }
    }
}
