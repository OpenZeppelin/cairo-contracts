#[starknet::contract]
pub(crate) mod TimelockControllerMock {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::governance::timelock::TimelockControllerComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::ERC1155ReceiverComponent;
    use openzeppelin::token::erc721::ERC721ReceiverComponent;
    use starknet::ContractAddress;

    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: TimelockControllerComponent, storage: timelock, event: TimelockEvent);
    component!(path: ERC721ReceiverComponent, storage: erc721_receiver, event: ERC721ReceiverEvent);
    component!(
        path: ERC1155ReceiverComponent, storage: erc1155_receiver, event: ERC1155ReceiverEvent
    );

    // Timelock Mixin
    #[abi(embed_v0)]
    impl TimelockMixinImpl =
        TimelockControllerComponent::TimelockMixinImpl<ContractState>;
    impl TimelockInternalImpl = TimelockControllerComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        timelock: TimelockControllerComponent::Storage,
        #[substorage(v0)]
        erc721_receiver: ERC721ReceiverComponent::Storage,
        #[substorage(v0)]
        erc1155_receiver: ERC1155ReceiverComponent::Storage,
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
        #[flat]
        ERC721ReceiverEvent: ERC721ReceiverComponent::Event,
        #[flat]
        ERC1155ReceiverEvent: ERC1155ReceiverComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        min_delay: u64,
        proposers: Span<ContractAddress>,
        executors: Span<ContractAddress>,
        admin: ContractAddress
    ) {
        self.timelock.initializer(min_delay, proposers, executors, admin);
    }
}

#[starknet::interface]
pub(crate) trait IMockContract<TState> {
    fn set_number(ref self: TState, new_number: felt252);
    fn get_number(self: @TState) -> felt252;
    fn failing_function(self: @TState);
}

#[starknet::contract]
pub(crate) mod MockContract {
    use super::IMockContract;

    #[storage]
    struct Storage {
        number: felt252,
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
            core::panic_with_felt252('Expected failure');
        }
    }
}

#[starknet::interface]
pub(crate) trait ITimelockAttacker<TState> {
    fn reenter(ref self: TState);
    fn reenter_batch(ref self: TState);
}

#[starknet::contract]
pub(crate) mod TimelockAttackerMock {
    use openzeppelin::governance::timelock::interface::{
        ITimelockDispatcher, ITimelockDispatcherTrait
    };
    use openzeppelin::governance::timelock::utils::call_impls::Call;
    use starknet::ContractAddress;
    use super::ITimelockAttacker;

    const NO_PREDECESSOR: felt252 = 0;
    const NO_SALT: felt252 = 0;

    #[storage]
    struct Storage {
        balance: felt252,
        count: felt252
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
                    to: this, selector: selector!("reenter"), calldata: array![].span()
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
                    to: this, selector: selector!("reenter_batch"), calldata: array![].span()
                };

                let calls = array![reentrant_call].span();

                let timelock = ITimelockDispatcher { contract_address: sender };
                timelock.execute_batch(calls, NO_PREDECESSOR, NO_SALT);
            }
        }
    }
}
