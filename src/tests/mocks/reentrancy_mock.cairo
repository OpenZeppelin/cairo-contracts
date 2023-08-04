use starknet::ContractAddress;

#[starknet::interface]
trait IReentrancyGuarded<TState> {
    fn count_external_recursive(ref self: TState, n: felt252);
}

#[starknet::interface]
trait IReentrancyMock<TState> {
    fn current_count(self: @TState) -> felt252;
    fn callback(ref self: TState);
    fn count_local_recursive(ref self: TState, n: felt252);
    fn count_external_recursive(ref self: TState, n: felt252);
    fn count_and_call(ref self: TState, attacker: ContractAddress);
}

#[starknet::contract]
mod ReentrancyMock {
    use starknet::ContractAddress;
    use starknet::get_contract_address;
    use openzeppelin::security::reentrancyguard::ReentrancyGuard;
    use openzeppelin::tests::mocks::reentrancy_attacker_mock::IAttackerDispatcher;
    use openzeppelin::tests::mocks::reentrancy_attacker_mock::IAttackerDispatcherTrait;
    use super::IReentrancyGuardedDispatcher;
    use super::IReentrancyGuardedDispatcherTrait;

    #[storage]
    struct Storage {
        counter: felt252
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn count(ref self: ContractState) {
            self.counter.write(self.counter.read() + 1);
        }

        fn _count_local_recursive(ref self: ContractState, n: felt252) {
            let mut unsafe_state = ReentrancyGuard::unsafe_new_contract_state();
            ReentrancyGuard::InternalImpl::start(ref unsafe_state);

            if n != 0 {
                self.count();
                self._count_local_recursive(n - 1);
            }

            ReentrancyGuard::InternalImpl::end(ref unsafe_state);
        }
    }

    #[external(v0)]
    impl IReentrancyMockImpl of super::IReentrancyMock<ContractState> {
        fn current_count(self: @ContractState) -> felt252 {
            self.counter.read()
        }

        fn callback(ref self: ContractState) {
            let mut unsafe_state = ReentrancyGuard::unsafe_new_contract_state();
            ReentrancyGuard::InternalImpl::start(ref unsafe_state);
            self.count();
            ReentrancyGuard::InternalImpl::end(ref unsafe_state);
        }

        fn count_local_recursive(ref self: ContractState, n: felt252) {
            self._count_local_recursive(n);
        }

        fn count_external_recursive(ref self: ContractState, n: felt252) {
            let mut unsafe_state = ReentrancyGuard::unsafe_new_contract_state();
            ReentrancyGuard::InternalImpl::start(ref unsafe_state);

            if n != 0 {
                self.count();
                let this: ContractAddress = get_contract_address();
                IReentrancyGuardedDispatcher {
                    contract_address: this
                }.count_external_recursive(n - 1)
            }

            ReentrancyGuard::InternalImpl::end(ref unsafe_state);
        }

        fn count_and_call(ref self: ContractState, attacker: ContractAddress) {
            let mut unsafe_state = ReentrancyGuard::unsafe_new_contract_state();
            ReentrancyGuard::InternalImpl::start(ref unsafe_state);

            self.count();
            IAttackerDispatcher { contract_address: attacker }.call_sender();

            ReentrancyGuard::InternalImpl::end(ref unsafe_state);
        }
    }
}
