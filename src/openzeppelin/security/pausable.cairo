#[contract]
mod Pausable {
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    struct Storage {
        paused: bool
    }

    #[event]
    fn Paused(account: ContractAddress) {}

    #[event]
    fn Unpaused(account: ContractAddress) {}

    fn is_paused() -> bool {
        paused::read()
    }

    fn assert_not_paused() {
        assert(!is_paused(), 'Pausable: paused');
    }

    fn assert_paused() {
        assert(is_paused(), 'Pausable: not paused');
    }

    fn pause() {
        assert_not_paused();
        paused::write(true);
        Paused(get_caller_address());
    }

    fn unpause() {
        assert_paused();
        paused::write(false);
        Unpaused(get_caller_address());
    }
}
