use core::starknet::SyscallResultTrait;
use snforge_std::{declare, get_class_hash, ContractClass, ContractClassTrait};
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
use starknet::ContractAddress;

pub fn deploy(contract_class: ContractClass, calldata: Array<felt252>) -> ContractAddress {
    match contract_class.deploy(@calldata) {
        Result::Ok((contract_address, _)) => contract_address,
        Result::Err(panic_data) => panic!("Failed to deploy, error: ${:?}", panic_data)
    }
}

pub fn deploy_at(
    contract_class: ContractClass, contract_address: ContractAddress, calldata: Array<felt252>
) {
    match contract_class.deploy_at(@calldata, contract_address) {
        Result::Ok(_) => (),
        Result::Err(panic_data) => panic!("Failed to deploy, error: ${:?}", panic_data)
    };
}

/// Deploys a contract from the class hash of another contract which is already deployed.
pub fn deploy_another_at(
    existing: ContractAddress, target_address: ContractAddress, calldata: Array<felt252>
) {
    let class_hash = get_class_hash(existing);
    let contract_class = ContractClassTrait::new(class_hash);
    deploy_at(contract_class, target_address, calldata)
}

pub fn declare_class(contract_name: ByteArray) -> ContractClass {
    declare(contract_name).unwrap_syscall()
}

pub fn declare_and_deploy(contract_name: ByteArray, calldata: Array<felt252>) -> ContractAddress {
    let contract_class = declare(contract_name).unwrap_syscall();
    deploy(contract_class, calldata)
}

pub fn declare_and_deploy_with_caller(
    contract_name: ByteArray, calldata: Array<felt252>, caller: ContractAddress
) -> ContractAddress {
    let contract_class = declare(contract_name).unwrap_syscall();

    // Precalculate the address before the constructor call (deploy) itself
    let contract_address = contract_class.precalculate_address(@calldata);

    start_cheat_caller_address(contract_address, caller);
    deploy(contract_class, calldata);
    stop_cheat_caller_address(contract_address);

    contract_address
}

pub fn declare_and_deploy_at(
    contract_name: ByteArray, target_address: ContractAddress, calldata: Array<felt252>
) {
    let contract_class = declare(contract_name).unwrap_syscall();
    deploy_at(contract_class, target_address, calldata)
}
