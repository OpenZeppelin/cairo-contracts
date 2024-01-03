use openzeppelin::introspection::interface::{ISRC5_ID, ISRC5};
use openzeppelin::introspection::src5::SRC5Component::InternalTrait;
use openzeppelin::introspection::src5::SRC5Component;
use openzeppelin::tests::mocks::src5_mocks::DualCaseSRC5Mock;

const OTHER_ID: felt252 = 0x12345678;

type ComponentState = SRC5Component::ComponentState<DualCaseSRC5Mock::ContractState>;

fn COMPONENT_STATE() -> ComponentState {
    SRC5Component::component_state_for_testing()
}

#[test]
fn test_default_behavior() {
    let state = COMPONENT_STATE();
    let supports_default_interface = state.supports_interface(ISRC5_ID);
    assert(supports_default_interface, 'Should support base interface');
}

#[test]
fn test_not_registered_interface() {
    let state = COMPONENT_STATE();
    let supports_unregistered_interface = state.supports_interface(OTHER_ID);
    assert(!supports_unregistered_interface, 'Should not support unregistered');
}

#[test]
fn test_register_interface() {
    let mut state = COMPONENT_STATE();
    state.register_interface(OTHER_ID);
    let supports_new_interface = state.supports_interface(OTHER_ID);
    assert(supports_new_interface, 'Should support new interface');
}

#[test]
fn test_deregister_interface() {
    let mut state = COMPONENT_STATE();
    state.register_interface(OTHER_ID);
    state.deregister_interface(OTHER_ID);
    let supports_old_interface = state.supports_interface(OTHER_ID);
    assert(!supports_old_interface, 'Should not support interface');
}

#[test]
#[should_panic(expected: ('SRC5: invalid id',))]
fn test_deregister_default_interface() {
    let mut state = COMPONENT_STATE();
    state.deregister_interface(ISRC5_ID);
}
