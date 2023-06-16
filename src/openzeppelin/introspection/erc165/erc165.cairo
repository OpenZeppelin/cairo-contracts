#[contract]
mod ERC165 {
    use openzeppelin::introspection::erc165::interface;

    struct Storage {
        supported_interfaces: LegacyMap<u32, bool>
    }

    impl ERC165Impl of interface::IERC165 {
        fn supports_interface(interface_id: u32) -> bool {
            if interface_id == interface::IERC165_ID {
                return true;
            }
            supported_interfaces::read(interface_id)
        }
    }

    impl ERC165CamelImpl of interface::IERC165Camel {
        fn supportsInterface(interfaceId: u32) -> bool {
            ERC165Impl::supports_interface(interfaceId)
        }
    }

    #[view]
    fn supports_interface(interface_id: u32) -> bool {
        ERC165Impl::supports_interface(interface_id)
    }

    #[view]
    fn supportsInterface(interfaceId: u32) -> bool {
        ERC165CamelImpl::supportsInterface(interfaceId)
    }

    //
    // Internals
    //

    #[internal]
    fn register_interface(interface_id: u32) {
        assert(interface_id != interface::INVALID_ID, 'Invalid id');
        supported_interfaces::write(interface_id, true);
    }

    #[internal]
    fn deregister_interface(interface_id: u32) {
        assert(interface_id != interface::IERC165_ID, 'Invalid id');
        supported_interfaces::write(interface_id, false);
    }
}
