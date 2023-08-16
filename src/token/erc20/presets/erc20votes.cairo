// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (token/erc20/presets/erc20votes.cairo)

/// ERC20 with the ERC20Votes extension.
#[starknet::contract]
mod ERC20VotesPreset {
    use openzeppelin::governance::utils::interfaces::IVotes;
    use openzeppelin::token::erc20::ERC20;
    use openzeppelin::token::erc20::extensions::ERC20Votes;
    use openzeppelin::token::erc20::interface::{IERC20, IERC20Camel};
    use openzeppelin::utils::structs::checkpoints::Checkpoint;
    use starknet::ContractAddress;
    use starknet::contract_address_const;

    #[storage]
    struct Storage {}

    //
    // Hooks
    //

    impl ERC20VotesHooksImpl of ERC20::ERC20HooksTrait {
        fn _after_update(
            ref self: ERC20::ContractState,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            let mut unsafe_state = ERC20Votes::unsafe_new_contract_state();
            ERC20Votes::InternalImpl::transfer_voting_units(
                ref unsafe_state, from, recipient, amount
            );
        }
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        let mut unsafe_state = ERC20::unsafe_new_contract_state();
        ERC20::InternalImpl::initializer(ref unsafe_state, name, symbol);
        ERC20::InternalImpl::_mint::<ERC20VotesHooksImpl>(
            ref unsafe_state, recipient, initial_supply
        );
    }

    //
    // External
    //

    #[external(v0)]
    impl ERC20Impl of IERC20<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            let unsafe_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::name(@unsafe_state)
        }

        fn symbol(self: @ContractState) -> felt252 {
            let unsafe_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::symbol(@unsafe_state)
        }

        fn decimals(self: @ContractState) -> u8 {
            let unsafe_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::decimals(@unsafe_state)
        }

        fn total_supply(self: @ContractState) -> u256 {
            let unsafe_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::total_supply(@unsafe_state)
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            let unsafe_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::balance_of(@unsafe_state, account)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            let unsafe_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::allowance(@unsafe_state, owner, spender)
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let mut unsafe_state = ERC20::unsafe_new_contract_state();
            let sender = starknet::get_caller_address();
            ERC20::InternalImpl::_transfer::<ERC20VotesHooksImpl>(
                ref unsafe_state, sender, recipient, amount
            );
            true
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            let mut unsafe_state = ERC20::unsafe_new_contract_state();
            let caller = starknet::get_caller_address();
            ERC20::InternalImpl::_spend_allowance(ref unsafe_state, sender, caller, amount);
            ERC20::InternalImpl::_transfer::<ERC20VotesHooksImpl>(
                ref unsafe_state, sender, recipient, amount
            );
            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let mut unsafe_state = ERC20::unsafe_new_contract_state();
            ERC20::ERC20Impl::approve(ref unsafe_state, spender, amount)
        }
    }

    #[external(v0)]
    fn increase_allowance(
        ref self: ContractState, spender: ContractAddress, added_value: u256
    ) -> bool {
        let mut unsafe_state = ERC20::unsafe_new_contract_state();
        ERC20::InternalImpl::_increase_allowance(ref unsafe_state, spender, added_value)
    }

    #[external(v0)]
    fn decrease_allowance(
        ref self: ContractState, spender: ContractAddress, subtracted_value: u256
    ) -> bool {
        let mut unsafe_state = ERC20::unsafe_new_contract_state();
        ERC20::InternalImpl::_decrease_allowance(ref unsafe_state, spender, subtracted_value)
    }

    #[external(v0)]
    impl VotesImpl of IVotes<ContractState> {
        fn get_votes(self: @ContractState, account: ContractAddress) -> u256 {
            let unsafe_state = ERC20Votes::unsafe_new_contract_state();
            ERC20Votes::VotesImpl::get_votes(@unsafe_state, account)
        }

        fn get_past_votes(self: @ContractState, account: ContractAddress, timepoint: u64) -> u256 {
            let unsafe_state = ERC20Votes::unsafe_new_contract_state();
            ERC20Votes::VotesImpl::get_past_votes(@unsafe_state, account, timepoint)
        }

        fn get_past_total_supply(self: @ContractState, timepoint: u64) -> u256 {
            let unsafe_state = ERC20Votes::unsafe_new_contract_state();
            ERC20Votes::VotesImpl::get_past_total_supply(@unsafe_state, timepoint)
        }

        fn delegates(self: @ContractState, account: ContractAddress) -> ContractAddress {
            let unsafe_state = ERC20Votes::unsafe_new_contract_state();
            ERC20Votes::VotesImpl::delegates(@unsafe_state, account)
        }

        fn delegate(ref self: ContractState, delegatee: ContractAddress) {
            let mut unsafe_state = ERC20Votes::unsafe_new_contract_state();
            ERC20Votes::VotesImpl::delegate(ref unsafe_state, delegatee);
        }

        fn delegate_by_sig(
            ref self: ContractState,
            delegator: ContractAddress,
            delegatee: ContractAddress,
            nonce: felt252,
            expiry: u64,
            signature: Array<felt252>
        ) {
            let mut unsafe_state = ERC20Votes::unsafe_new_contract_state();
            ERC20Votes::VotesImpl::delegate_by_sig(
                ref unsafe_state, delegator, delegatee, nonce, expiry, signature
            );
        }
    }

    /// Get number of checkpoints for `account`.
    #[external(v0)]
    fn num_checkpoints(self: @ContractState, account: ContractAddress) -> u32 {
        let unsafe_state = ERC20Votes::unsafe_new_contract_state();
        ERC20Votes::InternalImpl::_num_checkpoints(@unsafe_state, account)
    }

    /// Get the `pos`-th checkpoint for `account`.
    #[external(v0)]
    fn checkpoints(self: @ContractState, account: ContractAddress, pos: u32) -> Checkpoint {
        let unsafe_state = ERC20Votes::unsafe_new_contract_state();
        ERC20Votes::InternalImpl::_checkpoints(@unsafe_state, account, pos)
    }
}
