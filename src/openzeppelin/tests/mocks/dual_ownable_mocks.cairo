#[contract]
mod SnakeOwnableMock {
    use starknet::ContractAddress;
    use openzeppelin::access::ownable::Ownable;

    #[constructor]
    fn constructor() {
        Ownable::initializer();
    }

    #[view]
    fn owner() -> ContractAddress {
        Ownable::owner()
    }

    #[external]
    fn transfer_ownership(new_owner: ContractAddress) {
        Ownable::transfer_ownership(new_owner);
    }

    #[external]
    fn renounce_ownership() {
        Ownable::renounce_ownership();
    }
}

#[contract]
mod CamelOwnableMock {
    use starknet::ContractAddress;
    use openzeppelin::access::ownable::Ownable;

    #[constructor]
    fn constructor() {
        Ownable::initializer();
    }

    #[view]
    fn owner() -> ContractAddress {
        Ownable::owner()
    }

    #[external]
    fn transferOwnership(newOwner: ContractAddress) {
        Ownable::transferOwnership(newOwner);
    }

    #[external]
    fn renounceOwnership() {
        Ownable::renounceOwnership();
    }
}

#[contract]
mod SnakeOwnablePanicMock {
    use starknet::ContractAddress;

    #[view]
    fn owner() -> ContractAddress {
        panic_with_felt252('Some error');
        Zeroable::zero()
    }

    #[external]
    fn transfer_ownership(new_owner: ContractAddress) {
        panic_with_felt252('Some error');
    }

    #[external]
    fn renounce_ownership() {
        panic_with_felt252('Some error');
    }
}

#[contract]
mod CamelOwnablePanicMock {
    use starknet::ContractAddress;

    #[view]
    fn owner() -> ContractAddress {
        panic_with_felt252('Some error');
        Zeroable::zero()
    }

    #[external]
    fn transfer_ownership(new_owner: ContractAddress) {
        panic_with_felt252('Some error');
    }

    #[external]
    fn renounce_ownership() {
        panic_with_felt252('Some error');
    }
}
