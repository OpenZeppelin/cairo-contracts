#[starknet::contract]
mod OwnableCamel {
    use openzeppelin::access::ownable::interface;
    use openzeppelin::access::ownable::Ownable;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl IOwnableCamelImpl of interface::IOwnableCamel<ContractState> {
        fn owner(self: @ContractState) -> ContractAddress {
            let mut UNSAFE_LIB_STATE = Ownable::unsafe_new_contract_state();
            Ownable::IOwnableImpl::owner(@UNSAFE_LIB_STATE)
        }

        fn transferOwnership(ref self: ContractState, newOwner: ContractAddress) {
            let mut UNSAFE_LIB_STATE = Ownable::unsafe_new_contract_state();
            Ownable::IOwnableImpl::transfer_ownership(ref UNSAFE_LIB_STATE, newOwner);
        }

        fn renounceOwnership(ref self: ContractState) {
            let mut UNSAFE_LIB_STATE = Ownable::unsafe_new_contract_state();
            Ownable::IOwnableImpl::renounce_ownership(ref UNSAFE_LIB_STATE);
        }
    }
}
