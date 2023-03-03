use erc165::tests::erc165mock::ERC165Mock;

const ERC165_ID: felt = 0x01ffc9a7;
const INVALID_ID: felt = 0xffffffff;
const OTHER_ID: felt = 0x12345678;


#[test]
#[available_gas(2000000)]
fn test_default_behavior() {
    let supports_default_interface: bool = ERC165Mock::supports_interface(ERC165_ID);
    assert(supports_default_interface, 'Should support base interface');
}

#[test]
#[available_gas(2000000)]
fn test_not_registered_interface() {
    let supports_unregistered_interface: bool = ERC165Mock::supports_interface(OTHER_ID);
    assert(! supports_unregistered_interface, 'Should not support unregistered');
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test_supports_invalid_interface() {
    let supports_invalid_interface: bool = ERC165Mock::supports_interface(INVALID_ID);
    assert(! supports_invalid_interface, 'Should not support invalid id');
}

#[test]
#[available_gas(2000000)]
fn test_register_interface() {
    ERC165Mock::register_interface(OTHER_ID);
    let supports_new_interface: bool = ERC165Mock::supports_interface(OTHER_ID);
    assert(supports_new_interface, 'Should support new interface');
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test_register_invalid_interface() {
    ERC165Mock::register_interface(INVALID_ID);
}
