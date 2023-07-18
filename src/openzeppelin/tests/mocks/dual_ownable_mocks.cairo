use openzeppelin::access::ownable::Ownable;
use openzeppelin::access::ownable::OwnableCamel;
use openzeppelin::access::ownable::interface::IOwnable;
use openzeppelin::access::ownable::interface::IOwnableCamel;

#[starknet::contract]
mod SnakeOwnableMock {
    use starknet::ContractAddress;
    use super::Ownable;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(self: @ContractState, owner: ContractAddress) {
        let mut unsafe_state = Ownable::unsafe_new_contract_state();
        Ownable::StorageTrait::initializer(ref unsafe_state, owner);
    }

    #[external(v0)]
    impl OwnableImpl of super::IOwnable<ContractState> {
        fn owner(self: @ContractState) -> ContractAddress {
            let mut unsafe_state = Ownable::unsafe_new_contract_state();
            Ownable::IOwnableImpl::owner(@unsafe_state)
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            let mut unsafe_state = Ownable::unsafe_new_contract_state();
            Ownable::IOwnableImpl::transfer_ownership(ref unsafe_state, new_owner);
        }

        fn renounce_ownership(ref self: ContractState) {
            let mut unsafe_state = Ownable::unsafe_new_contract_state();
            Ownable::IOwnableImpl::renounce_ownership(ref unsafe_state);
        }
    }
}

#[starknet::contract]
mod CamelOwnableMock {
    use starknet::ContractAddress;
    use super::OwnableCamel;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(self: @ContractState, owner: ContractAddress) {
        let mut unsafe_state = OwnableCamel::unsafe_new_contract_state();
        OwnableCamel::StorageTrait::initializer(ref unsafe_state, owner);
    }

    #[external(v0)]
    impl OwnableCamelImpl of super::IOwnableCamel<ContractState> {
        fn owner(self: @ContractState) -> ContractAddress {
            let mut unsafe_state = OwnableCamel::unsafe_new_contract_state();
            OwnableCamel::IOwnableCamelImpl::owner(@unsafe_state)
        }

        fn transferOwnership(ref self: ContractState, newOwner: ContractAddress) {
            let mut unsafe_state = OwnableCamel::unsafe_new_contract_state();
            OwnableCamel::IOwnableCamelImpl::transferOwnership(ref unsafe_state, newOwner);
        }

        fn renounceOwnership(ref self: ContractState) {
            let mut unsafe_state = OwnableCamel::unsafe_new_contract_state();
            OwnableCamel::IOwnableCamelImpl::renounceOwnership(ref unsafe_state);
        }
    }
}

#[starknet::contract]
mod SnakeOwnablePanicMock {
    use starknet::ContractAddress;
    use zeroable::Zeroable;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl OwnableImpl of super::IOwnable<ContractState> {
        fn owner(self: @ContractState) -> ContractAddress {
            panic_with_felt252('Some error');
            Zeroable::zero()
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            panic_with_felt252('Some error');
        }

        fn renounce_ownership(ref self: ContractState) {
            panic_with_felt252('Some error');
        }
    }
}

#[starknet::contract]
mod CamelOwnablePanicMock {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl OwnableCamelImpl of super::IOwnableCamel<ContractState> {
        fn owner(self: @ContractState) -> ContractAddress {
            panic_with_felt252('Some error');
            Zeroable::zero()
        }

        fn transferOwnership(ref self: ContractState, newOwner: ContractAddress) {
            panic_with_felt252('Some error');
        }

        fn renounceOwnership(ref self: ContractState) {
            panic_with_felt252('Some error');
        }
    }
}
