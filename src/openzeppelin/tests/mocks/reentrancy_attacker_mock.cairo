#[abi]
trait IReentrancyGuard {
    fn callback();
}

#[contract]
mod ReentrancyAttackerMock {
    // Dispatcher
    use super::IReentrancyGuardDispatcher;
    use super::IReentrancyGuardDispatcherTrait;

    // Other
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[external]
    fn call_sender() {
        let caller: ContractAddress = get_caller_address();
        IReentrancyGuardDispatcher { contract_address: caller }.callback();
    }
}
