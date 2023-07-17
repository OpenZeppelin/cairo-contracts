use starknet::ContractAddress;

#[starknet::interface]
trait IReentrancyGuarded<TContractState> {
    fn count_external_recursive(ref self: TContractState, n: felt252);
}

#[starknet::interface]
trait IReentrancyMock<TContractState> {
    fn current_count(self: @TContractState) -> felt252;
    fn callback(ref self: TContractState);
    fn count_local_recursive(ref self: TContractState, n: felt252);
    fn count_external_recursive(ref self: TContractState, n: felt252);
    fn count_and_call(ref self: TContractState, attacker: ContractAddress);
}

#[starknet::contract]
mod ReentrancyMock {
    use openzeppelin::security::reentrancyguard::ReentrancyGuard;
    use openzeppelin::tests::mocks::reentrancy_attacker_mock::IAttackerDispatcher;
    use openzeppelin::tests::mocks::reentrancy_attacker_mock::IAttackerDispatcherTrait;
    use starknet::ContractAddress;
    use starknet::get_contract_address;
    use super::IReentrancyGuardedDispatcher;
    use super::IReentrancyGuardedDispatcherTrait;

    #[storage]
    struct Storage {
        counter: felt252
    }

    #[generate_trait]
    impl StorageImpl of StorageTrait {
        fn count(ref self: ContractState) {
            self.counter.write(self.counter.read() + 1);
        }

        fn _count_local_recursive(ref self: ContractState, n: felt252) {
            let mut lib_state = ReentrancyGuard::unsafe_new_contract_state();
            ReentrancyGuard::StorageTrait::start(ref lib_state);

            if n != 0 {
                self.count();
                self._count_local_recursive(n - 1);
            }

            ReentrancyGuard::StorageTrait::end(ref lib_state);
        }
    }

    #[external(v0)]
    impl IReentrancyMockImpl of super::IReentrancyMock<ContractState> {
        fn current_count(self: @ContractState) -> felt252 {
            self.counter.read()
        }

        fn callback(ref self: ContractState) {
            let mut lib_state = ReentrancyGuard::unsafe_new_contract_state();
            ReentrancyGuard::StorageTrait::start(ref lib_state);
            self.count();
            ReentrancyGuard::StorageTrait::end(ref lib_state);
        }

        fn count_local_recursive(ref self: ContractState, n: felt252) {
            self._count_local_recursive(n);
        }

        fn count_external_recursive(ref self: ContractState, n: felt252) {
            let mut lib_state = ReentrancyGuard::unsafe_new_contract_state();
            ReentrancyGuard::StorageTrait::start(ref lib_state);

            if n != 0 {
                self.count();
                let this: ContractAddress = get_contract_address();
                IReentrancyGuardedDispatcher { contract_address: this }
                    .count_external_recursive(n - 1)
            }

            ReentrancyGuard::StorageTrait::end(ref lib_state);
        }

        fn count_and_call(ref self: ContractState, attacker: ContractAddress) {
            let mut lib_state = ReentrancyGuard::unsafe_new_contract_state();
            ReentrancyGuard::StorageTrait::start(ref lib_state);

            self.count();
            IAttackerDispatcher { contract_address: attacker }.call_sender();

            ReentrancyGuard::StorageTrait::end(ref lib_state);
        }
    }
}
