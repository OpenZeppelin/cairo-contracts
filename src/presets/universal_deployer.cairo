use starknet::ClassHash;
use starknet::ContractAddress;

#[starknet::interface]
trait IUniversalDeployer<TState> {
    fn deploy_contract(
        ref self: TState,
        class_hash: ClassHash,
        salt: felt252,
        unique: bool,
        calldata: Span<felt252>
    ) -> ContractAddress;
}

#[starknet::contract]
mod UniversalDeployer {
    use core::pedersen::pedersen;
    use starknet::ClassHash;
    use starknet::ContractAddress;
    use starknet::SyscallResultTrait;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ContractDeployed: ContractDeployed
    }

    #[derive(Drop, starknet::Event)]
    struct ContractDeployed {
        address: ContractAddress,
        deployer: ContractAddress,
        unique: bool,
        class_hash: ClassHash,
        calldata: Span<felt252>,
        salt: felt252,
    }

    #[abi(embed_v0)]
    impl UniversalDeployerImpl of super::IUniversalDeployer<ContractState> {
        fn deploy_contract(
            ref self: ContractState,
            class_hash: ClassHash,
            salt: felt252,
            unique: bool,
            calldata: Span<felt252>
        ) -> ContractAddress {
            let deployer: ContractAddress = get_caller_address();

            // Defaults for non-unique deployment
            let mut _salt: felt252 = salt;
            let mut from_zero: bool = true;

            if unique {
                _salt = pedersen(deployer.into(), salt);
                from_zero = false;
            }

            let (address, _) = starknet::deploy_syscall(class_hash, _salt, calldata, from_zero)
                .unwrap_syscall();

            self
                .emit(
                    ContractDeployed {
                        address: address,
                        deployer: deployer,
                        unique: unique,
                        class_hash: class_hash,
                        calldata: calldata,
                        salt: salt
                    }
                );

            return address;
        }
    }
}
