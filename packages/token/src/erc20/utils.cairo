use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use starknet::ContractAddress;

mod Errors {
    pub const TRANSFER_FAILED: felt252 = 'ERC20 transfer failed';
}

#[generate_trait]
pub impl ERC20Utils of ERC20UtilsTrait {
    fn get_self_balance(token: ContractAddress) -> u256 {
        IERC20Dispatcher { contract_address: token }.balance_of(starknet::get_contract_address())
    }

    fn transfer(token: ContractAddress, to: ContractAddress, amount: u256) {
        let is_success = IERC20Dispatcher { contract_address: token }.transfer(to, amount);
        assert(is_success, Errors::TRANSFER_FAILED);
    }

    fn transfer_from(
        token: ContractAddress, from: ContractAddress, to: ContractAddress, amount: u256
    ) {
        let is_success = IERC20Dispatcher { contract_address: token }
            .transfer_from(from, to, amount);
        assert(is_success, Errors::TRANSFER_FAILED);
    }
}
