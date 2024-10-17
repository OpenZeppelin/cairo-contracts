// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.18.0 (utils/deployments.cairo)

pub mod interface;

use core::hash::{HashStateTrait, HashStateExTrait};
use core::num::traits::Zero;
use core::pedersen::PedersenTrait;
use core::poseidon::PoseidonTrait;
use crate::serde::SerializedAppend;
use starknet::{ClassHash, ContractAddress};

// 2**251 - 256
pub const L2_ADDRESS_UPPER_BOUND: felt252 =
    0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00;
pub const CONTRACT_ADDRESS_PREFIX: felt252 = 'STARKNET_CONTRACT_ADDRESS';

/// Returns the contract address from a `deploy_syscall`.
/// `deployer_address` should be the zero address if the deployment is origin-independent (deployed
/// from zero).
///
/// For more information, see
/// https://docs.starknet.io/documentation/architecture_and_concepts/Smart_Contracts/contract-address/
pub fn calculate_contract_address_from_deploy_syscall(
    salt: felt252,
    class_hash: ClassHash,
    constructor_calldata: Span<felt252>,
    deployer_address: ContractAddress
) -> ContractAddress {
    let constructor_calldata_hash = compute_hash_on_elements(constructor_calldata);

    let mut data = array![];
    data.append_serde(CONTRACT_ADDRESS_PREFIX);
    data.append_serde(deployer_address);
    data.append_serde(salt);
    data.append_serde(class_hash);
    data.append_serde(constructor_calldata_hash);
    let raw_address = compute_hash_on_elements(data.span());

    // Felt modulo is discouraged, hence the conversion to u256
    let u256_addr: u256 = raw_address.into() % L2_ADDRESS_UPPER_BOUND.into();
    let felt_addr = u256_addr.try_into().unwrap();

    let mut serialized = array![felt_addr].span();
    Serde::<ContractAddress>::deserialize(ref serialized).unwrap()
}

/// Creates a Pedersen hash chain with the elements of `data` and returns the finalized hash.
fn compute_hash_on_elements(mut data: Span<felt252>) -> felt252 {
    let data_len = data.len();
    let mut state = PedersenTrait::new(0);
    let mut hash = 0;
    loop {
        match data.pop_front() {
            Option::Some(elem) => { state = state.update_with(*elem); },
            Option::None => {
                hash = state.update_with(data_len).finalize();
                break;
            },
        };
    };
    hash
}

#[derive(Drop)]
pub struct DeployerInfo {
    pub caller_address: ContractAddress,
    pub udc_address: ContractAddress
}

/// Returns the calculated contract address for contracts deployed through the UDC.
/// Origin-independent deployments (deployed from zero) should pass `Option::None` as
/// `deployer_info`.
pub fn calculate_contract_address_from_udc(
    salt: felt252,
    class_hash: ClassHash,
    constructor_calldata: Span<felt252>,
    deployer_info: Option<DeployerInfo>
) -> ContractAddress {
    match deployer_info {
        Option::Some(deployer_info) => {
            let mut state = PoseidonTrait::new();
            let hashed_salt = state
                .update_with(deployer_info.caller_address)
                .update_with(salt)
                .finalize();
            calculate_contract_address_from_deploy_syscall(
                hashed_salt, class_hash, constructor_calldata, deployer_info.udc_address
            )
        },
        Option::None => calculate_contract_address_from_deploy_syscall(
            salt, class_hash, constructor_calldata, Zero::zero()
        ),
    }
}
