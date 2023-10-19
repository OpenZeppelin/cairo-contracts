#[starknet::contract]
mod DualCaseERC20 {
    use openzeppelin::token::erc20::ERC20 as erc20_component;
    use starknet::ContractAddress;

    component!(path: erc20_component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = erc20_component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = erc20_component::ERC20MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl SafeAllowanceImpl =
        erc20_component::SafeAllowanceImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = erc20_component::ERC20CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl SafeAllowanceCamelImpl =
        erc20_component::SafeAllowanceCamelImpl<ContractState>;
    impl InternalImpl = erc20_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: erc20_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: erc20_component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20._mint(recipient, initial_supply);
    }
}

#[starknet::contract]
mod SnakeERC20Mock {
    use openzeppelin::token::erc20::ERC20 as erc20_component;
    use starknet::ContractAddress;

    component!(path: erc20_component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = erc20_component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = erc20_component::ERC20MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl SafeAllowanceImpl =
        erc20_component::SafeAllowanceImpl<ContractState>;
    impl InternalImpl = erc20_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: erc20_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ERC20Event: erc20_component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20._mint(recipient, initial_supply);
    }
}

#[starknet::contract]
mod CamelERC20Mock {
    use openzeppelin::token::erc20::ERC20 as erc20_component;
    use starknet::ContractAddress;

    component!(path: erc20_component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = erc20_component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = erc20_component::ERC20MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = erc20_component::ERC20CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl SafeAllowanceCamelImpl =
        erc20_component::SafeAllowanceCamelImpl<ContractState>;
    impl InternalImpl = erc20_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: erc20_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ERC20Event: erc20_component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20._mint(recipient, initial_supply);
    }
}

/// Although these modules are designed to panic, functions
/// still need a valid return value. We chose:
///
/// 3 for felt252, u8, and u256
/// zero for ContractAddress
/// false for bool
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

