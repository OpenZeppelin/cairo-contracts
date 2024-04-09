mod interface;

use core::pedersen::PedersenTrait;
use hash::{HashStateTrait, HashStateExTrait};
use interface::IUniversalDeployer;
use openzeppelin::utils::serde::SerializedAppend;
use poseidon::PoseidonTrait;
use starknet::ClassHash;
use starknet::ContractAddress;

// 2**251 - 256
const L2_ADDRESS_UPPER_BOUND: felt252 =
    0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00;
const CONTRACT_ADDRESS_PREFIX: felt252 = 'STARKNET_CONTRACT_ADDRESS';

/// Returns the contract address from a `deploy_syscall`.
/// `deployer_address` should be the zero address if the deployment is origin-independent (deployed from zero).
/// For more information, see https://docs.starknet.io/documentation/architecture_and_concepts/Smart_Contracts/contract-address/
fn calculate_contract_address_from_deploy_syscall(
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
    starknet::contract_address_try_from_felt252(felt_addr).unwrap()
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

/// Returns the contract address for an origin-independent deployment from the UDC.
/// This follows the same logic as `deploy_syscall` when deploying from zero.
fn udc_calculate_contract_address_from_zero(
    salt: felt252, class_hash: ClassHash, constructor_calldata: Span<felt252>,
) -> ContractAddress {
    calculate_contract_address_from_deploy_syscall(
        salt, class_hash, constructor_calldata, Zeroable::zero()
    )
}

/// Returns the contract address for an origin-dependent deployment from the UDC.
/// The inner `deploy_syscall` receives the hash of `salt` and `caller_address` as the salt argument.
fn udc_calculate_contract_address_not_from_zero(
    salt: felt252,
    class_hash: ClassHash,
    constructor_calldata: Span<felt252>,
    caller_address: ContractAddress,
    deployer_address: ContractAddress
) -> ContractAddress {
    // Hash salt
    let mut state = PoseidonTrait::new();
    let hashed_salt = state.update_with(caller_address).update_with(salt).finalize();

    calculate_contract_address_from_deploy_syscall(
        hashed_salt, class_hash, constructor_calldata, deployer_address
    )
}
