#[contract]
mod ERC20 {
    use erc20_lib::ERC20Library;

    #[constructor]
    fn constructor(name: felt, symbol: felt, amount: u256, recipient: felt) {
        ERC20Library::initializer(name, symbol, amount, recipient);
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
    fn balanceOf(account: felt) -> u256 {
        ERC20Library::balance_of(account)
    }

    #[view]
    fn allowance(owner: felt, spender: felt) -> u256 {
        ERC20Library::allowance(owner, spender)
    }

    #[external]
    fn transfer(recipient: felt, amount: u256) {
        ERC20Library::transfer(recipient, amount);
    }

    #[external]
    fn transferFrom(sender: felt, recipient: felt, amount: u256) {
        ERC20Library::transfer_from(sender, recipient, amount);
    }

    #[external]
    fn approve(spender: felt, amount: u256) {
        ERC20Library::approve(spender, amount);
    }

    #[external]
    fn increaseAllowance(spender: felt, added_value: u256) {
        ERC20Library::increase_allowance(spender, added_value);
    }

    #[external]
    fn decreaseAllowance(spender: felt, subtracted_value: u256) {
        ERC20Library::decrease_allowance(spender, subtracted_value);
    }
}
