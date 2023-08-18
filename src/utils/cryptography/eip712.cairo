// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.7.0 (utils/cryptography/eip712.cairo)

use array::ArrayTrait;
use array::SpanTrait;
use box::BoxTrait;
use poseidon::poseidon_hash_span;
use starknet::SyscallResultTrait;
use traits::Into;

/// Returns the poseidon digest of an EIP-712 typed data (EIP-191 version `0x01`).
///
/// The digest is calculated from a `domain_separator` and a `struct_hash`, by prefixing them with
/// `\x19\x01` and hashing the result. It corresponds to the hash signed by the
/// https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`] JSON-RPC method as part of EIP-712.
fn to_typed_data_hash(domain_separator: felt252, struct_hash: felt252) -> felt252 {
    let prefix = 0x1901;
    poseidon_hash_span(array![prefix, domain_separator, struct_hash].span())
}


/// The meaning of `name` and `version` is specified in
/// https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator[EIP 712]:
///
/// - `name`: the user readable name of the signing domain, i.e. the name of the DApp or the protocol.
/// - `version`: the current major version of the signing domain.
///
fn build_domain_separator(name: felt252, version: felt252) -> felt252 {
    let hashed_name = poseidon_hash_span(array![name].span());
    let hashed_version = poseidon_hash_span(array![version].span());
    let contract_address = starknet::get_contract_address();
    let tx_info = starknet::get_tx_info().unbox();
    poseidon_hash_span(
        array![TYPE_HASH(), hashed_name, hashed_version, tx_info.chain_id, contract_address.into()]
            .span()
    )
}

fn TYPE_HASH() -> felt252 {
    poseidon_hash_span(
        array![
            'EIP712Domain',
            '(name: ContractAddress,',
            'version: felt252,',
            'chain_id: felt252,',
            'verifying_contract: ',
            'ContractAddress)'
        ]
            .span()
    )
}
