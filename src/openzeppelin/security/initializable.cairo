#[contract]
mod Initializable {
    struct Storage {
        _initialized: bool,
    }

    fn is_initialized() -> bool {
        _initialized::read()
    }

    fn initialize() {
        assert(!is_initialized(), 'Contract already initialized');
        _initialized::write(true);
    }
}
