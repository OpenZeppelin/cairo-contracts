use openzeppelin::introspection::erc165::ERC165Contract;
use openzeppelin::introspection::erc165::IERC165_ID;
use openzeppelin::introspection::erc165::INVALID_ID;

const OTHER_ID: u32 = 0x12345678_u32;

#[test]
#[available_gas(2000000)]
fn test_default_behavior() {
    let supports_default_interface: bool = ERC165Contract::supports_interface(IERC165_ID);
    assert(supports_default_interface, 'Should support base interface');
}

#[test]
#[available_gas(2000000)]
fn test_not_registered_interface() {
    let supports_unregistered_interface: bool = ERC165Contract::supports_interface(OTHER_ID);
    assert(!supports_unregistered_interface, 'Should not support unregistered');
}

#[test]
#[available_gas(2000000)]
fn test_supports_invalid_interface() {
    let supports_invalid_interface: bool = ERC165Contract::supports_interface(INVALID_ID);
    assert(!supports_invalid_interface, 'Should not support invalid id');
}

#[test]
#[available_gas(2000000)]
fn test_register_interface() {
    ERC165Contract::register_interface(OTHER_ID);
    let supports_new_interface: bool = ERC165Contract::supports_interface(OTHER_ID);
    assert(supports_new_interface, 'Should support new interface');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('Invalid id', ))]
fn test_register_invalid_interface() {
    ERC165Contract::register_interface(INVALID_ID);
}
