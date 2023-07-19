#[starknet::contract]
mod OwnableCamel {
    use openzeppelin::access::ownable::interface;
    use openzeppelin::access::ownable::Ownable;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn initializer(ref self: ContractState, owner: ContractAddress) {
            let mut unsafe_state = Ownable::unsafe_new_contract_state();
            Ownable::InternalImpl::initializer(ref unsafe_state, owner);
        }
    }

    #[external(v0)]
    impl OwnableCamelImpl of interface::IOwnableCamel<ContractState> {
        fn owner(self: @ContractState) -> ContractAddress {
            let mut unsafe_state = Ownable::unsafe_new_contract_state();
            Ownable::OwnableImpl::owner(@unsafe_state)
        }

        fn transferOwnership(ref self: ContractState, newOwner: ContractAddress) {
            let mut unsafe_state = Ownable::unsafe_new_contract_state();
            Ownable::OwnableImpl::transfer_ownership(ref unsafe_state, newOwner);
        }

        fn renounceOwnership(ref self: ContractState) {
            let mut unsafe_state = Ownable::unsafe_new_contract_state();
            Ownable::OwnableImpl::renounce_ownership(ref unsafe_state);
        }
    }
}
