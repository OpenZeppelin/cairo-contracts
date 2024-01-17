// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.8.0 (account/utils.cairo)

mod secp256k1;
mod signature;

use signature::{is_valid_stark_signature, is_valid_eth_signature};
use starknet::account::Call;

const TRANSACTION_VERSION: felt252 = 1;
// 2**128 + TRANSACTION_VERSION
const QUERY_VERSION: felt252 = 0x100000000000000000000000000000001;

fn execute_calls(mut calls: Array<Call>) -> Array<Span<felt252>> {
    let mut res = ArrayTrait::new();
    loop {
        match calls.pop_front() {
            Option::Some(call) => {
                let _res = execute_single_call(call);
                res.append(_res);
            },
            Option::None(_) => { break (); },
        };
    };
    res
}

fn execute_single_call(call: Call) -> Span<felt252> {
    let Call{to, selector, calldata } = call;
    starknet::call_contract_syscall(to, selector, calldata.span()).unwrap()
}
