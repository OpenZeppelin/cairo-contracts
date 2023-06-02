use array::ArrayTrait;
use array::SpanTrait;
use core::result::ResultTrait;
use core::traits::Into;
use hash::pedersen;
use option::OptionTrait;
use starknet::class_hash::Felt252TryIntoClassHash;
use starknet::class_hash::ClassHash;
use starknet::ContractAddress;
use traits::TryInto;

// from_bytes(b"STARKNET_CONTRACT_ADDRESS")
const CONTRACT_ADDRESS_PREFIX: felt252 = 0x535441524b4e45545f434f4e54524143545f41444452455353;
// 2**251 - 256
const L2_ADDRESS_UPPER_BOUND: felt252 =
    0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00;

fn deploy(contract_class_hash: felt252, calldata: Array<felt252>) -> ContractAddress {
    let (address, _) = starknet::deploy_syscall(
        contract_class_hash.try_into().unwrap(), 0, calldata.span(), false
    )
        .unwrap();
    address
}

fn compute_hash_on_elements(mut data: Span::<felt252>) -> felt252 {
    let data_len: usize = data.len();
    let mut hash = 0;
    loop {
        match data.pop_front() {
            Option::Some(x) => {
                hash = pedersen(hash, *x);
            },
            Option::None(_) => {
                hash = pedersen(hash, data_len.into());
                break ();
            },
        };
    };
    hash
}

fn calculate_contract_address_from_hash(
    salt: felt252,
    class_hash: ClassHash,
    constructor_calldata: Span::<felt252>,
    deployer_address: ContractAddress
) -> ContractAddress {
    let constructor_calldata_hash = compute_hash_on_elements(constructor_calldata);

    let mut data = ArrayTrait::new();
    data.append(CONTRACT_ADDRESS_PREFIX);
    data.append(deployer_address.into());
    data.append(salt);
    data.append(class_hash.into());
    data.append(constructor_calldata_hash);
    let raw_address = compute_hash_on_elements(data.span());

    // Felt modulo is discouraged, hence the conversion to u256
    let u256_addr: u256 = raw_address.into() % L2_ADDRESS_UPPER_BOUND.into();
    let felt_addr = u256_addr.try_into().unwrap();
    starknet::contract_address_try_from_felt252(felt_addr).unwrap()
}
