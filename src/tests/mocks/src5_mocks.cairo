use openzeppelin::introspection::src5::SRC5;

#[starknet::contract]
mod SnakeSRC5Mock {
    #[storage]
    struct Storage {}

    #[external(v0)]
    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
        let unsafe_state = super::SRC5::unsafe_new_contract_state();
        super::SRC5::SRC5Impl::supports_interface(@unsafe_state, interface_id)
    }
}

#[starknet::contract]
mod CamelSRC5Mock {
    #[storage]
    struct Storage {}

    #[external(v0)]
    fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
        let unsafe_state = super::SRC5::unsafe_new_contract_state();
        super::SRC5::SRC5CamelImpl::supportsInterface(@unsafe_state, interfaceId)
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
