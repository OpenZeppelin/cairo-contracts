const IERC165_ID: u32 = 0x01ffc9a7_u32;
const INVALID_ID: u32 = 0xffffffff_u32;

#[abi]
trait IERC165 {
    #[view]
    fn supports_interface(interface_id: u32) -> bool;
}

#[abi]
trait IERC165Camel {
    #[view]
    fn supportsInterface(interfaceId: u32) -> bool;
}

#[contract]
mod ERC165 {
    use openzeppelin::introspection::erc165;

    struct Storage {
        supported_interfaces: LegacyMap<u32, bool>
    }

    impl ERC165Impl of erc165::IERC165 {
        fn supports_interface(interface_id: u32) -> bool {
            if interface_id == erc165::IERC165_ID {
                return true;
            }
            supported_interfaces::read(interface_id)
        }
    }

    impl ERC165CamelImpl of erc165::IERC165Camel {
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
        assert(interface_id != erc165::INVALID_ID, 'Invalid id');
        supported_interfaces::write(interface_id, true);
    }

    #[internal]
    fn deregister_interface(interface_id: u32) {
        assert(interface_id != erc165::IERC165_ID, 'Invalid id');
        supported_interfaces::write(interface_id, false);
    }
}
