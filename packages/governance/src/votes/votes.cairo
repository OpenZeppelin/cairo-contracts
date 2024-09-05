// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.15.1 (governance/votes/votes.cairo)

use openzeppelin_utils::cryptography::snip12::{OffchainMessageHash, SNIP12Metadata};

/// # Votes Component
///
/// The Votes component provides a flexible system for tracking voting power and delegation
/// that is currently implemented for ERC20 and ERC721 tokens. It allows accounts to delegate
/// their voting power to a representative, who can then use the pooled voting power in
/// governance decisions. Voting power must be delegated to be counted, and an account can
/// delegate to itself if it wishes to vote directly.
///
/// This component offers a unified interface for voting mechanisms across ERC20 and ERC721
/// token standards, with the potential to be extended to other token standards in the future.
/// It's important to note that only one token implementation (either ERC20 or ERC721) should
/// be used at a time to ensure consistent voting power calculations.
#[starknet::component]
pub mod VotesComponent {
    // We should not use Checkpoints or StorageArray as they are for ERC721Vote
    // Instead we can rely on Vec
    use core::num::traits::Zero;
    use openzeppelin_account::dual_account::{DualCaseAccount, DualCaseAccountTrait};
    use openzeppelin_governance::votes::interface::{IVotes, TokenVotesTrait};
    use openzeppelin_governance::votes::utils::Delegation;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc20::ERC20Component;
    use openzeppelin_token::erc20::interface::IERC20;
    use openzeppelin_token::erc721::ERC721Component;
    use openzeppelin_token::erc721::interface::IERC721;
    use openzeppelin_utils::nonces::NoncesComponent::InternalTrait as NoncesInternalTrait;
    use openzeppelin_utils::nonces::NoncesComponent;
    use openzeppelin_utils::structs::checkpoint::{Trace, TraceTrait};
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
        +TokenVotesTrait<ComponentState<TContractState>>,
        +SNIP12Metadata,
        +Drop<TContractState>
    > of IVotes<ComponentState<TContractState>> {
        /// Returns the current amount of votes that `account` has.
        fn get_votes(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            self.Votes_delegate_checkpoints.read(account).latest()
        }

        /// Returns the amount of votes that `account` had at a specific moment in the past.
        ///
        /// Requirements:
        ///
        /// - `timepoint` must be in the past.
        fn get_past_votes(
            self: @ComponentState<TContractState>, account: ContractAddress, timepoint: u64
        ) -> u256 {
            let current_timepoint = starknet::get_block_timestamp();
            assert(timepoint < current_timepoint, Errors::FUTURE_LOOKUP);
            self.Votes_delegate_checkpoints.read(account).upper_lookup_recent(timepoint)
        }

        /// Returns the total supply of votes available at a specific moment in the past.
        ///
        /// Requirements:
        ///
        /// - `timepoint` must be in the past.
        fn get_past_total_supply(self: @ComponentState<TContractState>, timepoint: u64) -> u256 {
            let current_timepoint = starknet::get_block_timestamp();
            assert(timepoint < current_timepoint, Errors::FUTURE_LOOKUP);
            self.Votes_total_checkpoints.read().upper_lookup_recent(timepoint)
        }

        /// Returns the delegate that `account` has chosen.
        fn delegates(
            self: @ComponentState<TContractState>, account: ContractAddress
        ) -> ContractAddress {
            self.Votes_delegatee.read(account)
        }

        /// Delegates votes from the sender to `delegatee`.
        ///
        /// Emits a `DelegateChanged` event.
        /// May emit one or two `DelegateVotesChanged` events.
        fn delegate(ref self: ComponentState<TContractState>, delegatee: ContractAddress) {
            let sender = starknet::get_caller_address();
            self._delegate(sender, delegatee);
        }

        /// Delegates votes from the sender to `delegatee` through a SNIP12 message signature
        /// validation.
        ///
        /// Requirements:
        ///
        /// - `expiry` must not be in the past.
        /// - `nonce` must match the account's current nonce.
        /// - `delegator` must implement `SRC6::is_valid_signature`.
        /// - `signature` should be valid for the message hash.
        ///
        /// Emits a `DelegateChanged` event.
        /// May emit one or two `DelegateVotesChanged` events.
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
    // Internal
    //

    impl ERC721VotesImpl<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        +Drop<TContractState>
    > of TokenVotesTrait<ComponentState<TContractState>> {
        /// Returns the number of voting units for a given account.
        ///
        /// This implementation is specific to ERC721 tokens, where each token
        /// represents one voting unit. The function returns the balance of
        /// ERC721 tokens for the specified account.
        fn get_voting_units(
            self: @ComponentState<TContractState>, account: ContractAddress
        ) -> u256 {
            let mut erc721_component = get_dep_component!(self, ERC721);
            erc721_component.balance_of(account).into()
        }
    }

    impl ERC20VotesImpl<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        +Drop<TContractState>
    > of TokenVotesTrait<ComponentState<TContractState>> {
        /// Returns the number of voting units for a given account.
        ///
        /// This implementation is specific to ERC20 tokens, where the balance
        /// of tokens directly represents the number of voting units.
        fn get_voting_units(
            self: @ComponentState<TContractState>, account: ContractAddress
        ) -> u256 {
            let mut erc20_component = get_dep_component!(self, ERC20);
            erc20_component.balance_of(account)
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl TokenTrait: TokenVotesTrait<ComponentState<TContractState>>,
        +NoncesComponent::HasComponent<TContractState>,
        +SNIP12Metadata,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Delegates all of `account`'s voting units to `delegatee`.
        ///
        /// Emits a `DelegateChanged` event.
        /// May emit one or two `DelegateVotesChanged` events.
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

        /// Moves delegated votes from one delegate to another.
        ///
        /// May emit one or two `DelegateVotesChanged` events.
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

        /// Transfers, mints, or burns voting units.
        ///
        /// To register a mint, `from` should be zero. To register a burn, `to`
        /// should be zero. Total supply of voting units will be adjusted with mints and burns.
        ///
        /// May emit one or two `DelegateVotesChanged` events.
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
