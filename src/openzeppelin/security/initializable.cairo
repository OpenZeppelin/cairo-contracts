#[contract]
mod Initializable {
    struct Storage {
        initialized: bool,
    }

    fn is_initialized() -> bool {
        initialized::read()
    }

    fn initialize() {
        assert(!is_initialized(), 'Contract already initialized');
        initialized::write(true);
    }
}
