#[contract]
mod Initializable {
    struct Storage {
        initialized: bool,
    }

    #[internal]
    fn is_initialized() -> bool {
        initialized::read()
    }

    #[internal]
    fn initialize() {
        assert(!is_initialized(), 'Contract already initialized');
        initialized::write(true);
    }
}
