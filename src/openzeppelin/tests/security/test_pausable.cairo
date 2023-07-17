use openzeppelin::security::pausable::Pausable;

fn STATE() -> Pausable::ContractState {
    Pausable::contract_state_for_testing()
}

//
// is_paused
//

#[test]
#[available_gas(2000000)]
fn test_is_paused() {
    let mut state = STATE();
    assert(!Pausable::StorageTrait::is_paused(@state), 'Should not be paused');

    Pausable::StorageTrait::pause(ref state);
    assert(Pausable::StorageTrait::is_paused(@state), 'Should be paused');

    Pausable::StorageTrait::unpause(ref state);
    assert(!Pausable::StorageTrait::is_paused(@state), 'Should not be paused');
}

//
// assert_paused
//

#[test]
#[available_gas(2000000)]
fn test_assert_paused_when_paused() {
    let mut state = STATE();
    Pausable::StorageTrait::pause(ref state);
    Pausable::StorageTrait::assert_paused(@state);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pausable: not paused', ))]
fn test_assert_paused_when_not_paused() {
    let mut state = STATE();
    Pausable::StorageTrait::assert_paused(@state);
}

//
// assert_not_paused
//

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pausable: paused', ))]
fn test_assert_not_paused_when_paused() {
    let mut state = STATE();
    Pausable::StorageTrait::pause(ref state);
    Pausable::StorageTrait::assert_not_paused(@state);
}

#[test]
#[available_gas(2000000)]
fn test_assert_not_paused_when_not_paused() {
    let mut state = STATE();
    Pausable::StorageTrait::assert_not_paused(@state);
}

//
// pause
//

#[test]
#[available_gas(2000000)]
fn test_pause_when_unpaused() {
    let mut state = STATE();
    Pausable::StorageTrait::pause(ref state);
    assert(Pausable::StorageTrait::is_paused(@state), 'Should be paused');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pausable: paused', ))]
fn test_pause_when_paused() {
    let mut state = STATE();
    Pausable::StorageTrait::pause(ref state);
    Pausable::StorageTrait::pause(ref state);
}

//
// unpause
//

#[test]
#[available_gas(2000000)]
fn test_unpause_when_paused() {
    let mut state = STATE();
    Pausable::StorageTrait::pause(ref state);
    Pausable::StorageTrait::unpause(ref state);
    assert(!Pausable::StorageTrait::is_paused(@state), 'Should not be paused');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pausable: not paused', ))]
fn test_unpause_when_unpaused() {
    let mut state = STATE();
    assert(!Pausable::StorageTrait::is_paused(@state), 'Should be paused');
    Pausable::StorageTrait::unpause(ref state);
}
