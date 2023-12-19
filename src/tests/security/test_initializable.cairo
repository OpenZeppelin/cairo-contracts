use openzeppelin::security::InitializableComponent::{InitializableImpl, InternalImpl};
use openzeppelin::security::InitializableComponent;
use openzeppelin::tests::mocks::initializable_mock::InitializableMock;

type ComponentState = InitializableComponent::ComponentState<InitializableMock::ContractState>;

fn COMPONENT_STATE() -> ComponentState {
    InitializableComponent::component_state_for_testing()
}

#[test]
#[available_gas(2000000)]
fn test_initialize() {
    let mut state = COMPONENT_STATE();
    assert(!state.is_initialized(), 'Should not be initialized');
    state.initialize();
    assert(state.is_initialized(), 'Should be initialized');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Initializable: is initialized',))]
fn test_initialize_when_initialized() {
    let mut state = COMPONENT_STATE();
    state.initialize();
    state.initialize();
}
