#[abi]
trait IAttacker {
    fn call_sender();
}

#[contract]
mod Attacker {
    // Dispatcher
    use openzeppelin::tests::mocks::reentrancy_mock::IReentrancyMockDispatcher;
    use openzeppelin::tests::mocks::reentrancy_mock::IReentrancyMockDispatcherTrait;

    // Other
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[external]
    fn call_sender() {
        let caller: ContractAddress = get_caller_address();
        IReentrancyMockDispatcher { contract_address: caller }.callback();
    }
}
