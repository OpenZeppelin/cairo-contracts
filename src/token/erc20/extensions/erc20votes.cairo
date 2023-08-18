// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (token/erc20/extensions/erc20votes.cairo)

/// This is a contract that tracks voting units from ERC20 balances, which are a measure of voting power that can be
/// transferred, and provides a system of vote delegation, where an account can delegate its voting units to a sort of
/// "representative" that will pool delegated voting units from different accounts and can then use it to vote in
/// decisions. In fact, voting units MUST be delegated in order to count as actual votes, and an account has to
/// delegate those votes to itself if it wishes to participate in decisions and does not have a trusted representative.
#[starknet::contract]
mod ERC20Votes {
    use array::{ArrayTrait, SpanTrait};
    use openzeppelin::governance::utils::interfaces::IVotes;
    use openzeppelin::token::erc20::ERC20;
    use openzeppelin::utils::cryptography::eip712;
    use openzeppelin::utils::nonces::Nonces;
    use openzeppelin::utils::selectors;
    use openzeppelin::utils::serde::SerializedAppend;
    use openzeppelin::utils::structs::checkpoints::{Checkpoint, Trace, TraceTrait};
    use poseidon::poseidon_hash_span;
    use starknet::ContractAddress;
    use starknet::contract_address_const;
    use traits::Into;

    #[storage]
    struct Storage {
        _delegatee: LegacyMap<ContractAddress, ContractAddress>,
        _delegate_checkpoints: LegacyMap<ContractAddress, Trace>,
        _total_checkpoints: Trace
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
    }

    #[external(v0)]
    impl VotesImpl of IVotes<ContractState> {
        fn get_votes(self: @ContractState, account: ContractAddress) -> u256 {
            self._delegate_checkpoints.read(account).latest()
        }

        fn get_past_votes(self: @ContractState, account: ContractAddress, timepoint: u64) -> u256 {
            let current_timepoint = starknet::get_block_timestamp();
            assert(timepoint < current_timepoint, Errors::FUTURE_LOOKUP);

            self._delegate_checkpoints.read(account).upper_lookup_recent(timepoint)
        }

        fn get_past_total_supply(self: @ContractState, timepoint: u64) -> u256 {
            let current_timepoint = starknet::get_block_timestamp();
            assert(timepoint < current_timepoint, Errors::FUTURE_LOOKUP);

            self._total_checkpoints.read().upper_lookup_recent(timepoint)
        }

        fn delegates(self: @ContractState, account: ContractAddress) -> ContractAddress {
            self._delegatee.read(account)
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
            Nonces::InternalImpl::_use_checked_nonce(ref unsafe_state, delegator, nonce);

            // Build hash for calling `is_valid_signature`.
            let domain_separator = eip712::build_domain_separator('OZ-ERC20Votes', 'v4');
            let struct_hash = poseidon_hash_span(
                array![DELEGATION_TYPEHASH(), delegatee.into(), nonce, expiry.into()].span()
            );
            let hash = eip712::to_typed_data_hash(domain_separator, struct_hash);

            let mut calldata = array![];
            calldata.append_serde(hash);
            calldata.append_serde(signature);

            starknet::call_contract_syscall(
                delegator, selectors::is_valid_signature, calldata.span()
            )
                .unwrap_syscall();

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
            self._total_checkpoints.read().latest()
        }

        /// Delegate all of `account`'s voting units to `delegatee`.
        fn _delegate(
            ref self: ContractState, account: ContractAddress, delegatee: ContractAddress
        ) {
            let from_delegate = VotesImpl::delegates(@self, account);
            self._delegatee.write(account, delegatee);

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
            let zero_address = contract_address_const::<0>();
            let block_timestamp = starknet::get_block_timestamp();
            if (from != to && amount > 0) {
                if (from != zero_address) {
                    let mut trace = self._delegate_checkpoints.read(from);
                    let (previous_votes, new_votes) = trace
                        .push(block_timestamp, trace.latest() - amount);
                    self.emit(DelegateVotesChanged { delegate: from, previous_votes, new_votes });
                }
                if (to != zero_address) {
                    let mut trace = self._delegate_checkpoints.read(to);
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
            let zero_address = contract_address_const::<0>();
            let block_timestamp = starknet::get_block_timestamp();
            if (from == zero_address) {
                let mut trace = self._total_checkpoints.read();
                trace.push(block_timestamp, trace.latest() + amount);
            }
            if (to == zero_address) {
                let mut trace = self._total_checkpoints.read();
                trace.push(block_timestamp, trace.latest() - amount);
            }
            self
                .move_delegate_votes(
                    VotesImpl::delegates(@self, from), VotesImpl::delegates(@self, to), amount
                );
        }

        /// Get number of checkpoints for `account`.
        fn num_checkpoints(self: @ContractState, account: ContractAddress) -> u32 {
            self._delegate_checkpoints.read(account).length()
        }

        /// Get the `pos`-th checkpoint for `account`.
        fn checkpoints(self: @ContractState, account: ContractAddress, pos: u32) -> Checkpoint {
            self._delegate_checkpoints.read(account).at(pos)
        }

        fn get_voting_units(self: @ContractState, account: ContractAddress) -> u256 {
            let unsafe_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::balance_of(@unsafe_state, account)
        }
    }

    fn DELEGATION_TYPEHASH() -> felt252 {
        poseidon_hash_span(
            array!['Delegation', '(delegatee: ContractAddress,', 'nonce: felt252,', 'expiry: u64)']
                .span()
        )
    }
}
