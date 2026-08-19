## Account

> **NOTE:** This document is better viewed at [https://docs.openzeppelin.com/contracts-cairo/api/account](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account)

This crate provides components for building account contracts that interact with the network.

- `AccountComponent` validates transactions from signatures over the
  [STARK Curve](https://docs.starknet.io/architecture-and-concepts/cryptography/#the_stark_curve).

- `EthAccountComponent` validates transactions from signatures over the
  [Secp256k1 curve](https://en.bitcoin.it/wiki/Secp256k1).

- `Falcon512AccountComponent` provides felt-array public-key management and account behavior for
  canonical Falcon-512 public keys. It is generic over `Falcon512SignatureVerifier` and supports
  two supplied SHAKE-256 strategies:

  - `Falcon512ShakeVerifier` validates a 60-felt signature containing a verifier-checked
    polynomial-product hint to reduce on-chain execution cost.

  - `Falcon512ShakeDirectVerifier` validates a 31-felt signature and recomputes the polynomial
    product on-chain.

> **WARNING:** The supplied Falcon verifiers target the verification relation and SHAKE-256
> hash-to-point from the FALCON submission selected by NIST. Their public-key and signature
> encodings are contract-specific, and they are not FN-DSA (FIPS 206) implementations.

The Falcon component implements invoke, declare, and deploy-account validation,
signature validation, and owner-authorized felt-array public-key management. Contracts embed it
with `SRC5Component` and one of the supplied verifier strategies. Ready-to-deploy variants with
SRC9 outside execution and class upgrades are provided by the `openzeppelin_presets` package.

Falcon accounts support owner-authorized key rotation by executing a self-call to
`set_public_key` or `setPublicKey`. As with the STARK-curve and Secp256k1 accounts, the
current key authorizes the outer account transaction and the new key signs a
domain-separated ownership-acceptance message. Rotation keeps the same account address.
Because the current key authorizes the outer transaction, rotating a lost or unavailable key
requires an independent recovery mechanism. The upgradeable presets can adopt verifier changes at
the same account address through a self-authorized class upgrade.

### Build profile

Build deployable Falcon preset artifacts from this repository with
`scarb --release build -p openzeppelin_presets`. The workspace dev profile produces Falcon Sierra
artifacts that cannot be lowered to CASM. Only the workspace's `target/release` Falcon preset
artifacts are suitable for declaration. A consuming project that embeds the component must
likewise use a declaration profile with inlining enabled.

### Maintainer workflow: generated Falcon NTT sources

The Falcon root tables, bit-reversal table, and unrolled production transform are derived and
checked by `scripts/falcon_512/generate_ntt.py`. Regenerate them from the repository root and verify
the checked-in output with:

```sh
python3 scripts/falcon_512/generate_ntt.py --write
git diff --exit-code -- packages/account/src/falcon_512/ntt
```

### Interfaces

- [`ISRC6`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#ISRC6)
- [`IFeltArrayDeployable`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#IFeltArrayDeployable)
- [`IFeltArrayPublicKey`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#IFeltArrayPublicKey)
- [`IFeltArrayPublicKeyCamel`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#IFeltArrayPublicKeyCamel)
- [`ISRC9_V2`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#ISRC9_V2)

### Components

- [`AccountComponent`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#AccountComponent)
- [`EthAccountComponent`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#EthAccountComponent)
- [`Falcon512AccountComponent`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#Falcon512AccountComponent)
- [`SRC9Component`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#SRC9Component)
