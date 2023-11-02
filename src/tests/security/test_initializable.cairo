use openzeppelin::security::InitializableComponent::{InitializableImpl, InternalImpl};
use openzeppelin::tests::mocks::initializable_mock::InitializableMock;

fn STATE() -> InitializableMock::ContractState {
    InitializableMock::contract_state_for_testing()
}

#[test]
#[available_gas(2000000)]
fn test_initialize() {
    let mut state = STATE();
    assert(!state.initializable.is_initialized(), 'Should not be initialized');
    state.initializable.initialize();
    assert(state.initializable.is_initialized(), 'Should be initialized');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Initializable: is initialized',))]
fn test_initialize_when_initialized() {
    let mut state = STATE();
    state.initializable.initialize();
    state.initializable.initialize();
}
