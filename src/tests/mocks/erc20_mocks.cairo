#[starknet::contract]
mod DualCaseERC20Mock {
    use openzeppelin::token::erc20::ERC20Component;
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl SafeAllowanceImpl = ERC20Component::SafeAllowanceImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl SafeAllowanceCamelImpl =
        ERC20Component::SafeAllowanceCamelImpl<ContractState>;
    impl InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20._mint(recipient, initial_supply);
    }
}

#[starknet::contract]
mod SnakeERC20Mock {
    use openzeppelin::token::erc20::ERC20Component;
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl SafeAllowanceImpl = ERC20Component::SafeAllowanceImpl<ContractState>;
    impl InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20._mint(recipient, initial_supply);
    }
}

#[starknet::contract]
mod CamelERC20Mock {
    use openzeppelin::token::erc20::ERC20Component;
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl SafeAllowanceCamelImpl =
        ERC20Component::SafeAllowanceCamelImpl<ContractState>;
    // `ERC20Impl` is not embedded because it would defeat the purpose of the
    // mock. The `ERC20Impl` case-agnostic methods are manually exposed.
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    impl InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20._mint(recipient, initial_supply);
    }

    #[external(v0)]
    fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
        self.erc20.allowance(owner, spender)
    }

    #[external(v0)]
    fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
        self.erc20.transfer(recipient, amount)
    }

    #[external(v0)]
    fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
        self.erc20.approve(spender, amount)
    }
}

#[starknet::contract]
mod SnakeERC20Panic {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn name(self: @ContractState) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn symbol(self: @ContractState) {
        panic_with_felt252('Some error');
        //panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn decimals(self: @ContractState) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn total_supply(self: @ContractState) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn balance_of(self: @ContractState, account: ContractAddress) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn transfer_from(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256
    ) {
        panic_with_felt252('Some error');
    }
}

#[starknet::contract]
mod CamelERC20Panic {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn totalSupply(self: @ContractState) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn balanceOf(self: @ContractState, account: ContractAddress) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn transferFrom(
        ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) {
        panic_with_felt252('Some error');
    }
}

