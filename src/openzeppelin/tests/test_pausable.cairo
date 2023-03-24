use openzeppelin::security::pausable::Pausable;
use openzeppelin::mocks::mock_pausable::MockPausable;

//
// Library
//

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

//
// Mock Pausable
//

#[test]
#[available_gas(2000000)]
fn test_mock_pause_when_unpaused() {
    assert(MockPausable::is_paused() == false, 'Should not be paused');
    assert(MockPausable::get_count() == 0, 'Should be 0');
    MockPausable::assert_unpaused_and_increment();
    assert(MockPausable::get_count() == 1, 'Should increment');
    MockPausable::pause();
    assert(MockPausable::is_paused() == true, 'Should be paused');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('Pausable: paused', ))]
fn test_mock_pause_when_paused() {
    MockPausable::pause();
    MockPausable::pause();
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('Pausable: paused', ))]
fn test_mock_pause_assertion() {
    MockPausable::pause();
    MockPausable::assert_unpaused_and_increment();
}

#[test]
#[available_gas(2000000)]
fn test_mock_unpause_when_paused() {
    MockPausable::pause();
    assert(MockPausable::is_paused() == true, 'Should be paused');
    MockPausable::unpause();
    MockPausable::assert_unpaused_and_increment();
    assert(MockPausable::get_count() == 1, 'Should increment');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected = ('Pausable: not paused', ))]
fn test_mock_unpause_when_unpaused() {
    assert(MockPausable::is_paused() == false, 'Should be unpaused');
    MockPausable::unpause();
}
