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
