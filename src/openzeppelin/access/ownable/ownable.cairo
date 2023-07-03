#[contract]
mod Ownable {
    use openzeppelin::access::ownable::interface;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use zeroable::Zeroable;

    struct Storage {
        _owner: ContractAddress
    }

    #[event]
    fn OwnershipTransferred(previous_owner: ContractAddress, new_owner: ContractAddress) {}

    impl OwnableImpl of interface::IOwnable {
        fn owner() -> ContractAddress {
            _owner::read()
        }

        fn transfer_ownership(new_owner: ContractAddress) {
            assert(!new_owner.is_zero(), 'New owner is the zero address');
            assert_only_owner();
            _transfer_ownership(new_owner);
        }

        fn renounce_ownership() {
            assert_only_owner();
            _transfer_ownership(Zeroable::zero());
        }
    }

    impl OwnableCamelImpl of interface::IOwnableCamel {
        fn owner() -> ContractAddress {
            OwnableImpl::owner()
        }

        fn transferOwnership(newOwner: ContractAddress) {
            OwnableImpl::transfer_ownership(newOwner);
        }

        fn renounceOwnership() {
            OwnableImpl::renounce_ownership();
        }
    }

    #[view]
    fn owner() -> ContractAddress {
        OwnableImpl::owner()
    }

    #[external]
    fn transfer_ownership(new_owner: ContractAddress) {
        OwnableImpl::transfer_ownership(new_owner);
    }

    #[external]
    fn transferOwnership(newOwner: ContractAddress) {
        OwnableCamelImpl::transferOwnership(newOwner);
    }

    #[external]
    fn renounce_ownership() {
        OwnableImpl::renounce_ownership();
    }

    #[external]
    fn renounceOwnership() {
        OwnableCamelImpl::renounceOwnership();
    }

    // Internals

    #[internal]
    fn initializer() {
        let caller: ContractAddress = get_caller_address();
        _transfer_ownership(caller);
    }

    #[internal]
    fn assert_only_owner() {
        let owner: ContractAddress = _owner::read();
        let caller: ContractAddress = get_caller_address();
        assert(!caller.is_zero(), 'Caller is the zero address');
        assert(caller == owner, 'Caller is not the owner');
    }

    #[internal]
    fn _transfer_ownership(new_owner: ContractAddress) {
        let previous_owner: ContractAddress = _owner::read();
        _owner::write(new_owner);
        OwnershipTransferred(previous_owner, new_owner);
    }
}
