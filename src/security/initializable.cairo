#[contract]
mod Initializable {
    struct Storage {
        initialized: bool
    }

    #[internal]
    fn is_initialized() -> bool {
        initialized::read()
    }

    #[internal]
    fn initialize() {
        assert(!is_initialized(), 'Initializable: is initialized');
        initialized::write(true);
    }
}
