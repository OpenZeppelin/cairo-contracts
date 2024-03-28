mod interface;
use interface::IUniversalDeployer;

use core::pedersen::pedersen;
use hash::{HashStateTrait, HashStateExTrait};
use openzeppelin::utils::serde::SerializedAppend;
use poseidon::PoseidonTrait;
use starknet::ClassHash;
use starknet::ContractAddress;

// 2**251 - 256
const L2_ADDRESS_UPPER_BOUND: felt252 =
    0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00;
const CONTRACT_ADDRESS_PREFIX: felt252 = 'STARKNET_CONTRACT_ADDRESS';

/// Return the contract address for an origin-independent deployment.
fn calculate_address_from_zero(
    salt: felt252, class_hash: ClassHash, constructor_calldata: Span<felt252>,
) -> ContractAddress {
    _calculate_contract_address_from_hash(salt, class_hash, constructor_calldata, Zeroable::zero())
}

/// Return the contract address for an origin-dependent deployment.
fn calculate_address_not_from_zero(
    salt: felt252,
    class_hash: ClassHash,
    constructor_calldata: Span<felt252>,
    caller_address: ContractAddress,
    deployer_address: ContractAddress
) -> ContractAddress {
    // Hash salt
    let mut state = PoseidonTrait::new();
    let hashed_salt = state.update_with(caller_address).update_with(salt).finalize();

    _calculate_contract_address_from_hash(
        hashed_salt, class_hash, constructor_calldata, deployer_address
    )
}

fn compute_hash_on_elements(mut data: Span<felt252>) -> felt252 {
    let data_len: usize = data.len();
    let mut hash = 0;
    loop {
        match data.pop_front() {
            Option::Some(elem) => { hash = pedersen(hash, *elem); },
            Option::None => {
                hash = pedersen(hash, data_len.into());
                break;
            },
        };
    };
    hash
}

/// See https://github.com/starkware-libs/cairo/blob/v2.6.3/crates/cairo-lang-runner/src/casm_run/contract_address.rs#L38-L57
fn _calculate_contract_address_from_hash(
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

