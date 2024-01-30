#[starknet::contract]
mod SnakeSRC5Mock {
    use openzeppelin::introspection::src5::SRC5Component;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event
    }
}

#[starknet::contract]
mod SnakeSRC5PanicMock {
    #[storage]
    struct Storage {}

    #[external(v0)]
    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
        panic!("Some error");
        false
    }
}
