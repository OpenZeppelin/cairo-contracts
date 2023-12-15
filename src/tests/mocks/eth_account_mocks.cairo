#[starknet::contract]
mod DualCaseEthAccountMock {
    use openzeppelin::account::eth_account::EthAccountComponent;
    use openzeppelin::account::eth_account::interface::EthPublicKey;
    use openzeppelin::introspection::src5::SRC5Component;

    component!(path: EthAccountComponent, storage: eth_account, event: EthAccountEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC6Impl = EthAccountComponent::SRC6Impl<ContractState>;
    #[abi(embed_v0)]
    impl SRC6CamelOnlyImpl = EthAccountComponent::SRC6CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl DeclarerImpl = EthAccountComponent::DeclarerImpl<ContractState>;
    #[abi(embed_v0)]
    impl DeployableImpl = EthAccountComponent::DeployableImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl EthAccountInternalImpl = EthAccountComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        eth_account: EthAccountComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        EthAccountEvent: EthAccountComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, public_key: EthPublicKey) {
        self.eth_account.initializer(public_key);
    }
}

#[starknet::contract]
mod SnakeEthAccountMock {
    use openzeppelin::account::eth_account::EthAccountComponent;
    use openzeppelin::account::eth_account::interface::EthPublicKey;
    use openzeppelin::introspection::src5::SRC5Component;

    component!(path: EthAccountComponent, storage: eth_account, event: EthAccountEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC6Impl = EthAccountComponent::SRC6Impl<ContractState>;
    #[abi(embed_v0)]
    impl PublicKeyImpl = EthAccountComponent::PublicKeyImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl EthAccountInternalImpl = EthAccountComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        eth_account: EthAccountComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        EthAccountEvent: EthAccountComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, public_key: EthPublicKey) {
        self.eth_account.initializer(public_key);
    }
}

#[starknet::contract]
mod CamelEthAccountMock {
    use openzeppelin::account::eth_account::EthAccountComponent;
    use openzeppelin::account::eth_account::interface::EthPublicKey;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::account::Call;

    component!(path: EthAccountComponent, storage: eth_account, event: EthAccountEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC6CamelOnlyImpl = EthAccountComponent::SRC6CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl PublicKeyCamelImpl =
        EthAccountComponent::PublicKeyCamelImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC6Impl = EthAccountComponent::SRC6Impl<ContractState>;
    impl EthAccountInternalImpl = EthAccountComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        eth_account: EthAccountComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        EthAccountEvent: EthAccountComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, publicKey: EthPublicKey) {
        self.eth_account.initializer(publicKey);
    }

    #[external(v0)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
        fn __execute__(self: @ContractState, mut calls: Array<Call>) -> Array<Span<felt252>> {
            self.eth_account.__execute__(calls)
        }

        fn __validate__(self: @ContractState, mut calls: Array<Call>) -> felt252 {
            self.eth_account.__validate__(calls)
        }
    }
}

// Although these modules are designed to panic, functions
// still need a valid return value. We chose:
//
// 3 for felt252
// false for bool

#[starknet::contract]
mod SnakeEthAccountPanicMock {
    use openzeppelin::account::eth_account::interface::EthPublicKey;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn set_public_key(ref self: ContractState, new_public_key: EthPublicKey) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn get_public_key(self: @ContractState) -> EthPublicKey {
        panic_with_felt252('Some error');
        (3, 3)
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
mod CamelEthAccountPanicMock {
    use openzeppelin::account::eth_account::interface::EthPublicKey;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn setPublicKey(ref self: ContractState, newPublicKey: EthPublicKey) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn getPublicKey(self: @ContractState) -> EthPublicKey {
        panic_with_felt252('Some error');
        (3, 3)
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
