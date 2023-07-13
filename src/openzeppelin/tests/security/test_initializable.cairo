use array::ArrayTrait;
use openzeppelin::security::initializable::Initializable;
use openzeppelin::security::initializable::Initializable::StorageTrait;

fn internal_state() -> Initializable::ContractState {
    Initializable::contract_state_for_testing()
}

#[test]
#[available_gas(2000000)]
fn test_initialize() {
    let mut contract = internal_state();
    assert(!contract.is_initialized(), 'Should not be initialized');
    contract.initialize();
    assert(contract.is_initialized(), 'Should be initialized');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Initializable: is initialized', ))]
fn test_initialize_when_initialized() {
    let mut contract = internal_state();
    contract.initialize();
    contract.initialize();
}
