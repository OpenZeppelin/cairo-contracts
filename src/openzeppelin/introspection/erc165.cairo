const IERC165_ID: felt252 = 0x01ffc9a7;
const INVALID_ID: felt252 = 0xffffffff;

trait IERC165 {
  fn supports_interface(interface_id: felt252) -> bool;
  fn register_interface(interface_id: felt252);
}

#[contract]
mod ERC165Contract {
    use openzeppelin::introspection::erc165;

    struct Storage {
        supported_interfaces: LegacyMap<felt252, bool>,
    }

    impl ERC165 of erc165::IERC165 {
        fn supports_interface(interface_id: felt252) -> bool {
            if interface_id == erc165::IERC165_ID {
                return true;
            }
            supported_interfaces::read(interface_id)
        }
 
        fn register_interface(interface_id: felt252) {
            assert(interface_id != erc165::INVALID_ID, 'Invalid id');
            supported_interfaces::write(interface_id, true);
        }
    }

    #[view]
    fn supports_interface(interface_id: felt252) -> bool {
        ERC165::supports_interface(interface_id)
    }
 
    #[external]
    fn register_interface(interface_id: felt) {
        ERC165::register_interface(interface_id)
    }
}
