#[starknet::contract]
pub mod NoncesMock {
    use openzeppelin_utils::cryptography::nonces::NoncesComponent;

    component!(path: NoncesComponent, storage: nonces, event: NoncesEvent);

    #[abi(embed_v0)]
    impl NoncesImpl = NoncesComponent::NoncesImpl<ContractState>;
    impl InternalImpl = NoncesComponent::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub nonces: NoncesComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        NoncesEvent: NoncesComponent::Event,
    }
}
