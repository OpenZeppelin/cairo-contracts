#[contract]
mod Initializable {
    struct Storage {
        _initialized: bool,
    }

    fn initialized() -> bool {
        _initialized::read()
    }

    fn initialize() {
        assert(!initialized(), 'Contract already initialized');
        _initialized::write(true);
    }
}
