use openzeppelin::introspection::interface::{ISRC5_ID, ISRC5};
use openzeppelin::introspection::src5::SRC5Component::InternalTrait;
use openzeppelin::tests::mocks::src5_mocks::DualCaseSRC5Mock;

const OTHER_ID: felt252 = 0x12345678;

fn STATE() -> DualCaseSRC5Mock::ContractState {
    DualCaseSRC5Mock::contract_state_for_testing()
}

#[test]
#[available_gas(2000000)]
fn test_default_behavior() {
    let state = @STATE();
    let supports_default_interface = state.src5.supports_interface(ISRC5_ID);
    assert(supports_default_interface, 'Should support base interface');
}

#[test]
#[available_gas(2000000)]
fn test_not_registered_interface() {
    let state = @STATE();
    let supports_unregistered_interface = state.src5.supports_interface(OTHER_ID);
    assert(!supports_unregistered_interface, 'Should not support unregistered');
}

#[test]
#[available_gas(2000000)]
fn test_register_interface() {
    let mut state = STATE();
    state.src5.register_interface(OTHER_ID);
    let supports_new_interface = state.src5.supports_interface(OTHER_ID);
    assert(supports_new_interface, 'Should support new interface');
}

#[test]
#[available_gas(2000000)]
fn test_deregister_interface() {
    let mut state = STATE();
    state.src5.register_interface(OTHER_ID);
    state.src5.deregister_interface(OTHER_ID);
    let supports_old_interface = state.src5.supports_interface(OTHER_ID);
    assert(!supports_old_interface, 'Should not support interface');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('SRC5: invalid id',))]
fn test_deregister_default_interface() {
    let mut state = STATE();
    state.src5.deregister_interface(ISRC5_ID);
}
