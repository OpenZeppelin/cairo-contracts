#[starknet::contract]
mod ReentrancyGuard {
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        entered: bool
    }

    #[generate_trait]
    impl StorageImpl of StorageTrait {
        fn start(ref self: ContractState) {
            assert(!self.is_entered(), 'ReentrancyGuard: reentrant call');
            self.entered.write(true);
        }

        fn end(ref self: ContractState) {
            self.entered.write(false);
        }

        fn is_entered(self: @ContractState) -> bool {
            self.entered.read()
        }
    }
}
