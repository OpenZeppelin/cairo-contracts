# SerializedSigning

A helper trait that facilitates converting a signature into a serialized format.

Fully qualified path: `openzeppelin_testing::signing::SerializedSigning`

```rust
pub trait SerializedSigning<KP, M>
```

## Trait functions

### serialized_sign

Fully qualified path: `openzeppelin_testing::signing::SerializedSigning::serialized_sign`

```rust
fn serialized_sign(self: KP, msg: M) -> Array<felt252>
```


