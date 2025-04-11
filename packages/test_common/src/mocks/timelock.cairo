#[starknet::contract]
pub mod TimelockControllerMock {
    use openzeppelin_access::accesscontrol::AccessControlComponent;
    use openzeppelin_governance::timelock::TimelockControllerComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;

    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: TimelockControllerComponent, storage: timelock, event: TimelockEvent);

    // Timelock Mixin
    #[abi(embed_v0)]
    impl TimelockMixinImpl =
        TimelockControllerComponent::TimelockMixinImpl<ContractState>;
    impl TimelockInternalImpl = TimelockControllerComponent::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage,
        #[substorage(v0)]
        pub timelock: TimelockControllerComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        TimelockEvent: TimelockControllerComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        min_delay: u64,
        proposers: Span<ContractAddress>,
        executors: Span<ContractAddress>,
        admin: ContractAddress,
    ) {
        self.timelock.initializer(min_delay, proposers, executors, admin);
    }
}

#[starknet::interface]
pub trait IMockContract<TState> {
    fn set_number(ref self: TState, new_number: felt252);
    fn get_number(self: @TState) -> felt252;
    fn failing_function(self: @TState);
}

#[starknet::contract]
pub mod MockContract {
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::IMockContract;

    #[storage]
    pub struct Storage {
        pub number: felt252,
    }

    #[abi(embed_v0)]
    impl MockContractImpl of IMockContract<ContractState> {
        fn set_number(ref self: ContractState, new_number: felt252) {
            self.number.write(new_number);
        }

        fn get_number(self: @ContractState) -> felt252 {
            self.number.read()
        }

        fn failing_function(self: @ContractState) {
            core::panic_with_const_felt252::<'Expected failure'>();
        }
    }
}

#[starknet::interface]
pub trait ITimelockAttacker<TState> {
    fn reenter(ref self: TState);
    fn reenter_batch(ref self: TState);
}

#[starknet::contract]
pub mod TimelockAttackerMock {
    use openzeppelin_governance::timelock::interface::{
        ITimelockDispatcher, ITimelockDispatcherTrait,
    };
    use starknet::account::Call;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::ITimelockAttacker;

    const NO_PREDECESSOR: felt252 = 0;
    const NO_SALT: felt252 = 0;

    #[storage]
    pub struct Storage {
        pub balance: felt252,
        pub count: felt252,
    }

    #[abi(embed_v0)]
    impl TimelockAttackerImpl of ITimelockAttacker<ContractState> {
        fn reenter(ref self: ContractState) {
            let new_balance = self.balance.read() + 1;
            self.balance.write(new_balance);

            let sender = starknet::get_caller_address();
            let this = starknet::get_contract_address();

            let current_count = self.count.read();
            if current_count != 2 {
                self.count.write(current_count + 1);

                let reentrant_call = Call {
                    to: this, selector: selector!("reenter"), calldata: array![].span(),
                };

                let timelock = ITimelockDispatcher { contract_address: sender };
                timelock.execute(reentrant_call, NO_PREDECESSOR, NO_SALT);
            }
        }

        fn reenter_batch(ref self: ContractState) {
            let new_balance = self.balance.read() + 1;
            self.balance.write(new_balance);

            let sender = starknet::get_caller_address();
            let this = starknet::get_contract_address();

            let current_count = self.count.read();
            if current_count != 2 {
                self.count.write(current_count + 1);

                let reentrant_call = Call {
                    to: this, selector: selector!("reenter_batch"), calldata: array![].span(),
                };

                let calls = array![reentrant_call].span();

                let timelock = ITimelockDispatcher { contract_address: sender };
                timelock.execute_batch(calls, NO_PREDECESSOR, NO_SALT);
            }
        }
    }
}
