# common

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[common](./openzeppelin_testing-common.md)


## [Free functions](./openzeppelin_testing-common-free_functions.md)

| | |
|:---|:---|
| [panic_data_to_byte_array](./openzeppelin_testing-common-panic_data_to_byte_array.md) | Converts panic data into a string (ByteArray). `panic_data`  is expected to be a valid serialized byte array with an extra felt252 at the beginning, which is the BYTE_ARRAY_MAGIC. |
| [to_base_16_string](./openzeppelin_testing-common-to_base_16_string.md) | Converts a `felt252`  to a `base16`  string padded to 66 characters including the `0x`  prefix. |
| [to_base_16_string_no_padding](./openzeppelin_testing-common-to_base_16_string_no_padding.md) | Converts a `felt252`  to a `base16`  (hexadecimal) string without padding, but including the `0x` prefix. We need this because Starknet Foundry has a way of representing addresses and selectors that... |
| [assert_entrypoint_not_found_error](./openzeppelin_testing-common-assert_entrypoint_not_found_error.md) | Asserts that the syscall result of a call failed with an "Entrypoint not found" error, following the Starknet Foundry emitted error format. |

## [Traits](./openzeppelin_testing-common-traits.md)

| | |
|:---|:---|
| [IntoBase16StringTrait](./openzeppelin_testing-common-IntoBase16StringTrait.md) | — |

## [Impls](./openzeppelin_testing-common-impls.md)

| | |
|:---|:---|
| [FuzzableBool](./openzeppelin_testing-common-FuzzableBool.md) | An implementation of Fuzzable trait to support boolean parameters in fuzz tests. |
| [FuzzableContractAddress](./openzeppelin_testing-common-FuzzableContractAddress.md) | An implementation of Fuzzable trait to support ContractAddress parameters in fuzz tests. |
