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

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn is_paused(self: @ContractState) -> bool {
            self.paused.read()
        }

        fn assert_not_paused(self: @ContractState) {
            assert(!self.is_paused(), 'Pausable: paused');
        }

        fn assert_paused(self: @ContractState) {
            assert(self.is_paused(), 'Pausable: not paused');
        }

        fn pause(ref self: ContractState) {
            self.assert_not_paused();
            self.paused.write(true);
            self.emit(Event::Paused(Paused { account: get_caller_address() }));
        }

        fn unpause(ref self: ContractState) {
            self.assert_paused();
            self.paused.write(false);
            self.emit(Event::Unpaused(Unpaused { account: get_caller_address() }));
        }
    }
}
