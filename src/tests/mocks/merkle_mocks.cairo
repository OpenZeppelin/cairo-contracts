#[starknet::contract]
mod MerkleMock {
    use openzeppelin::utils::cryptography::merkle::MerkleComponent;

    component!(path: MerkleComponent, storage: merkle, event: MerkleEvent);

    #[abi(embed_v0)]
    impl MerkleImpl = MerkleComponent::MerkleImpl<ContractState>;
    impl InternalImpl = MerkleComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        merkle: MerkleComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        MerkleEvent: MerkleComponent::Event
    }
}
