## Account

> **NOTE:** This document is better viewed at https://docs.openzeppelin.com/contracts-cairo/api/account

This crate provides components to implement account contracts that can be used for interacting with the network.

- `Account` validates transactions from signatures over the
[STARK Curve](https://docs.starknet.io/architecture-and-concepts/cryptography/stark-curve/).

- `EthAccount` validates transactions from signatures over the
[Secp256k1 curve](https://en.bitcoin.it/wiki/Secp256k1).

### Interfaces

- `ISRC6`

### Components

- `AccountComponent`
- `EthAccountComponent`
