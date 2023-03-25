#[contract]
mod Pausable {
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    struct Storage {
        _paused: bool,
    }

    #[event]
    fn Paused(account: ContractAddress) {}

    #[event]
    fn Unpaused(account: ContractAddress) {}

    fn is_paused() -> bool {
        _paused::read()
    }

    fn assert_not_paused() {
        assert(!is_paused(), 'Pausable: paused');
    }

    fn assert_paused() {
        assert(is_paused(), 'Pausable: not paused');
    }

    fn pause() {
        assert_not_paused();
        _paused::write(true);
        Paused(get_caller_address());
    }

    fn unpause() {
        assert_paused();
        _paused::write(false);
        Unpaused(get_caller_address());
    }
}
