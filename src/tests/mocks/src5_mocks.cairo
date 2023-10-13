use openzeppelin::introspection::src5::SRC5;

#[starknet::contract]
mod DualCaseSRC5Mock {
    use openzeppelin::introspection::src5::SRC5 as src5_component;

    component!(path: src5_component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC5Impl = src5_component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5CamelOnlyImpl = src5_component::SRC5CamelImpl<ContractState>;
    impl InternalImpl = src5_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: src5_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SRC5Event: src5_component::Event
    }
}

#[starknet::contract]
mod SnakeSRC5Mock {
    use openzeppelin::introspection::src5::SRC5 as src5_component;

    component!(path: src5_component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC5Impl = src5_component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: src5_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SRC5Event: src5_component::Event
    }
}

#[starknet::contract]
mod CamelSRC5Mock {
    use openzeppelin::introspection::src5::SRC5 as src5_component;

    component!(path: src5_component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC5CamelImpl = src5_component::SRC5CamelImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: src5_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SRC5Event: src5_component::Event
    }
}

#[starknet::contract]
mod SnakeSRC5PanicMock {
    #[storage]
    struct Storage {}

    #[external(v0)]
    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
        panic_with_felt252('Some error');
        false
    }
}

#[starknet::contract]
mod CamelSRC5PanicMock {
    #[storage]
    struct Storage {}

    #[external(v0)]
    fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
        panic_with_felt252('Some error');
        false
    }
}
