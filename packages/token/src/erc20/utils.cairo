use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use starknet::ContractAddress;

mod Errors {
    pub const TRANSFER_FAILED: felt252 = 'ERC20 transfer failed';
}

/// A module containing utility functions for interacting with ERC-20 token contracts.
#[generate_trait]
pub impl ERC20Utils of ERC20UtilsTrait {
    /// Returns the balance of the given `token` held by the contract in which this function is called.
    fn get_self_balance(token: ContractAddress) -> u256 {
        IERC20Dispatcher { contract_address: token }.balance_of(starknet::get_contract_address())
    }

    /// Transfers the specified `amount` of tokens from the caller's balance to the `to` address 
    /// and ensures that the transfer is successful.
    fn transfer(token: ContractAddress, to: ContractAddress, amount: u256) {
        let is_success = IERC20Dispatcher { contract_address: token }.transfer(to, amount);
        assert(is_success, Errors::TRANSFER_FAILED);
    }

    /// Transfers the specified amount of tokens from the from address to the to address using
    /// the allowance mechanism and ensures the transfer is successful.
    fn transfer_from(
        token: ContractAddress, from: ContractAddress, to: ContractAddress, amount: u256
    ) {
        let is_success = IERC20Dispatcher { contract_address: token }
            .transfer_from(from, to, amount);
        assert(is_success, Errors::TRANSFER_FAILED);
    }
}
