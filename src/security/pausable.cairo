#[starknet::interface]
trait IPausable<TState> {
    fn is_paused(self: @TState) -> bool;
}

#[starknet::contract]
mod Pausable {
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        paused: bool
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Paused: Paused,
        Unpaused: Unpaused,
    }
    #[derive(Drop, starknet::Event)]
    struct Paused {
        account: ContractAddress
    }
    #[derive(Drop, starknet::Event)]
    struct Unpaused {
        account: ContractAddress
    }

    #[external(v0)]
    impl PausableImpl of super::IPausable<ContractState> {
        fn is_paused(self: @ContractState) -> bool {
            self.paused.read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_not_paused(self: @ContractState) {
            assert(!self.paused.read(), 'Pausable: paused');
        }

        fn assert_paused(self: @ContractState) {
            assert(self.paused.read(), 'Pausable: not paused');
        }

        fn _pause(ref self: ContractState) {
            self.assert_not_paused();
            self.paused.write(true);
            self.emit(Paused { account: get_caller_address() });
        }

        fn _unpause(ref self: ContractState) {
            self.assert_paused();
            self.paused.write(false);
            self.emit(Unpaused { account: get_caller_address() });
        }
    }
}
