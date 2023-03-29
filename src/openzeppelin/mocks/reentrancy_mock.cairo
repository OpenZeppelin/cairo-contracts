#[abi]
trait IReentrancyGuardAttacker {
  fn call_sender();
}

#[abi]
trait IReentrancyGuarded {
    fn count_this_recursive(n: felt252);
}

#[contract]
mod ReentrancyMock {
    // OZ modules
    use openzeppelin::security::reentrancyguard::ReentrancyGuard;
    use openzeppelin::utils::check_gas;

    // Dispatchers
    use super::IReentrancyGuardAttackerDispatcher;
    use super::IReentrancyGuardAttackerDispatcherTrait;
    use super::IReentrancyGuardedDispatcher;
    use super::IReentrancyGuardedDispatcherTrait;

    // Other
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_contract_address;

    struct Storage {
        _counter: felt252
    }

    #[view]
    fn current_count() -> felt252 {
        _counter::read()
    }

    #[external]
    fn callback() {
        ReentrancyGuard::start();
        count();
        ReentrancyGuard::end();
    }

    #[external]
    fn count_local_recursive(n: felt252) {
        ReentrancyGuard::start();
        check_gas();
        if n != 0 {
            count();
            count_local_recursive(n - 1);
        }
        ReentrancyGuard::end();
    }

    #[external]
    fn count_this_recursive(n: felt252) {
        ReentrancyGuard::start();
        check_gas();
        if n != 0 {
            count();
            let caller: ContractAddress = get_contract_address();
            IReentrancyGuardedDispatcher{ contract_address: caller }.count_this_recursive(n - 1)
        }
        ReentrancyGuard::end();
    }

    #[external]
    fn count_and_call(attacker: ContractAddress) {
        ReentrancyGuard::start();
        check_gas();
        count();
        IReentrancyGuardAttackerDispatcher{ contract_address: attacker }.call_sender();
        ReentrancyGuard::end();
    }

    #[external]
    fn count() {
        _counter::write(_counter::read() + 1);
    }
}
