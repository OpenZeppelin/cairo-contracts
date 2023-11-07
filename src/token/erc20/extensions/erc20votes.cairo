// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0-beta.1 (token/erc20/extensions/erc20votes.cairo)

use core::hash::HashStateExTrait;
use hash::{HashStateTrait, Hash};
use openzeppelin::utils::cryptography::typed_message::IOffchainMessageHash;
use openzeppelin::utils::cryptography::typed_message::IStructHash;
use openzeppelin::utils::cryptography::typed_message::StarknetDomain;
use pedersen::{PedersenTrait, HashState};
use starknet::ContractAddress;

/// This is a contract that tracks voting units from ERC20 balances, which are a measure of voting power that can be
/// transferred, and provides a system of vote delegation, where an account can delegate its voting units to a sort of
/// "representative" that will pool delegated voting units from different accounts and can then use it to vote in
/// decisions. In fact, voting units MUST be delegated in order to count as actual votes, and an account has to
/// delegate those votes to itself if it wishes to participate in decisions and does not have a trusted representative.
#[starknet::contract]
mod ERC20Votes {
    use openzeppelin::account::dual_account::{DualCaseAccount, DualCaseAccountABI};
    use openzeppelin::governance::utils::interfaces::IVotes;
    use openzeppelin::token::erc20::ERC20;
    use openzeppelin::utils::cryptography::eip712_draft::EIP712;
    use openzeppelin::utils::nonces::Nonces;
    use openzeppelin::utils::selectors;
    use openzeppelin::utils::serde::SerializedAppend;
    use openzeppelin::utils::structs::checkpoints::{Checkpoint, Trace, TraceTrait};
    use starknet::ContractAddress;
    use super::Delegation;
    use super::IOffchainMessageHash;

    #[storage]
    struct Storage {
        ERC20Votes_delegatee: LegacyMap<ContractAddress, ContractAddress>,
        ERC20Votes_delegate_checkpoints: LegacyMap<ContractAddress, Trace>,
        ERC20Votes_total_checkpoints: Trace
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        DelegateChanged: DelegateChanged,
        DelegateVotesChanged: DelegateVotesChanged,
    }

    #[derive(Drop, starknet::Event)]
    struct DelegateChanged {
        delegator: ContractAddress,
        from_delegate: ContractAddress,
        to_delegate: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct DelegateVotesChanged {
        delegate: ContractAddress,
        previous_votes: u256,
        new_votes: u256
    }

    mod Errors {
        const FUTURE_LOOKUP: felt252 = 'Votes: future Lookup';
        const EXPIRED_SIGNATURE: felt252 = 'Votes: expired signature';
        const INVALID_SIGNATURE: felt252 = 'Votes: invalid signature';
    }

    #[external(v0)]
    impl VotesImpl of IVotes<ContractState> {
        fn get_votes(self: @ContractState, account: ContractAddress) -> u256 {
            self.ERC20Votes_delegate_checkpoints.read(account).latest()
        }

        fn get_past_votes(self: @ContractState, account: ContractAddress, timepoint: u64) -> u256 {
            let current_timepoint = starknet::get_block_timestamp();
            assert(timepoint < current_timepoint, Errors::FUTURE_LOOKUP);

            self.ERC20Votes_delegate_checkpoints.read(account).upper_lookup_recent(timepoint)
        }

        fn get_past_total_supply(self: @ContractState, timepoint: u64) -> u256 {
            let current_timepoint = starknet::get_block_timestamp();
            assert(timepoint < current_timepoint, Errors::FUTURE_LOOKUP);

            self.ERC20Votes_total_checkpoints.read().upper_lookup_recent(timepoint)
        }

        fn delegates(self: @ContractState, account: ContractAddress) -> ContractAddress {
            self.ERC20Votes_delegatee.read(account)
        }

        fn delegate(ref self: ContractState, delegatee: ContractAddress) {
            let sender = starknet::get_caller_address();
            self._delegate(sender, delegatee);
        }

