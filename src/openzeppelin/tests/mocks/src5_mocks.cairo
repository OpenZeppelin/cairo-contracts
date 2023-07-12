use openzeppelin::introspection::src5::SRC5;

#[contract]
mod SnakeSRC5Mock {
    #[view]
    fn supports_interface(interface_id: felt252) -> bool {
        super::SRC5::supports_interface(interface_id)
    }
}

#[contract]
mod CamelSRC5Mock {
    #[view]
    fn supportsInterface(interfaceId: felt252) -> bool {
        super::SRC5::supportsInterface(interfaceId)
    }
}

#[contract]
mod SnakeSRC5PanicMock {
    #[view]
    fn supports_interface(interface_id: felt252) -> bool {
        panic_with_felt252('Some error');
        false
    }
}

#[contract]
mod CamelSRC5PanicMock {
    #[view]
    fn supportsInterface(interfaceId: felt252) -> bool {
        panic_with_felt252('Some error');
        false
    }
}
