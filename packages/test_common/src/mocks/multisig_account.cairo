#[starknet::contract(account)]
pub mod MultisigAccountMock {
    use openzeppelin_account::MultisigAccountComponent;
    use openzeppelin_introspection::src5::SRC5Component;

    component!(
        path: MultisigAccountComponent, storage: multisig_account, event: MultisigAccountEvent,
    );
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl MultisigAccountMixinImpl =
        MultisigAccountComponent::MultisigAccountMixinImpl<ContractState>;
    impl MultisigAccountInternalImpl = MultisigAccountComponent::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub multisig_account: MultisigAccountComponent::Storage,
        #[substorage(v0)]
        pub src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        MultisigAccountEvent: MultisigAccountComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, quorum: u32, signers: Span<felt252>) {
        self.multisig_account.initializer(quorum, signers);
    }
}

#[starknet::interface]
pub trait ISignatureCallerMock<TState> {
    fn call_is_valid_signature(
        self: @TState, account: starknet::ContractAddress, hash: felt252, signature: Array<felt252>,
    ) -> felt252;
}

#[starknet::contract]
pub mod SignatureCallerMock {
    use openzeppelin_interfaces::accounts::{ISRC6Dispatcher, ISRC6DispatcherTrait};
    use starknet::ContractAddress;

    #[storage]
    pub struct Storage {}

    #[abi(embed_v0)]
    impl SignatureCallerMockImpl of super::ISignatureCallerMock<ContractState> {
        fn call_is_valid_signature(
            self: @ContractState,
            account: ContractAddress,
            hash: felt252,
            signature: Array<felt252>,
        ) -> felt252 {
            ISRC6Dispatcher { contract_address: account }.is_valid_signature(hash, signature)
        }
    }
}
