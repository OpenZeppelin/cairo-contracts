use core::starknet::SyscallResultTrait;
use openzeppelin::tests::utils::panic_data_to_byte_array;
use snforge_std::{ContractClass, ContractClassTrait};
use starknet::ContractAddress;

pub fn deploy(contract_class: ContractClass, calldata: Array<felt252>) -> ContractAddress {
    match contract_class.deploy(@calldata) {
        Result::Ok((contract_address, _)) => contract_address,
        Result::Err(panic_data) => panic!("{}", panic_data_to_byte_array(panic_data))
    }
}

pub fn deploy_at(
    contract_class: ContractClass, contract_address: ContractAddress, calldata: Array<felt252>
) {
    match contract_class.deploy_at(@calldata, contract_address) {
        Result::Ok(_) => (),
        Result::Err(panic_data) => panic!("{}", panic_data_to_byte_array(panic_data))
    };
}

/// Deploys a contract from the class hash of another contract which is already deployed.
pub fn deploy_another_at(
    existing: ContractAddress, target_address: ContractAddress, calldata: Array<felt252>
) {
    let class_hash = snforge_std::get_class_hash(existing);
    let contract_class = ContractClassTrait::new(class_hash);
    deploy_at(contract_class, target_address, calldata)
}

pub fn declare_class(contract_name: ByteArray) -> ContractClass {
    match snforge_std::declare(contract_name) {
        Result::Ok(contract_class) => contract_class,
        Result::Err(panic_data) => panic!("{}", panic_data_to_byte_array(panic_data))
    }
}

pub fn declare_and_deploy(contract_name: ByteArray, calldata: Array<felt252>) -> ContractAddress {
    let contract_class = declare_class(contract_name);
    deploy(contract_class, calldata)
}

pub fn declare_and_deploy_at(
    contract_name: ByteArray, target_address: ContractAddress, calldata: Array<felt252>
) {
    let contract_class = declare_class(contract_name);
    deploy_at(contract_class, target_address, calldata)
}
