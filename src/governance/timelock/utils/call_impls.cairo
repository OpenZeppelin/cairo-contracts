// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.14.0 (governance/timelock/utils/call_impls.cairo)

use core::hash::{HashStateTrait, HashStateExTrait, Hash};
use starknet::ContractAddress;
use starknet::account::Call;

pub(crate) impl HashCallImpl<S, +HashStateTrait<S>, +Drop<S>> of Hash<@Call, S> {
    fn update_state(mut state: S, value: @Call) -> S {
        let Call { to, selector, mut calldata } = *value;
        state = state.update_with(to).update_with(selector).update_with(calldata.len());
        while calldata.len() > 0 {
            let elem = *calldata.pop_front().unwrap();
            state = state.update_with(elem);
        };
        state
    }
}

pub(crate) impl HashCallsImpl<S, +HashStateTrait<S>, +Drop<S>> of Hash<@Span<Call>, S> {
    fn update_state(mut state: S, value: @Span<Call>) -> S {
        let mut calls = *value;
        state = state.update_with(calls.len());
        while calls.len() > 0 {
            let call = calls.pop_front().unwrap();
            state = state.update_with(call);
        };
        state
    }
}

pub(crate) impl CallPartialEq of PartialEq<Call> {
    #[inline(always)]
    fn eq(lhs: @Call, rhs: @Call) -> bool {
        let mut lhs_arr = array![];
        Serde::serialize(lhs, ref lhs_arr);
        let mut rhs_arr = array![];
        Serde::serialize(lhs, ref rhs_arr);
        lhs_arr == rhs_arr
    }
    #[inline(always)]
    fn ne(lhs: @Call, rhs: @Call) -> bool {
        let mut lhs_arr = array![];
        Serde::serialize(lhs, ref lhs_arr);
        let mut rhs_arr = array![];
        Serde::serialize(lhs, ref rhs_arr);
        !(lhs_arr == rhs_arr)
    }
}
