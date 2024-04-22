// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.12.0 (utils/unwrap_and_cast.cairo)

use starknet::SyscallResult;
use starknet::SyscallResultTrait;

trait UnwrapAndCast<T> {
    fn unwrap_and_cast(self: SyscallResult<Span<felt252>>) -> T;
}

impl UnwrapAndCastSerde<T, +Serde<T>> of UnwrapAndCast<T> {
    fn unwrap_and_cast(self: SyscallResult<Span<felt252>>) -> T {
        let mut result = self.unwrap_syscall();
        Serde::<T>::deserialize(ref result).unwrap()
    }
}
