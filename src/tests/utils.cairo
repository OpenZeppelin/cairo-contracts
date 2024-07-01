pub(crate) mod constants;
pub mod foundry;

pub use foundry::{declare_and_deploy, spy_on, assert_no_events_left, drop_event, drop_events};

use starknet::ContractAddress;
use starknet::SyscallResultTrait;
use starknet::testing;

pub fn deploy(contract_class_hash: felt252, calldata: Array<felt252>) -> ContractAddress {
    deploy_with_salt(contract_class_hash, calldata, 0)
}

pub fn deploy_with_salt(
    contract_class_hash: felt252, calldata: Array<felt252>, salt: felt252
) -> ContractAddress {
    let (address, _) = starknet::syscalls::deploy_syscall(
        contract_class_hash.try_into().unwrap(), salt, calldata.span(), false
    )
        .unwrap_syscall();
    address
}
