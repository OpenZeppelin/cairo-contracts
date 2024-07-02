use snforge_std::{declare, ContractClass, ContractClassTrait};
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

pub fn declare_class(contract_name: ByteArray) -> ContractClass {
    declare(contract_name).unwrap()
}

pub fn declare_and_deploy(contract_name: ByteArray, calldata: Array<felt252>) -> ContractAddress {
    let contract_class = declare(contract_name).unwrap();
    deploy(contract_class, calldata)
}

pub fn declare_and_deploy_at(
    contract_name: ByteArray, target_address: ContractAddress, calldata: Array<felt252>
) {
    let contract_class = declare(contract_name).expect('Failed to declare contract');
    deploy_at(contract_class, target_address, calldata)
}
