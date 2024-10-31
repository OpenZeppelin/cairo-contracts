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
        MultisigEvent: MultisigComponent::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        threshold: u32, 
        signers: Span<ContractAddress>
    ) {
        self.multisig.initializer(threshold, signers);
    }
}
