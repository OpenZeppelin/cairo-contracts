#[contract]
mod Initializable {
    struct Storage {
        initialized: bool,
    }

    fn is_initialized() -> bool {
        _initialized::read()
    }

    fn initialize() {
        assert(!is_initialized(), 'Contract already initialized');
        _initialized::write(true);
    }
}
