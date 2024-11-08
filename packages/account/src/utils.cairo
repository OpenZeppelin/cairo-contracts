// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.19.0 (account/utils.cairo)

pub mod secp256_point;
pub mod signature;

pub use signature::{is_valid_stark_signature, is_valid_eth_signature, is_valid_p256_signature};

use starknet::SyscallResultTrait;
use starknet::account::Call;

pub const MIN_TRANSACTION_VERSION: u256 = 1;
pub const QUERY_OFFSET: u256 = 0x100000000000000000000000000000000;
// QUERY_OFFSET + TRANSACTION_VERSION
pub const QUERY_VERSION: u256 = 0x100000000000000000000000000000001;

pub fn execute_calls(mut calls: Span<Call>) -> Array<Span<felt252>> {
    let mut res = array![];
    loop {
        match calls.pop_front() {
            Option::Some(call) => {
                let _res = execute_single_call(call);
                res.append(_res);
            },
            Option::None => { break (); },
        };
    };
    res
}

fn execute_single_call(call: @Call) -> Span<felt252> {
    let Call { to, selector, calldata } = *call;
    starknet::syscalls::call_contract_syscall(to, selector, calldata).unwrap_syscall()
}
