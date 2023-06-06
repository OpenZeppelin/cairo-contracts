#[contract]
mod CamelERC20Mock {
    use starknet::ContractAddress;
    use openzeppelin::token::erc20::ERC20;

    #[constructor]
    fn constructor(
        name: felt252, symbol: felt252, initial_supply: u256, recipient: ContractAddress
    ) {
        ERC20::initializer(name, symbol);
        ERC20::_mint(recipient, initial_supply);
    }

    #[view]
    fn name() -> felt252 {
        ERC20::name()
    }

    #[view]
    fn symbol() -> felt252 {
        ERC20::symbol()
    }

    #[view]
    fn decimals() -> u8 {
        ERC20::decimals()
    }

    #[view]
    fn totalSupply() -> u256 {
        ERC20::totalSupply()
    }

    #[view]
    fn balanceOf(account: ContractAddress) -> u256 {
        ERC20::balanceOf(account)
    }

    #[view]
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256 {
        ERC20::allowance(owner, spender)
    }

    #[external]
    fn transfer(recipient: ContractAddress, amount: u256) -> bool {
        ERC20::transfer(recipient, amount)
    }

    #[external]
    fn transferFrom(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool {
        ERC20::transferFrom(sender, recipient, amount)
    }

    #[external]
    fn approve(spender: ContractAddress, amount: u256) -> bool {
        ERC20::approve(spender, amount)
    }
}
