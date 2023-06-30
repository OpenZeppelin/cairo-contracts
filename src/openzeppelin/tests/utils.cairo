use core::result::ResultTrait;
use option::OptionTrait;
use array::ArrayTrait;
use traits::TryInto;
use traits::Into;

use openzeppelin::utils::BoolIntoFelt252;
use starknet::class_hash::Felt252TryIntoClassHash;
use starknet::ContractAddress;

fn deploy(contract_class_hash: felt252, calldata: Array<felt252>) -> ContractAddress {
    let (address, _) = starknet::deploy_syscall(
        contract_class_hash.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();
    address
}
