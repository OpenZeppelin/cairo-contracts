use openzeppelin::tests::mocks::mock_pausable::MockPausable;

#[test]
#[available_gas(2000000)]
fn test_pause_when_unpaused() {
    assert(!MockPausable::is_paused(), 'Should not be paused');
    assert(MockPausable::get_count() == 0, 'Should be 0');
    MockPausable::assert_unpaused_and_increment();
    assert(MockPausable::get_count() == 1, 'Should increment');
    MockPausable::pause();
    assert(MockPausable::is_paused(), 'Should be paused');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pausable: paused', ))]
fn test_pause_when_paused() {
    MockPausable::pause();
    MockPausable::pause();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pausable: paused', ))]
fn test_pause_increment() {
    MockPausable::pause();
    MockPausable::assert_unpaused_and_increment();
}

#[test]
#[available_gas(2000000)]
fn test_unpause_when_paused() {
    MockPausable::pause();
    assert(MockPausable::is_paused(), 'Should be paused');
    MockPausable::unpause();
    assert(!MockPausable::is_paused(), 'Should not be paused');
    MockPausable::assert_unpaused_and_increment();
    assert(MockPausable::get_count() == 1, 'Should increment');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pausable: not paused', ))]
fn test_unpause_when_unpaused() {
    assert(!MockPausable::is_paused(), 'Should be unpaused');
    MockPausable::unpause();
}
