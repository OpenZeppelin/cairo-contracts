use array::ArrayTrait;
use core::result::ResultTrait;
use openzeppelin::utils::BoolIntoFelt252;
use option::OptionTrait;
use serde::Serde;
use starknet::class_hash::Felt252TryIntoClassHash;
use starknet::ContractAddress;
use traits::Into;
use traits::TryInto;

fn deploy(contract_class_hash: felt252, calldata: Array<felt252>) -> ContractAddress {
    let (address, _) = starknet::deploy_syscall(
        contract_class_hash.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();
    address
}

trait SerializedAppend<T> {
    fn append_serde(ref self: Array<felt252>, value: T);
}

impl SerializedAppendImpl<T, impl TSerde: Serde<T>, impl TDrop: Drop<T>> of SerializedAppend<T> {
    fn append_serde(ref self: Array<felt252>, value: T) {
        value.serialize(ref self);
    }
}
