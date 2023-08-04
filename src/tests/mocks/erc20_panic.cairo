// Although these modules are designed to panic, functions
// still need a valid return value. We chose:
//
// 3 for felt252, u8, and u256
// zero for ContractAddress
// false for bool

#[starknet::contract]
mod SnakeERC20Panic {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn name(self: @ContractState) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn symbol(self: @ContractState) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn decimals(self: @ContractState) -> u8 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
        panic_with_felt252('Some error');
        false
    }

    #[external(v0)]
    fn approve(ref self: ContractState, to: ContractAddress, token_id: u256) -> bool {
        panic_with_felt252('Some error');
        false
    }

    #[external(v0)]
    fn total_supply(self: @ContractState) -> u256 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn transfer_from(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256
    ) -> bool {
        panic_with_felt252('Some error');
        false
    }
}

#[starknet::contract]
mod CamelERC20Panic {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn totalSupply(self: @ContractState) -> u256 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn transferFrom(
        ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) {
        panic_with_felt252('Some error');
    }
}
