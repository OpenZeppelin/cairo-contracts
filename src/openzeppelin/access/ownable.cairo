#[contract]
mod Ownable {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use zeroable::Zeroable;

    struct Storage {
        _owner: ContractAddress
    }

    #[event]
    fn OwnershipTransferred(previous_owner: ContractAddress, new_owner: ContractAddress) {}

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
    fn owner() -> ContractAddress {
        _owner::read()
    }

    #[internal]
    fn transfer_ownership(new_owner: ContractAddress) {
        assert(!new_owner.is_zero(), 'New owner is the zero address');
        assert_only_owner();
        _transfer_ownership(new_owner);
    }

    #[internal]
    fn renounce_ownership() {
        assert_only_owner();
        _transfer_ownership(Zeroable::zero());
    }

    #[internal]
    fn _transfer_ownership(new_owner: ContractAddress) {
        let previous_owner: ContractAddress = _owner::read();
        _owner::write(new_owner);
        OwnershipTransferred(previous_owner, new_owner);
    }
}
