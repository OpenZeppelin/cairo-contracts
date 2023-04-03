#[contract]
mod MockPausable {
    use openzeppelin::security::pausable::Pausable;

    struct Storage {
        counter: felt252
    }

    #[view]
    fn is_paused() -> bool {
        Pausable::is_paused()
    }

    #[view]
    fn get_count() -> felt252 {
        counter::read()
    }

    #[external]
    fn assert_unpaused_and_increment() {
        Pausable::assert_not_paused();
        counter::write(counter::read() + 1);
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
