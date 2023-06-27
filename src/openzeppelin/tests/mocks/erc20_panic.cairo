// Although these modules are designed to panic, functions
// still need a valid return value. We chose:
//
// 3 for felt252
// zero for ContractAddress
// u256 { 3, 3 } for u256

#[contract]
mod SnakeERC20Panic {
    use starknet::ContractAddress;

    ///
    /// Agnostic
    ///

    #[view]
    fn name() -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[view]
    fn symbol() -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[view]
    fn decimals() -> u8 {
        panic_with_felt252('Some error');
        3_u8
    }

    #[view]
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256 {
        panic_with_felt252('Some error');
        u256 { low: 3, high: 3 }
    }

    #[external]
    fn transfer(recipient: ContractAddress, amount: u256) -> bool {
        panic_with_felt252('Some error');
        false
    }

    #[external]
    fn approve(to: ContractAddress, token_id: u256) -> bool {
        panic_with_felt252('Some error');
        false
    }

    ///
    /// Snake
    ///

    #[view]
    fn total_supply() -> u256 {
        panic_with_felt252('Some error');
        u256 { low: 3, high: 3 }
    }

    #[view]
    fn balance_of(account: ContractAddress) -> u256 {
        panic_with_felt252('Some error');
        u256 { low: 3, high: 3 }
    }

    #[external]
    fn transfer_from(from: ContractAddress, to: ContractAddress, amount: u256) -> bool {
        panic_with_felt252('Some error');
        false
    }
}

#[contract]
mod CamelERC20Panic {
    use starknet::ContractAddress;

    #[view]
    fn totalSupply() -> u256 {
        panic_with_felt252('Some error');
        u256 { low: 3, high: 3 }
    }

    #[view]
    fn balanceOf(account: ContractAddress) -> u256 {
        panic_with_felt252('Some error');
        u256 { low: 3, high: 3 }
    }

    #[external]
    fn transferFrom(sender: ContractAddress, recipient: ContractAddress, amount: u256) {
        panic_with_felt252('Some error');
    }
}
