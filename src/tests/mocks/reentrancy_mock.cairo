use starknet::ContractAddress;

#[starknet::interface]
trait IReentrancyGuarded<TState> {
    fn count_external_recursive(ref self: TState, n: felt252);
}

#[starknet::interface]
trait IReentrancyMock<TState> {
    fn count(ref self: TState);
    fn current_count(self: @TState) -> felt252;
    fn callback(ref self: TState);
    fn count_local_recursive(ref self: TState, n: felt252);
    fn count_external_recursive(ref self: TState, n: felt252);
    fn count_and_call(ref self: TState, attacker: ContractAddress);
}

#[starknet::contract]
mod ReentrancyMock {
    use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent;
    use openzeppelin::tests::mocks::reentrancy_attacker_mock::IAttackerDispatcher;
    use openzeppelin::tests::mocks::reentrancy_attacker_mock::IAttackerDispatcherTrait;
    use starknet::ContractAddress;
    use starknet::get_contract_address;
    use super::IReentrancyGuardedDispatcher;
    use super::IReentrancyGuardedDispatcherTrait;

    component!(
        path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent
    );

    impl InternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        counter: felt252,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event
    }

    #[external(v0)]
    impl IReentrancyMockImpl of super::IReentrancyMock<ContractState> {
        fn count(ref self: ContractState) {
            self.counter.write(self.counter.read() + 1);
        }

        fn current_count(self: @ContractState) -> felt252 {
            self.counter.read()
        }

        fn callback(ref self: ContractState) {
            self.reentrancy_guard.start();
            self.count();
            self.reentrancy_guard.end();
        }

        fn count_local_recursive(ref self: ContractState, n: felt252) {
            self.reentrancy_guard.start();

            if n != 0 {
                self.count();
                self.count_local_recursive(n - 1);
            }

            self.reentrancy_guard.end();
        }

        fn count_external_recursive(ref self: ContractState, n: felt252) {
            self.reentrancy_guard.start();

            if n != 0 {
                self.count();
                let this: ContractAddress = get_contract_address();
                IReentrancyGuardedDispatcher { contract_address: this }
                    .count_external_recursive(n - 1)
            }

            self.reentrancy_guard.end();
        }

        fn count_and_call(ref self: ContractState, attacker: ContractAddress) {
            self.reentrancy_guard.start();

            self.count();
            IAttackerDispatcher { contract_address: attacker }.call_sender();

            self.reentrancy_guard.end();
        }
    }
}
