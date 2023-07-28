use openzeppelin::security::initializable::Initializable::InternalImpl;
use openzeppelin::security::initializable::Initializable;

fn STATE() -> Initializable::ContractState {
    Initializable::contract_state_for_testing()
}

#[test]
#[available_gas(2000000)]
fn test_initialize() {
    let mut state = STATE();
    assert(!InternalImpl::is_initialized(@state), 'Should not be initialized');
    InternalImpl::initialize(ref state);
    assert(InternalImpl::is_initialized(@state), 'Should be initialized');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Initializable: is initialized', ))]
fn test_initialize_when_initialized() {
    let mut state = STATE();
    InternalImpl::initialize(ref state);
    InternalImpl::initialize(ref state);
}
