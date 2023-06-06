#[contract]
mod ReentrancyGuard {
    use starknet::get_caller_address;

    struct Storage {
        entered: bool
    }

    fn start() {
        assert(!entered::read(), 'ReentrancyGuard: reentrant call');
        entered::write(true);
    }

    fn end() {
        entered::write(false);
    }
}
