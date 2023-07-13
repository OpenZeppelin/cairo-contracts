use openzeppelin::security::pausable::Pausable;
use openzeppelin::security::pausable::Pausable::StorageTrait;

fn internal_state() -> Pausable::ContractState {
    Pausable::contract_state_for_testing()
}

//
// is_paused
//

#[test]
#[available_gas(2000000)]
fn test_is_paused() {
    let mut contract = internal_state();
    assert(!contract.is_paused(), 'Should not be paused');

    contract.pause();
    assert(contract.is_paused(), 'Should be paused');

    contract.unpause();
    assert(!contract.is_paused(), 'Should not be paused');
}

//
// assert_paused
//

#[test]
#[available_gas(2000000)]
fn test_assert_paused_when_paused() {
    let mut contract = internal_state();
    contract.pause();
    contract.assert_paused();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pausable: not paused', ))]
fn test_assert_paused_when_not_paused() {
    let mut contract = internal_state();
    contract.assert_paused();
}

//
// assert_not_paused
//

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pausable: paused', ))]
fn test_assert_not_paused_when_paused() {
    let mut contract = internal_state();
    contract.pause();
    contract.assert_not_paused();
}

#[test]
#[available_gas(2000000)]
fn test_assert_not_paused_when_not_paused() {
    let mut contract = internal_state();
    contract.assert_not_paused();
}

//
// pause
//

#[test]
#[available_gas(2000000)]
fn test_pause_when_unpaused() {
    let mut contract = internal_state();
    contract.pause();
    assert(contract.is_paused(), 'Should be paused');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pausable: paused', ))]
fn test_pause_when_paused() {
    let mut contract = internal_state();
    contract.pause();
    contract.pause();
}

//
// unpause
//

#[test]
#[available_gas(2000000)]
fn test_unpause_when_paused() {
    let mut contract = internal_state();
    contract.pause();
    contract.unpause();
    assert(!contract.is_paused(), 'Should not be paused');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pausable: not paused', ))]
fn test_unpause_when_unpaused() {
    let mut contract = internal_state();
    assert(!contract.is_paused(), 'Should be paused');
    contract.unpause();
}
