use openzeppelin_testing::panic_data_to_byte_array;
use snforge_std::{ContractClass, ContractClassTrait, DeclareResultTrait};
use starknet::ContractAddress;

/// Declares a contract with a `snforge` `declare` call and unwraps the result.
///
/// NOTE: If the contract is already declared, this function won't panic but will instead
/// return the existing class.
pub fn declare_class(contract_name: ByteArray) -> ContractClass {
    match snforge_std::declare(contract_name) {
        Result::Ok(declare_result) => *declare_result.contract_class(),
        Result::Err(panic_data) => panic!("{}", panic_data_to_byte_array(panic_data))
    }
}

/// Deploys an instance of a contract and unwraps the result.
pub fn deploy(contract_class: ContractClass, calldata: Array<felt252>) -> ContractAddress {
    match contract_class.deploy(@calldata) {
        Result::Ok((contract_address, _)) => contract_address,
        Result::Err(panic_data) => panic!("{}", panic_data_to_byte_array(panic_data))
    }
}

/// Deploys a contract at the given address and unwraps the result.
pub fn deploy_at(
    contract_class: ContractClass, target_address: ContractAddress, calldata: Array<felt252>
) {
    match contract_class.deploy_at(@calldata, target_address) {
        Result::Ok(_) => (),
        Result::Err(panic_data) => panic!("{}", panic_data_to_byte_array(panic_data))
    };
}

/// Deploys a contract using the class hash from another already-deployed contract.
pub fn deploy_another_at(
    existing: ContractAddress, target_address: ContractAddress, calldata: Array<felt252>
) {
    let class_hash = snforge_std::get_class_hash(existing);
    let contract_class = ContractClassTrait::new(class_hash);
    deploy_at(contract_class, target_address, calldata)
}

/// Combines the declaration of a class and the deployment of a contract into one function call.
///
/// NOTE: If the contract is already declared, this function will skip the declaration step and will
/// deploy it.
pub fn declare_and_deploy(contract_name: ByteArray, calldata: Array<felt252>) -> ContractAddress {
    let contract_class = declare_class(contract_name);
    deploy(contract_class, calldata)
}

/// Combines the declaration of a class and the deployment of a contract at the given address
/// into one function call.
///
/// NOTE: If the contract is already declared, this function will skip the declaration step and will
/// deploy it.
pub fn declare_and_deploy_at(
    contract_name: ByteArray, target_address: ContractAddress, calldata: Array<felt252>
) {
    let contract_class = declare_class(contract_name);
    deploy_at(contract_class, target_address, calldata)
}
