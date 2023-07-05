use starknet::ContractAddress;

#[abi]
trait IERC20 {
    #[view]
    fn name() -> felt252;
    #[view]
    fn symbol() -> felt252;
    #[view]
    fn decimals() -> u8;
    #[view]
    fn total_supply() -> u256;
    #[view]
    fn balance_of(account: ContractAddress) -> u256;
    #[view]
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256;
    #[external]
    fn transfer(recipient: ContractAddress, amount: u256) -> bool;
    #[external]
    fn transfer_from(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    #[external]
    fn approve(spender: ContractAddress, amount: u256) -> bool;
}

#[abi]
trait IERC20Camel {
    #[view]
    fn name() -> felt252;
    #[view]
    fn symbol() -> felt252;
    #[view]
    fn decimals() -> u8;
    #[view]
    fn totalSupply() -> u256;
    #[view]
    fn balanceOf(account: ContractAddress) -> u256;
    #[view]
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256;
    #[external]
    fn transfer(recipient: ContractAddress, amount: u256) -> bool;
    #[external]
    fn transferFrom(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    #[external]
    fn approve(spender: ContractAddress, amount: u256) -> bool;
}
