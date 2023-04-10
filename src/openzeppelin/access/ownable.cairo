#[contract]
mod Ownable {
    use starknet::ContractAddress;
    use starknet::ContractAddressZeroable;
    use starknet::contract_address_const;
    use starknet::get_caller_address;
    use zeroable::Zeroable;

    struct Storage {
        _owner: ContractAddress
    }

    #[event]
    fn OwnershipTransferred(previous_owner: ContractAddress, new_owner: ContractAddress) {}

    fn initializer() {
        let caller: ContractAddress = get_caller_address();
        _owner::write(caller);
    }

    fn assert_only_owner() {
        let owner: ContractAddress = _owner::read();
        let caller: ContractAddress = get_caller_address();
        assert(!caller.is_zero(), 'Caller is the zero address');
        assert(caller == owner, 'Caller is not the owner');
    }

    fn owner() -> ContractAddress {
        _owner::read()
    }

    fn transfer_ownership(new_owner: ContractAddress) {
        assert(!new_owner.is_zero(), 'New owner is zero address');
        assert_only_owner();
        _transfer_ownership(new_owner);
    }

    fn renounce_ownership() {
        assert_only_owner();
        _transfer_ownership(contract_address_const::<0>());
    }

    fn _transfer_ownership(new_owner: ContractAddress) {
        let previous_owner: ContractAddress = _owner::read();
        _owner::write(new_owner);
        OwnershipTransferred(previous_owner, new_owner);
    }
}
