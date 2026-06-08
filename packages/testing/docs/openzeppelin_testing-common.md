# common

<a href='https://github.com/OpenZeppelin/cairo-contracts/blob/e4c5e434fb1cf8890b0c6b577e194876449e1d48/packages/testing/src/lib.cairo#L1-L1'> [source code] </a>

Fully qualified path: [openzeppelin_testing](./openzeppelin_testing.md)::[common](./openzeppelin_testing-common.md)


## [Free functions](./openzeppelin_testing-common-free_functions.md)

| | |
|:---|:---|
| [panic_data_to_byte_array](./openzeppelin_testing-common-panic_data_to_byte_array.md) | Converts panic data into a string (ByteArray). `panic_data`  is expected to be a valid serialized byte array with an extra felt252 at the beginning, which is the BYTE_ARRAY_MAGIC. |
| [to_base_16_string](./openzeppelin_testing-common-to_base_16_string.md) | Converts a `felt252`  to a `base16`  string padded to 66 characters including the `0x`  prefix. |
| [to_base_16_string_no_padding](./openzeppelin_testing-common-to_base_16_string_no_padding.md) | Converts a `felt252`  to a `base16`  (hexadecimal) string without padding, but including the `0x` prefix. We need this because Starknet Foundry has a way of representing addresses and selectors that... |

## [Traits](./openzeppelin_testing-common-traits.md)

| | |
|:---|:---|
| [IntoBase16StringTrait](./openzeppelin_testing-common-IntoBase16StringTrait.md) | — |
