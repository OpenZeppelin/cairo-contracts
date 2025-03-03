## Testing

> **NOTE:** This package is intended to be used only as a dev dependency. For this reason it is not included as part of the
`openzeppelin` main package, and it has its own versioning not pegged to the version of the library.

This crate provides various helper functions for declaring, deploying,
and testing smart contracts using the `snforge` toolchain from Starknet Foundry.

### Usage

The module isn’t part of the openzeppelin main package and to be accessible has to be added as a
separate dependency in the Scarb.toml file:

```cairo
[dev-dependencies]
openzeppelin_testing = "1.0.0"
```

Then it can be imported into tests:

```cairo
use openzeppelin_testing;
```

### API documentation

- [Summary](docs/openzeppelin_testing.md)

- [Index](docs/SUMMARY.md)

