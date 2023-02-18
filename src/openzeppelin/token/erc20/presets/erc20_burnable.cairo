#[contract]
mod ERC20Burnable {
    use erc20::ERC20Library;
    use starknet::get_caller_address;

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
    fn totalSupply() -> u256 {
       ERC20Library::total_supply()
    }

    #[view]
    fn balanceOf(account: ContractAddress) -> u256 {
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
    fn transferFrom(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
        ERC20Library::transfer_from(sender, recipient, amount)
    }

    #[external]
    fn approve(spender: ContractAddress, amount: u256) -> bool {
        ERC20Library::approve(spender, amount)
    }

    #[external]
    fn increaseAllowance(spender: ContractAddress, added_value: u256) -> bool {
        ERC20Library::increase_allowance(spender, added_value)
    }

    #[external]
    fn decreaseAllowance(spender: ContractAddress, subtracted_value: u256) -> bool {
        ERC20Library::decrease_allowance(spender, subtracted_value)
    }

    #[external]
    fn burn(amount: u256) {
        let caller = get_caller_address();
        ERC20Library::_burn(caller, amount);
    }

    #[external]
    fn burnFrom(account: ContractAddress, amount: u256) {
        let caller = get_caller_address();
        ERC20Library::_spend_allowance(account, caller, amount);
        ERC20Library::_burn(account, amount);
    }
}
