const ISRC5_ID: u32 = 0x1ba86cc668fafde77705c7bfcafa3ee47934b5631ff0e32841dcdcd4e100a60;

#[abi]
trait ISRC5 {
    fn supports_interface(interface_id: felt252) -> bool;
}

#[contract]
mod SRC5 {
    use openzeppelin::introspection::src5;

    struct Storage {
        supported_interfaces: LegacyMap<felt252, bool>
    }

    impl SRC5Impl of src5::ISRC5 {
        fn supports_interface(interface_id: felt252) -> bool {
            if interface_id == src5::ISRC5_ID {
                return true;
            }
            supported_interfaces::read(interface_id)
        }
    }

    #[view]
    fn supports_interface(interface_id: felt252) -> bool {
        SRC5Impl::supports_interface(interface_id)
    }

    #[internal]
    fn register_interface(interface_id: felt252) {
        supported_interfaces::write(interface_id, true);
    }

    #[internal]
    fn deregister_interface(interface_id: u32) {
        assert(interface_id != src5::ISRC5_ID, 'Invalid id');
        supported_interfaces::write(interface_id, false);
    }
}
