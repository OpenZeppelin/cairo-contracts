#[starknet::contract]
pub mod MultisigWalletMock {
    use openzeppelin_governance::multisig::MultisigComponent;
    use starknet::ContractAddress;

    component!(path: MultisigComponent, storage: multisig, event: MultisigEvent);

    #[abi(embed_v0)]
    impl MultisigImpl = MultisigComponent::MultisigImpl<ContractState>;
    impl InternalImpl = MultisigComponent::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub multisig: MultisigComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        MultisigEvent: MultisigComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, quorum: u32, signers: Span<ContractAddress>) {
        self.multisig.initializer(quorum, signers);
    }
}

#[starknet::interface]
pub trait IMultisigTargetMock<TState> {
    fn add_number(ref self: TState, number: felt252);
    fn get_current_sum(self: @TState) -> felt252;
    fn failing_function(self: @TState);
}

#[starknet::contract]
pub mod MultisigTargetMock {
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    pub struct Storage {
        pub total_sum: felt252,
    }

    #[abi(embed_v0)]
    impl MockContractImpl of super::IMultisigTargetMock<ContractState> {
        fn add_number(ref self: ContractState, number: felt252) {
            self.total_sum.write(self.total_sum.read() + number);
        }

        fn get_current_sum(self: @ContractState) -> felt252 {
            self.total_sum.read()
        }

        fn failing_function(self: @ContractState) {
            core::panic_with_const_felt252::<'Expected failure'>();
        }
    }
}
