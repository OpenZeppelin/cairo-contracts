# assert_entrypoint_not_found_error

Asserts that the syscall result of a call failed with an "Entrypoint not found" error, following the Starknet Foundry emitted error format.

Fully qualified path: `openzeppelin_testing::common::assert_entrypoint_not_found_error`

```rust
pub fn assert_entrypoint_not_found_error<T, +Drop<T>>(
    result: SyscallResult<T>, selector: felt252, contract_address: ContractAddress,
)
```

