#[contract]
mod UniversalDeployerContract {
    use array::ArrayTrait;
    use hash::pedersen;
    use starknet::{class_hash::ClassHash, ContractAddress, get_caller_address};
    use traits::Into;

    #[event]
    fn ContractDeployed(
        address: ContractAddress,
        deployer: ContractAddress,
        unique: bool,
        class_hash: ClassHash,
        calldata: Array<felt252>,
        salt: felt252,
    ) {}

    #[external]
    fn deploy_contract(
        class_hash: ClassHash, salt: felt252, unique: bool, calldata: Span<felt252>
    ) -> ContractAddress {
        let deployer: ContractAddress = get_caller_address();

        // Defaults for non-unique deployment
        let mut _salt: felt252 = salt;
        let mut from_zero: bool = true;

        if unique {
            _salt = pedersen(deployer.into(), salt);
            from_zero = false;
        }

        let (address, _) = starknet::syscalls::deploy_syscall(
            class_hash, _salt, calldata.span(), from_zero
        ).unwrap_syscall();

        ContractDeployed(address, deployer, unique, class_hash, calldata, salt);
        return address;
    }
}
