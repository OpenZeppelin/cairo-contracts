#[contract]
mod ERC165Mock {
    use erc165::IERC165;
    const IERC165_ID: felt = 0x01ffc9a7;
    const INVALID_ID: felt = 0xffffffff;

    struct Storage {
        supported_interfaces: LegacyMap::<felt, bool>,
    }

    impl ERC165 of IERC165 {
        fn supports_interface(interface_id: felt) -> bool {
            if interface_id == IERC165_ID {
                return true;
            }
            supported_interfaces::read(interface_id)
        }
        
        fn register_interface(interface_id: felt) {
            assert(interface_id != INVALID_ID, 'Invalid id');
            supported_interfaces::write(interface_id, true);
        }
    }

    #[view]
    fn supports_interface(interface_id: felt) -> bool {
        ERC165::supports_interface(interface_id)
    }
    
    #[external]
    fn register_interface(interface_id: felt) {
        ERC165::register_interface(interface_id)
    }
}
