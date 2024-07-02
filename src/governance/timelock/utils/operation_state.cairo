// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.14.0 (governance/timelock/utils/operation_state.cairo)

use core::fmt::{Debug, Formatter, Error};

#[derive(Drop, Copy, Serde, PartialEq)]
pub enum OperationState {
    Unset,
    Waiting,
    Ready,
    Done
}

impl DebugOperationState of core::fmt::Debug<OperationState> {
    fn fmt(self: @OperationState, ref f: Formatter) -> Result<(), Error> {
        match self {
            OperationState::Unset => write!(f, "Unset"),
            OperationState::Waiting => write!(f, "Waiting"),
            OperationState::Ready => write!(f, "Ready"),
            OperationState::Done => write!(f, "Done"),
        }
    }
}
