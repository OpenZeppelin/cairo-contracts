// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.13.0 (governance/timelock/utils/call_impls.cairo)

use core::hash::{HashStateTrait, HashStateExTrait, Hash};
use starknet::account::Call;

impl HashCallImpl<Call, S, +Serde<Call>, +HashStateTrait<S>, +Drop<S>> of Hash<@Call, S> {
    fn update_state(mut state: S, value: @Call) -> S {
        let mut arr = array![];
        Serde::serialize(value, ref arr);
        state = state.update(arr.len().into());
        while let Option::Some(elem) = arr.pop_front() {
            state = state.update(elem)
        };
        state
    }
}

impl CallPartialEq of PartialEq<Call> {
    #[inline(always)]
    fn eq(lhs: @Call, rhs: @Call) -> bool {
        let mut lhs_arr = array![];
        Serde::serialize(lhs, ref lhs_arr);
        let mut rhs_arr = array![];
        Serde::serialize(lhs, ref rhs_arr);
        lhs_arr == rhs_arr
    }

    fn ne(lhs: @Call, rhs: @Call) -> bool {
        let mut lhs_arr = array![];
        Serde::serialize(lhs, ref lhs_arr);
        let mut rhs_arr = array![];
        Serde::serialize(lhs, ref rhs_arr);
        !(lhs_arr == rhs_arr)
    }
}
