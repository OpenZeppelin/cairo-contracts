#[starknet::contract]
mod NoncesMock {
    use openzeppelin::utils::cryptography::nonces::NoncesComponent;

    component!(path: NoncesComponent, storage: nonces, event: NoncesEvent);

    #[abi(embed_v0)]
    impl NoncesImpl = NoncesComponent::NoncesImpl<ContractState>;
    impl InternalImpl = NoncesComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        nonces: NoncesComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        NoncesEvent: NoncesComponent::Event
    }
}
