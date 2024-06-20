// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.14.0 (governance/timelock/utils/call_impls.cairo)

use core::hash::{HashStateTrait, HashStateExTrait, Hash};
use starknet::ContractAddress;

// TMP until cairo v2.7 release, then use SN `Call` struct
// `Call` from v2.6 does not derive Copy trait
#[derive(Drop, Copy, Serde, Debug)]
pub struct Call {
    pub to: ContractAddress,
    pub selector: felt252,
    pub calldata: Span<felt252>
}

pub(crate) impl HashCallImpl<
    Call, S, +Serde<Call>, +HashStateTrait<S>, +Drop<S>
> of Hash<@Call, S> {
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
    #[inline(always)]
    fn ne(lhs: @Call, rhs: @Call) -> bool {
        let mut lhs_arr = array![];
        Serde::serialize(lhs, ref lhs_arr);
        let mut rhs_arr = array![];
        Serde::serialize(lhs, ref rhs_arr);
        !(lhs_arr == rhs_arr)
    }
}
