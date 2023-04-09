#[contract]
mod Upgradeable {
    use starknet::class_hash::ClassHash;
    use starknet::class_hash::ClassHashZeroable;
    use starknet::ContractAddress;
    use starknet::ContractAddressZeroable;
    use starknet::get_caller_address;
    use starknet::syscalls::replace_class_syscall;
    use zeroable::Zeroable;

    struct Storage {
        admin: ContractAddress,
        initialized: bool,
    }

    #[event]
    fn Upgraded(implementation: ClassHash) {}

    #[event]
    fn AdminChanged(previous_admin: ContractAddress, new_admin: ContractAddress) {}

    fn initializer(contract_admin: ContractAddress) {
        assert(!initialized::read(), 'Contract already initialized');
        initialized::write(true);
        _set_admin(contract_admin);
    }

    fn assert_only_admin() {
        let caller: ContractAddress = get_caller_address();
        let admin: ContractAddress = admin::read();
        assert(caller == admin, 'Caller is not admin');
    }

    fn get_admin() -> ContractAddress {
        admin::read()
    }

    //
    // Unprotected
    //

    fn _set_admin(new_admin: ContractAddress) {
        assert(!new_admin.is_zero(), 'Admin cannot be zero');
        let old_admin: ContractAddress = admin::read();
        admin::write(new_admin);
        AdminChanged(old_admin, new_admin);
    }

    fn _upgrade(impl_hash: ClassHash) {
        assert(!impl_hash.is_zero(), 'Class hash cannot be zero');
        replace_class_syscall(impl_hash);
        Upgraded(impl_hash);
    }
}
