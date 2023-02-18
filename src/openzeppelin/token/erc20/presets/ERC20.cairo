#[contract]
mod ERC20 {
    use erc20::ERC20Library;

    // TMP starknet testing isn't fully functional.
    // Use to ensure paths are correctly set.
    #[external]
    fn mock_constructor(name: felt, symbol: felt) {
        ERC20Library::mock_initializer(name, symbol);
    }

    #[constructor]
    fn constructor(name: felt, symbol: felt, initial_supply: u256, recipient: ContractAddress) {
        ERC20Library::initializer(name, symbol, initial_supply, recipient);
    }

    #[view]
    fn name() -> felt {
        ERC20Library::name()
    }

    #[view]
    fn symbol() -> felt {
        ERC20Library::symbol()
    }

    #[view]
    fn decimals() -> u8 {
        ERC20Library::decimals()
    }

    #[view]
    fn total_supply() -> u256 {
       ERC20Library::total_supply()
    }

    #[view]
    fn balance_of(account: ContractAddress) -> u256 {
        ERC20Library::balance_of(account)
    }

    #[view]
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256 {
        ERC20Library::allowance(owner, spender)
    }

    #[external]
    fn transfer(recipient: ContractAddress, amount: u256) -> bool {
        ERC20Library::transfer(recipient, amount)
    }

    #[external]
    fn transfer_from(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
        ERC20Library::transfer_from(sender, recipient, amount)
    }

    #[external]
    fn approve(spender: ContractAddress, amount: u256) -> bool {
        ERC20Library::approve(spender, amount)
    }

    #[external]
    fn increase_allowance(spender: ContractAddress, added_value: u256) -> bool {
        ERC20Library::increase_allowance(spender, added_value)
    }

    #[external]
    fn decrease_allowance(spender: ContractAddress, subtracted_value: u256) -> bool {
        ERC20Library::decrease_allowance(spender, subtracted_value)
    }
}