        fn delegate_by_sig(
            ref self: ContractState,
            delegator: ContractAddress,
            delegatee: ContractAddress,
            nonce: felt252,
            expiry: u64,
            signature: Array<felt252>
        ) {
            assert(starknet::get_block_timestamp() <= expiry, Errors::EXPIRED_SIGNATURE);

            // Check and increase nonce.
            let mut unsafe_state = Nonces::unsafe_new_contract_state();
            Nonces::InternalImpl::use_checked_nonce(ref unsafe_state, delegator, nonce);

            // Build hash for calling `is_valid_signature`.
            let delegation = Delegation { delegatee, nonce, expiry };

            let eip712_state = EIP712::unsafe_new_contract_state();
            let name = EIP712::name(@eip712_state);
            let version = EIP712::version(@eip712_state);

            let hash = delegation.get_message_hash(name, version, delegator);

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

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Returns the current total supply of votes.
        fn get_total_supply(self: @ContractState) -> u256 {
            self.ERC20Votes_total_checkpoints.read().latest()
        }

        /// Delegates all of `account`'s voting units to `delegatee`.
        fn _delegate(
            ref self: ContractState, account: ContractAddress, delegatee: ContractAddress
        ) {
            let from_delegate = VotesImpl::delegates(@self, account);
            self.ERC20Votes_delegatee.write(account, delegatee);

            self
                .emit(
                    DelegateChanged { delegator: account, from_delegate, to_delegate: delegatee }
                );
            self.move_delegate_votes(from_delegate, delegatee, self.get_voting_units(account));
        }

        /// Moves delegated votes from one delegate to another.
        fn move_delegate_votes(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256
        ) {
            let zero_address = Zeroable::zero();
            let block_timestamp = starknet::get_block_timestamp();
            if (from != to && amount > 0) {
                if (from != zero_address) {
                    let mut trace = self.ERC20Votes_delegate_checkpoints.read(from);
                    let (previous_votes, new_votes) = trace
                        .push(block_timestamp, trace.latest() - amount);
                    self.emit(DelegateVotesChanged { delegate: from, previous_votes, new_votes });
                }
                if (to != zero_address) {
                    let mut trace = self.ERC20Votes_delegate_checkpoints.read(to);
                    let (previous_votes, new_votes) = trace
                        .push(block_timestamp, trace.latest() + amount);
                    self.emit(DelegateVotesChanged { delegate: to, previous_votes, new_votes });
                }
            }
        }

        /// Transfers, mints, or burns voting units. To register a mint, `from` should be zero. To register a burn, `to`
        /// should be zero. Total supply of voting units will be adjusted with mints and burns.
        fn transfer_voting_units(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256
        ) {
            let zero_address = Zeroable::zero();
            let block_timestamp = starknet::get_block_timestamp();
            if (from == zero_address) {
                let mut trace = self.ERC20Votes_total_checkpoints.read();
                trace.push(block_timestamp, trace.latest() + amount);
            }
            if (to == zero_address) {
                let mut trace = self.ERC20Votes_total_checkpoints.read();
                trace.push(block_timestamp, trace.latest() - amount);
            }
            self
                .move_delegate_votes(
                    VotesImpl::delegates(@self, from), VotesImpl::delegates(@self, to), amount
                );
        }

        /// Get number of checkpoints for `account`.
        fn num_checkpoints(self: @ContractState, account: ContractAddress) -> u32 {
            self.ERC20Votes_delegate_checkpoints.read(account).length()
        }

        /// Get the `pos`-th checkpoint for `account`.
        fn checkpoints(self: @ContractState, account: ContractAddress, pos: u32) -> Checkpoint {
            self.ERC20Votes_delegate_checkpoints.read(account).at(pos)
        }

        fn get_voting_units(self: @ContractState, account: ContractAddress) -> u256 {
            let unsafe_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::balance_of(@unsafe_state, account)
        }
    }
}

//
// Offchain message hash generation helpers.
//

// sn_keccak('Delegation(delegatee:felt,nonce:felt,expiry:felt)')
const DELEGATION_TYPE_HASH: felt252 =
    0x3199be234dc4a3b2ba2613182079bc0a1f7f9c445a77a7a36ae800010d8c939;

#[derive(Copy, Drop, Hash)]
struct Delegation {
    delegatee: ContractAddress,
    nonce: felt252,
    expiry: u64
}

impl OffchainMessageHashImpl of IOffchainMessageHash<Delegation> {
    fn get_message_hash(
        self: @Delegation, name: felt252, version: felt252, owner: ContractAddress
    ) -> felt252 {
        let domain = StarknetDomain {
            name, version, chain_id: starknet::get_tx_info().unbox().chain_id
        };
        let hash_state = PedersenTrait::new(0);
        hash_state
            .update_with('StarkNet Message')
            .update_with(domain.hash_struct())
            .update_with(owner)
            .update_with(self.hash_struct())
            .update_with(4)
            .finalize()
    }
}

impl StructHashImpl of IStructHash<Delegation> {
    fn hash_struct(self: @Delegation) -> felt252 {
        let hash_state = PedersenTrait::new(0);
        hash_state.update_with(DELEGATION_TYPE_HASH).update_with(*self).update_with(4).finalize()
    }
}
