use openzeppelin::access::ownable::Ownable;

#[starknet::contract]
mod SnakeOwnableMock {
    use starknet::ContractAddress;
    use super::Ownable;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(self: @ContractState, owner: ContractAddress) {
        let mut unsafe_state = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::initializer(ref unsafe_state, owner);
    }

    #[external(v0)]
    fn owner(self: @ContractState) -> ContractAddress {
        let unsafe_state = Ownable::unsafe_new_contract_state();
        Ownable::OwnableImpl::owner(@unsafe_state)
    }

    #[external(v0)]
    fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
        let mut unsafe_state = Ownable::unsafe_new_contract_state();
        Ownable::OwnableImpl::transfer_ownership(ref unsafe_state, new_owner);
    }

    #[external(v0)]
    fn renounce_ownership(ref self: ContractState) {
        let mut unsafe_state = Ownable::unsafe_new_contract_state();
        Ownable::OwnableImpl::renounce_ownership(ref unsafe_state);
    }
}

#[starknet::contract]
mod CamelOwnableMock {
    use starknet::ContractAddress;
    use super::Ownable;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(self: @ContractState, owner: ContractAddress) {
        let mut unsafe_state = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::initializer(ref unsafe_state, owner);
    }

    #[external(v0)]
    fn owner(self: @ContractState) -> ContractAddress {
        let unsafe_state = Ownable::unsafe_new_contract_state();
        Ownable::OwnableImpl::owner(@unsafe_state)
    }

    #[external(v0)]
    fn transferOwnership(ref self: ContractState, newOwner: ContractAddress) {
        let mut unsafe_state = Ownable::unsafe_new_contract_state();
        Ownable::OwnableCamelOnlyImpl::transferOwnership(ref unsafe_state, newOwner);
    }

    #[external(v0)]
    fn renounceOwnership(ref self: ContractState) {
        let mut unsafe_state = Ownable::unsafe_new_contract_state();
        Ownable::OwnableCamelOnlyImpl::renounceOwnership(ref unsafe_state);
    }
}

#[starknet::contract]
mod SnakeOwnablePanicMock {
    use starknet::ContractAddress;
    use zeroable::Zeroable;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn owner(self: @ContractState) -> ContractAddress {
        panic_with_felt252('Some error');
        Zeroable::zero()
    }

    #[external(v0)]
    fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn renounce_ownership(ref self: ContractState) {
        panic_with_felt252('Some error');
    }
}

#[starknet::contract]
mod CamelOwnablePanicMock {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn owner(self: @ContractState) -> ContractAddress {
        panic_with_felt252('Some error');
        Zeroable::zero()
    }

    #[external(v0)]
    fn transferOwnership(ref self: ContractState, newOwner: ContractAddress) {
        panic_with_felt252('Some error');
    }

    #[external(v0)]
    fn renounceOwnership(ref self: ContractState) {
        panic_with_felt252('Some error');
    }
}
