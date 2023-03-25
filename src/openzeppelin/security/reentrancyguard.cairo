#[contract]
mod ReentrancyGuard {
    use starknet::get_caller_address;

    struct Storage {
        _entered: bool,
    }

    fn start() {
        assert(!_entered::read(), 'ReentrancyGuard: reentrant call');
        _entered::write(true);
    }

    fn end() {
        _entered::write(false);
    }
}
