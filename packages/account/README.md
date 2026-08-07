## Account

> **NOTE:** This document is better viewed at [https://docs.openzeppelin.com/contracts-cairo/api/account](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account)

This crate provides components to implement account contracts that can be used for interacting with the network.

- `Account` validates transactions from signatures over the
[STARK Curve](https://docs.starknet.io/architecture-and-concepts/cryptography/#the_stark_curve).

- `EthAccount` validates transactions from signatures over the
[Secp256k1 curve](https://en.bitcoin.it/wiki/Secp256k1).

- `Falcon512ShakeAccount` validates legacy Falcon-512 submission-algorithm signatures
  using SHAKE-256 hash-to-point and a verifier-bound product hint.

- `Falcon512ShakeDirectAccount` validates the corresponding hint-free signatures by
  recomputing the polynomial product on-chain.

> **WARNING:** The Falcon accounts use immutable keys and a contract-specific felt encoding.
> They do not implement a finalized NIST FN-DSA standard. Key loss, key compromise, or a
> verifier revision requires migration to a new account address.

### Interfaces

- [`ISRC6`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#ISRC6)
- [`ISRC9_V2`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#ISRC9_V2)

### Components

- [`AccountComponent`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#AccountComponent)
- [`EthAccountComponent`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#EthAccountComponent)
- [`SRC9Component`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#SRC9Component)
