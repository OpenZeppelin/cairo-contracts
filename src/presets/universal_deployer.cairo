// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.12.0 (presets/universal_deployer.cairo)

/// # UniversalDeployerContract Preset
///
/// The Universal Deployer Contract is a standardized generic factory of Starknet contracts.
#[starknet::contract]
pub(crate) mod UniversalDeployer {
    use core::hash::{HashStateTrait, HashStateExTrait};
    use core::poseidon::PoseidonTrait;
    use openzeppelin::utils::interfaces::IUniversalDeployer;
    use starknet::ClassHash;
    use starknet::ContractAddress;
    use starknet::SyscallResultTrait;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub(crate) enum Event {
        ContractDeployed: ContractDeployed
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub(crate) struct ContractDeployed {
        pub(crate) address: ContractAddress,
        pub(crate) deployer: ContractAddress,
        pub(crate) from_zero: bool,
        pub(crate) class_hash: ClassHash,
        pub(crate) calldata: Span<felt252>,
        pub(crate) salt: felt252,
    }

    #[abi(embed_v0)]
    impl UniversalDeployerImpl of IUniversalDeployer<ContractState> {
        fn deploy_contract(
            ref self: ContractState,
            class_hash: ClassHash,
            salt: felt252,
            from_zero: bool,
            calldata: Span<felt252>
        ) -> ContractAddress {
            let deployer: ContractAddress = get_caller_address();
            let mut _salt: felt252 = salt;
            if !from_zero {
                let mut hash_state = PoseidonTrait::new();
                _salt = hash_state.update_with(deployer).update_with(salt).finalize();
            }

            let (address, _) = starknet::syscalls::deploy_syscall(
                class_hash, _salt, calldata, from_zero
            )
                .unwrap_syscall();

            self
                .emit(
                    ContractDeployed { address, deployer, from_zero, class_hash, calldata, salt }
                );
            return address;
        }
    }
}
