## Account

> **NOTE:** This document is better viewed at [https://docs.openzeppelin.com/contracts-cairo/api/account](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account)

This crate provides components to implement account contracts that can be used for interacting with the network.

- `Account` validates transactions from signatures over the
[STARK Curve](https://docs.starknet.io/architecture-and-concepts/cryptography/#the_stark_curve).

- `EthAccount` validates transactions from signatures over the
[Secp256k1 curve](https://en.bitcoin.it/wiki/Secp256k1).

- `Falcon512ShakeAccount` validates the Falcon-512 verification relation from the
  FALCON submission selected by NIST, using SHAKE-256 hash-to-point. Its
  contract-specific signature encoding includes a verifier-checked polynomial-product
  hint to reduce on-chain execution cost.

- `Falcon512ShakeDirectAccount` validates the same relation without the hint by
  recomputing the polynomial product on-chain.

> **WARNING:** These accounts implement the verification relation and SHAKE-256 hash-to-point
> used by FALCON as submitted to NIST. Their felt encodings are contract-specific, and the
> accounts do not claim conformance with FN-DSA/FIPS 206, which remains in development.

Both Falcon accounts support owner-authorized key rotation by executing a self-call to
`set_public_key` or `setPublicKey`. As with the STARK-curve and Secp256k1 accounts, the
current key authorizes the outer account transaction and the new key signs a
domain-separated ownership-acceptance message. Rotation keeps the same account address.
This is not lost-key recovery: if the current private key is unavailable, these
entrypoints cannot rotate it, and the contracts include no independent recovery mechanism.
Changing the verifier code is a separate class-upgrade concern; these concrete contracts
do not embed an upgrade component.

### Interfaces

- [`ISRC6`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#ISRC6)
- `IFeltArrayDeployable`
- `IFeltArrayPublicKey`
- `IFeltArrayPublicKeyCamel`
- [`ISRC9_V2`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#ISRC9_V2)

### Components

- [`AccountComponent`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#AccountComponent)
- [`EthAccountComponent`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#EthAccountComponent)
- [`SRC9Component`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#SRC9Component)
