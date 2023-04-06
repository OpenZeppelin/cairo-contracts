#[contract]
mod Upgradable {
    use serde::Serde;
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use starknet::contract_address::ContractAddressSerde;
    use starknet::ContractAddressZeroable;
    use starknet::class_hash::ClassHash;
    use starknet::class_hash::ClassHashZeroable;
    use zeroable::Zeroable;
    use array::ArrayTrait;
    use array::SpanTrait;
    use box::BoxTrait;
    use option::OptionTrait;
    use starknet::syscalls::replace_class_syscall;

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
        admin::write(contract_admin);
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
        admin::write(new_admin);
    }

    fn _upgrade(impl_hash: ClassHash) -> bool {
        assert(!impl_hash.is_zero(), 'Class hash cannot be zero');
        replace_class_syscall(impl_hash);
        return true;
    }
}
