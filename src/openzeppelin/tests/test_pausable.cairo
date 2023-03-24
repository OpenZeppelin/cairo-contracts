use openzeppelin::security::pausable::Pausable;

#[test]
#[available_gas(2000000)]
fn test_pause_when_unpaused() {
    assert(!Pausable::is_paused(),'Should not be paused');
    Pausable::pause();
    assert(Pausable::is_paused(),'Should be paused');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('Pausable: paused', ))]
fn test_pause_when_paused() {
    Pausable::pause();
    Pausable::pause();
}

#[test]
#[available_gas(2000000)]
fn test_unpause_when_paused() {
    Pausable::pause();
    assert(Pausable::is_paused(), 'Should be paused');
    Pausable::unpause();
    assert(!Pausable::is_paused(), 'Should be unpaused');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('Pausable: not paused', ))]
fn test_unpause_when_unpaused() {
    Pausable::unpause();
}
