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

trait PanicTrait<T> {
    fn panic(self: T);
}

impl Felt252PanicImpl of PanicTrait<felt252> {
    fn panic(self: felt252) {
        panic_with_felt252(self);
    }
}

impl ContractAddressPanicImpl of PanicTrait<ContractAddress> {
    fn panic(self: ContractAddress) {
        panic_with_felt252(self.into());
    }
}

impl U256PanicImpl of PanicTrait<u256> {
    fn panic(self: u256) {
        let mut message = ArrayTrait::new();
        message.append(self.low.into());
        message.append(self.high.into());
        panic(message);
    }
}

impl BoolPanicImpl of PanicTrait<bool> {
    fn panic(self: bool) {
        panic_with_felt252(self.into());
    }
}
