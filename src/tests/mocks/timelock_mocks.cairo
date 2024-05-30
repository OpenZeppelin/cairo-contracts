#[starknet::contract]
mod TimelockControllerMock {
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

    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[abi(embed_v0)]
    impl TimelockImpl = TimelockControllerComponent::TimelockImpl<ContractState>;
    impl TimelockInternalImpl = TimelockControllerComponent::InternalImpl<ContractState>;

    // ERC721Receiver
    impl ERC721ReceiverImpl = ERC721ReceiverComponent::ERC721ReceiverImpl<ContractState>;
    impl ERC721ReceiverInternalImpl = ERC721ReceiverComponent::InternalImpl<ContractState>;

    // ERC1155Receiver
    impl ERC1155ReceiverImpl = ERC1155ReceiverComponent::ERC1155ReceiverImpl<ContractState>;
    impl ERC1155ReceiverInternalImpl = ERC1155ReceiverComponent::InternalImpl<ContractState>;

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
trait ITimelockAttacker<TState> {
    fn reenter(ref self: TState);
}

#[starknet::contract]
mod TimelockAttackerMock {
    use openzeppelin::governance::timelock::interface::{
        ITimelockDispatcher, ITimelockDispatcherTrait
    };
    use openzeppelin::tests::utils::constants::SALT;
    use starknet::ContractAddress;
    use starknet::account::Call;
    use super::ITimelockAttacker;

    const PREDECESSOR: felt252 = 0;

    #[storage]
    struct Storage {
        balance: felt252,
        count: felt252
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

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
                let reentrant_call_span = array![reentrant_call].span();

                let timelock = ITimelockDispatcher { contract_address: sender };
                timelock.execute(reentrant_call_span, PREDECESSOR, SALT);
            }
        }
    }
}
