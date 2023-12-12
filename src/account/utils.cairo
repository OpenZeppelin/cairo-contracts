mod signature_validator;

use signature_validator::{is_valid_signature, is_valid_eth_signature};
use starknet::account::Call;

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
