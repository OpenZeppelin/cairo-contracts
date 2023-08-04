#[starknet::interface]
trait IAttacker<TState> {
    fn call_sender(self: @TState);
}

#[starknet::contract]
mod Attacker {
    use openzeppelin::tests::mocks::reentrancy_mock::IReentrancyMockDispatcher;
    use openzeppelin::tests::mocks::reentrancy_mock::IReentrancyMockDispatcherTrait;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl IAttackerImpl of super::IAttacker<ContractState> {
        fn call_sender(self: @ContractState) {
            let caller: ContractAddress = get_caller_address();
            IReentrancyMockDispatcher { contract_address: caller }.callback();
        }
    }
}
