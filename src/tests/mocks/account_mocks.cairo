#[starknet::contract]
mod DualCaseAccountMock {
    use openzeppelin::account::Account as account_component;
    use openzeppelin::introspection::src5::SRC5 as src5_component;

    component!(path: account_component, storage: account, event: AccountEvent);
    component!(path: src5_component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC6Impl = account_component::SRC6Impl<ContractState>;
    #[abi(embed_v0)]
    impl SRC6CamelOnlyImpl = account_component::SRC6CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl DeclarerImpl = account_component::DeclarerImpl<ContractState>;
    #[abi(embed_v0)]
    impl DeployableImpl = account_component::DeployableImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = src5_component::SRC5Impl<ContractState>;
    impl AccountInternalImpl = account_component::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        account: account_component::Storage,
        #[substorage(v0)]
        src5: src5_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AccountEvent: account_component::Event,
        SRC5Event: src5_component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, public_key: felt252) {
        self.account.initializer(public_key);
    }
}

#[starknet::contract]
mod SnakeAccountMock {
    use openzeppelin::account::Account as account_component;
    use openzeppelin::introspection::src5::SRC5 as src5_component;

    component!(path: account_component, storage: account, event: AccountEvent);
    component!(path: src5_component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC6Impl = account_component::SRC6Impl<ContractState>;
    #[abi(embed_v0)]
    impl PublicKeyImpl = account_component::PublicKeyImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = src5_component::SRC5Impl<ContractState>;
    impl AccountInternalImpl = account_component::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        account: account_component::Storage,
        #[substorage(v0)]
        src5: src5_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AccountEvent: account_component::Event,
        SRC5Event: src5_component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, public_key: felt252) {
        self.account.initializer(public_key);
    }
}

#[starknet::contract]
mod CamelAccountMock {
    use openzeppelin::account::Account as account_component;
    use openzeppelin::introspection::src5::SRC5 as src5_component;
    use starknet::account::Call;

    component!(path: account_component, storage: account, event: AccountEvent);
    component!(path: src5_component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC6CamelOnlyImpl = account_component::SRC6CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl PublicKeyCamelImpl = account_component::PublicKeyCamelImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = src5_component::SRC5Impl<ContractState>;
    impl SRC6Impl = account_component::SRC6Impl<ContractState>;
    impl AccountInternalImpl = account_component::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        account: account_component::Storage,
        #[substorage(v0)]
        src5: src5_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AccountEvent: account_component::Event,
        SRC5Event: src5_component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, publicKey: felt252) {
        self.account.initializer(publicKey);
    }

    #[external(v0)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
        fn __execute__(self: @ContractState, mut calls: Array<Call>) -> Array<Span<felt252>> {
            self.account.__execute__(calls)
        }

        fn __validate__(self: @ContractState, mut calls: Array<Call>) -> felt252 {
            self.account.__validate__(calls)
        }
    }
}

// Although these modules are designed to panic, functions
// still need a valid return value. We chose:
//
// 3 for felt252
// false for bool

#[starknet::contract]
mod SnakeAccountPanicMock {
    #[storage]
    struct Storage {}

    #[external(v0)]
    fn set_public_key(ref self: ContractState, new_public_key: felt252) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn get_public_key(self: @ContractState) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn is_valid_signature(
        self: @ContractState, hash: felt252, signature: Array<felt252>
    ) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
        panic_with_felt252('Some error');
        false
    }
}

#[starknet::contract]
mod CamelAccountPanicMock {
    #[storage]
    struct Storage {}

    #[external(v0)]
    fn setPublicKey(ref self: ContractState, newPublicKey: felt252) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn getPublicKey(self: @ContractState) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn isValidSignature(self: @ContractState, hash: felt252, signature: Array<felt252>) -> felt252 {
        panic_with_felt252('Some error');
        3
    }

    #[external(v0)]
    fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
        panic_with_felt252('Some error');
        false
    }
}
