// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.10.0 (presets/universal_deployer.cairo)

/// # UniversalDeployer Preset
///
/// The Universal Deployer Contract is a singleton smart contract that wraps `deploy_syscall`
/// to expose it to any contract that doesn't implement it, such as account contracts.
///
/// This contract is already deployed at 0x041a78e741e5af2fec34b695679bc6891742439f7afb8484ecd7766661ad02bf
/// on mainnet, testnets, and starknet-devnet.
/// This address may change in the future.
#[starknet::contract]
mod UniversalDeployer {
    use core::poseidon;
    use openzeppelin::utils::universal_deployer::interface;
    use starknet::ClassHash;
    use starknet::ContractAddress;
    use starknet::SyscallResultTrait;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        ContractDeployed: ContractDeployed
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct ContractDeployed {
        address: ContractAddress,
        deployer: ContractAddress,
        unique: bool,
        class_hash: ClassHash,
        calldata: Span<felt252>,
        salt: felt252,
    }

    #[abi(embed_v0)]
    impl UniversalDeployerImpl of interface::IUniversalDeployer<ContractState> {
        fn deploy_contract(
            ref self: ContractState,
            class_hash: ClassHash,
            salt: felt252,
            unique: bool,
            calldata: Span<felt252>
        ) -> ContractAddress {
            let deployer: ContractAddress = get_caller_address();
            let from_zero: bool = !unique;
            let mut _salt: felt252 = salt;
            if unique {
                _salt = poseidon::poseidon_hash_span(array![deployer.into(), salt].span());
            }

            let (address, _) = starknet::deploy_syscall(class_hash, _salt, calldata, from_zero)
                .unwrap_syscall();

            self.emit(ContractDeployed { address, deployer, unique, class_hash, calldata, salt });
            return address;
        }
    }
}
