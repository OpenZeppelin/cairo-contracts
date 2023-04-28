#[abi]
trait IReentrancyGuardAttacker {
    fn call_sender();
}

#[abi]
trait IReentrancyGuarded {
    fn count_external_recursive(n: felt252);
}

#[contract]
mod ReentrancyMock {
    // OZ modules
    use openzeppelin::security::reentrancyguard::ReentrancyGuard;

    // Dispatchers
    use super::IReentrancyGuardAttackerDispatcher;
    use super::IReentrancyGuardAttackerDispatcherTrait;
    use super::IReentrancyGuardedDispatcher;
    use super::IReentrancyGuardedDispatcherTrait;

    // Other
    use option::OptionTrait;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_contract_address;

    struct Storage {
        counter: felt252
    }

    #[view]
    fn current_count() -> felt252 {
        counter::read()
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
        gas::withdraw_gas().expect('Out of gas');
        if n != 0 {
            count();
            count_local_recursive(n - 1);
        }
        ReentrancyGuard::end();
    }

    #[external]
    fn count_external_recursive(n: felt252) {
        ReentrancyGuard::start();
        gas::withdraw_gas().expect('Out of gas');
        if n != 0 {
            count();
            let caller: ContractAddress = get_contract_address();
            IReentrancyGuardedDispatcher {
                contract_address: caller
            }.count_external_recursive(n - 1)
        }
        ReentrancyGuard::end();
    }

    #[external]
    fn count_and_call(attacker: ContractAddress) {
        ReentrancyGuard::start();
        gas::withdraw_gas().expect('Out of gas');
        count();
        IReentrancyGuardAttackerDispatcher { contract_address: attacker }.call_sender();
        ReentrancyGuard::end();
    }

    #[external]
    fn count() {
        counter::write(counter::read() + 1);
    }
}
