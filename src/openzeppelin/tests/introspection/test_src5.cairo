use openzeppelin::introspection::src5::SRC5;
use openzeppelin::introspection::src5::SRC5::SRC5Impl;
use openzeppelin::introspection::src5::SRC5::InternalImpl;
use openzeppelin::introspection::interface::ISRC5_ID;

const OTHER_ID: felt252 = 0x12345678;

fn STATE() -> SRC5::ContractState {
    SRC5::contract_state_for_testing()
}

#[test]
#[available_gas(2000000)]
fn test_default_behavior() {
    let supports_default_interface = SRC5Impl::supports_interface(@STATE(), ISRC5_ID);
    assert(supports_default_interface, 'Should support base interface');
}

#[test]
#[available_gas(2000000)]
fn test_not_registered_interface() {
    let supports_unregistered_interface = SRC5Impl::supports_interface(@STATE(), OTHER_ID);
    assert(!supports_unregistered_interface, 'Should not support unregistered');
}

#[test]
#[available_gas(2000000)]
fn test_register_interface() {
    let mut state = STATE();
    InternalImpl::register_interface(ref state, OTHER_ID);
    let supports_new_interface = SRC5Impl::supports_interface(@state, OTHER_ID);
    assert(supports_new_interface, 'Should support new interface');
}

#[test]
#[available_gas(2000000)]
fn test_deregister_interface() {
    let mut state = STATE();
    InternalImpl::register_interface(ref state, OTHER_ID);
    InternalImpl::deregister_interface(ref state, OTHER_ID);
    let supports_old_interface = SRC5Impl::supports_interface(@state, OTHER_ID);
    assert(!supports_old_interface, 'Should not support interface');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('SRC5: invalid id', ))]
fn test_deregister_default_interface() {
    let mut state = STATE();
    InternalImpl::deregister_interface(ref state, ISRC5_ID);
}
