use openzeppelin::introspection::src5::SRC5;
use openzeppelin::introspection::src5::ISRC5_ID;

const OTHER_ID: felt252 = 0x12345678;

#[test]
#[available_gas(2000000)]
fn test_default_behavior() {
    let supports_default_interface: bool = SRC5::supports_interface(ISRC5_ID);
    assert(supports_default_interface, 'Should support base interface');
}

#[test]
#[available_gas(2000000)]
fn test_not_registered_interface() {
    let supports_unregistered_interface: bool = SRC5::supports_interface(OTHER_ID);
    assert(!supports_unregistered_interface, 'Should not support unregistered');
}

#[test]
#[available_gas(2000000)]
fn test_register_interface() {
    SRC5::register_interface(OTHER_ID);
    let supports_new_interface: bool = SRC5::supports_interface(OTHER_ID);
    assert(supports_new_interface, 'Should support new interface');
}

#[test]
#[available_gas(2000000)]
fn test_deregister_interface() {
    SRC5::register_interface(OTHER_ID);
    SRC5::deregister_interface(OTHER_ID);
    let supports_old_interface: bool = SRC5::supports_interface(OTHER_ID);
    assert(!supports_old_interface, 'Should not support interface');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('SRC5: invalid id', ))]
fn test_deregister_default_interface() {
    SRC5::deregister_interface(ISRC5_ID);
}
