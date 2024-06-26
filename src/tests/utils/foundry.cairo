use snforge_std::{declare, ContractClass, ContractClassTrait, spy_events, EventSpy, SpyOn};
use starknet::ContractAddress;

pub fn declare_and_deploy(contract_name: ByteArray, calldata: Array<felt252>) -> ContractAddress {
    let contract_class = declare(contract_name).unwrap();
    match contract_class.deploy(@calldata) {
        Result::Ok((contract_address, _)) => contract_address,
        Result::Err(panic_data) => panic!("Failed to deploy, error: ${:?}", panic_data)
    }
}

pub fn declare_and_deploy_at(
    contract_name: ByteArray, contract_address: ContractAddress, calldata: Array<felt252>
) {
    let contract_class = declare(contract_name).unwrap();
    if let Result::Err(panic_data) = contract_class.deploy_at(@calldata, contract_address) {
        panic!("Failed to deploy, error: ${:?}", panic_data)
    }
}

pub fn spy_on(contract_address: ContractAddress) -> EventSpy {
    spy_events(SpyOn::One(contract_address))
}

