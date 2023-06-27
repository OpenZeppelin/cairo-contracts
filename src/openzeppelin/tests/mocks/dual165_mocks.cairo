#[contract]
mod SnakeERC165Mock {
    use openzeppelin::introspection::erc165::ERC165;

    #[view]
    fn supports_interface(interface_id: u32) -> bool {
        ERC165::supports_interface(interface_id)
    }
}

#[contract]
mod CamelERC165Mock {
    use openzeppelin::introspection::erc165::ERC165;

    #[view]
    fn supportsInterface(interfaceId: u32) -> bool {
        ERC165::supportsInterface(interfaceId)
    }
}

#[contract]
mod SnakeERC165PanicMock {
    use openzeppelin::introspection::erc165::ERC165;

    #[view]
    fn supports_interface(interface_id: u32) -> bool {
        panic_with_felt252('Some error');
        false
    }
}

#[contract]
mod CamelERC165PanicMock {
    use openzeppelin::introspection::erc165::ERC165;

    #[view]
    fn supportsInterface(interfaceId: u32) -> bool {
        panic_with_felt252('Some error');
        false
    }
}
