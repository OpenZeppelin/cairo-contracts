use snforge_std::{ContractClass, ContractClassTrait, test_address};
use starknet::ClassHash;
use crate::deployments::calculate_contract_address_from_deploy_syscall;

#[test]
#[fuzzer]
fn test_compute_contract_address(
    class_hash: felt252, arg_1: felt252, arg_2: felt252, arg_3: felt252,
) {
    let class_hash: ClassHash = match class_hash.try_into() {
        Option::Some(class_hash) => class_hash,
        Option::None => { return; },
    };
    let deployer_address = test_address();
    let contract_class = ContractClass { class_hash };
    let constructor_calldata = array![arg_1, arg_2, arg_3];
    let salt = 0;
    let expected_address = contract_class.precalculate_address(@constructor_calldata);

    let computed_address = calculate_contract_address_from_deploy_syscall(
        salt, class_hash, constructor_calldata.span(), deployer_address,
    );
    assert_eq!(computed_address, expected_address);
}
