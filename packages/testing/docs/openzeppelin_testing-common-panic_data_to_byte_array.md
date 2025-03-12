# panic_data_to_byte_array

Converts panic data into a string (ByteArray).`panic_data` is expected to be a valid serialized byte array with an extra felt252 at the beginning, which is the BYTE_ARRAY_MAGIC.

Fully qualified path: `openzeppelin_testing::common::panic_data_to_byte_array`

```rust
pub fn panic_data_to_byte_array(panic_data: Array<felt252>) -> ByteArray
```

