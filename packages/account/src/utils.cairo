// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v3.0.0-alpha.2 (account/src/utils.cairo)

pub mod secp256_point;
pub mod signature;
use openzeppelin_interfaces::accounts::{ISRC6Dispatcher, ISRC6DispatcherTrait};

pub use signature::{is_valid_eth_signature, is_valid_p256_signature, is_valid_stark_signature};
use starknet::account::Call;
use starknet::{ContractAddress, SyscallResultTrait};

pub const MIN_TRANSACTION_VERSION: u256 = 1;
pub const QUERY_OFFSET: u256 = 0x100000000000000000000000000000000;
// QUERY_OFFSET + TRANSACTION_VERSION
pub const QUERY_VERSION: u256 = 0x100000000000000000000000000000001;

/// Executes a list of calls and returns the return values.
pub fn execute_calls(calls: Span<Call>) -> Array<Span<felt252>> {
    let mut res = array![];
    for call in calls {
        res.append(execute_single_call(call));
    }
    res
}

/// Executes a single call and returns the return value.
pub fn execute_single_call(call: @Call) -> Span<felt252> {
    let Call { to, selector, calldata } = *call;
    starknet::syscalls::call_contract_syscall(to, selector, calldata).unwrap_syscall()
}

/// Validates a signature using SRC6 `is_valid_signature` and asserts it's valid.
/// Checks both 'VALID' (starknet::VALIDATED) and true (1) for backwards compatibility.
pub fn assert_valid_signature(
    signer: ContractAddress,
    hash: felt252,
    signature: Span<felt252>,
    invalid_signature_error: felt252,
) {
    let is_valid_signature_felt = ISRC6Dispatcher { contract_address: signer }
        .is_valid_signature(hash, signature.into());

    // Check either 'VALID' or true for backwards compatibility
    let is_valid_signature = is_valid_signature_felt == starknet::VALIDATED
        || is_valid_signature_felt == 1;

    assert(is_valid_signature, invalid_signature_error);
}

/// If the transaction is a simulation (version >= `QUERY_OFFSET`), it must be
/// greater than or equal to `QUERY_OFFSET` + `MIN_TRANSACTION_VERSION` to be considered valid.
/// Otherwise, it must be greater than or equal to `MIN_TRANSACTION_VERSION`.
pub fn is_tx_version_valid() -> bool {
    let tx_info = starknet::get_tx_info().unbox();
    let tx_version = tx_info.version.into();
    if tx_version >= QUERY_OFFSET {
        QUERY_OFFSET + MIN_TRANSACTION_VERSION <= tx_version
    } else {
        MIN_TRANSACTION_VERSION <= tx_version
    }
}
