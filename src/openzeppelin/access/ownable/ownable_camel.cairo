#[starknet::contract]
mod OwnableCamel {
    use openzeppelin::access::ownable::interface;
    use openzeppelin::access::ownable::Ownable;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[generate_trait]
    impl StorageImpl of StorageTrait {
        fn initializer(ref self: ContractState, owner: ContractAddress) {
            let mut unsafe_state = Ownable::unsafe_new_contract_state();
            Ownable::StorageTrait::initializer(ref unsafe_state, owner);
        }
    }

    #[external(v0)]
    impl IOwnableCamelImpl of interface::IOwnableCamel<ContractState> {
        fn owner(self: @ContractState) -> ContractAddress {
            let mut unsafe_state = Ownable::unsafe_new_contract_state();
            Ownable::IOwnableImpl::owner(@unsafe_state)
        }

        fn transferOwnership(ref self: ContractState, newOwner: ContractAddress) {
            let mut unsafe_state = Ownable::unsafe_new_contract_state();
            Ownable::IOwnableImpl::transfer_ownership(ref unsafe_state, newOwner);
        }

        fn renounceOwnership(ref self: ContractState) {
            let mut unsafe_state = Ownable::unsafe_new_contract_state();
            Ownable::IOwnableImpl::renounce_ownership(ref unsafe_state);
        }
    }
}
