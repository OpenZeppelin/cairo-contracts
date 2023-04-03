use starknet::ContractAddress;

#[contract]
mod Proxy {
    use openzeppelin::token::erc20::IERC20;
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use starknet::ContractAddressZeroable;
    use zeroable::Zeroable;

    struct Storage {
        implementation_hash: felt252,
        admin: ContractAddress,
        initialized: bool,
    }

    #[event]
    fn Upgraded(implementation: felt252) {}

    #[event]
    fn AdminChanged(previous_admin: ContractAddress, new_admin: ContractAddress) {}

    fn initializer(proxy_admin: ContractAddress) {
        assert(!initialized::read(), '');
        initialized::write(true);
    }

    fn assert_only_admin() {
        let caller: ContractAddress = get_caller_address();
        let admin: ContractAddress = admin::read();
        assert(caller == admin, '');
    }

    fn get_implementation_hash() -> felt252 {
        implementation_hash::read()
    }

    fn _set_admin(new_admin: ContractAddress) {
        let previous_admin: ContractAddress = admin::read();
        admin::write(new_admin);
        AdminChanged(previous_admin, new_admin);
    }

    fn _set_implementation_hash(new_hash: felt252) {
        assert(!new_hash.is_zero(), '');
        implementation_hash::write(new_hash);
        Upgraded(new_hash);
    }
}
