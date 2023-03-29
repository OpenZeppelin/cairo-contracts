#[contract]
mod MockPausable {
    use openzeppelin::security::pausable::Pausable;

    struct Storage {
        _counter: felt252
    }

    #[view]
    fn is_paused() -> bool {
        Pausable::is_paused()
    }

    #[view]
    fn get_count() -> felt252 {
        _counter::read()
    }

    #[external]
    fn assert_unpaused_and_increment() {
        Pausable::assert_not_paused();
        _counter::write(_counter::read() + 1);
    }

    #[external]
    fn pause() {
        Pausable::pause();
    }

    #[external]
    fn unpause() {
        Pausable::unpause();
    }
}
