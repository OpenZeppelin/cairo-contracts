#[abi]
trait IReentrancyGuard {
  fn callback();
}

#[contract]
mod ReentrancyAttackerMock {
    use super::IReentrancyGuard;
    use super::IReentrancyGuardDispatcher;
    use super::IReentrancyGuardDispatcherTrait;

    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[external]
    fn call_sender() {
        let caller: ContractAddress = get_caller_address();
        IReentrancyGuardDispatcher{ contract_address: caller }.callback();
    }
}
