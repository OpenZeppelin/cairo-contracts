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
Use the same verifier strategy for initialization and every embedded account implementation.
Call the initializer only from the constructor; like the other account components, it has no
reinitialization guard.

### Key and signature encoding

Public keys contain 512 canonical residues in `[0, 12289)` in the verifier's **NTT evaluation
order**, packed into 29 felts. A coefficient-domain Falcon public key must be transformed before
packing. Canonical packing alone does not prove that a key is usable or that its secret key is
known. Verify a signature with the intended key before deployment, especially when deploying
through a constructor without deploy-account validation.

The evaluation points are `(r, 12289 - r)` for each root `r` in the degree-512
[forward root table](src/falcon_512/ntt/roots_felt.cairo), in table order.

Each full packed felt holds 18 residues: nine base-12289 digits in its low 128 bits and nine in
its high 128 bits, least-significant digit first within each limb. The last felt holds eight
digits in the low limb and zero in the high limb. Both full limbs must be below `12289^9`, and
the final limb must be below `12289^8`.

The direct signature is `pack(s1) || salt_a || salt_b` (31 felts). The hint signature appends
`pack(s1 * h mod (x^512 + 1, 12289))` (60 felts). Signature polynomials use coefficient order,
with negative coefficients represented modulo 12289. Each salt felt encodes 20 bytes in
little-endian order. SHAKE-256 absorbs `salt_a[20 LE] || salt_b[20 LE] || message_hash[32 LE]`;
its output is read as big-endian 16-bit words, discarding words at least 61445 and reducing the
others modulo 12289 until 512 coefficients are available.

The two signature layouts authenticate the same message: removing a valid hint signature's
29-felt product suffix gives a direct signature. Do not use signature bytes as a unique message ID.

### Key rotation

Falcon accounts support owner-authorized key rotation by executing a self-call to
`set_public_key` or `setPublicKey`. As with the STARK-curve and Secp256k1 accounts, the
current key authorizes the outer account transaction and the new key signs a
domain-separated ownership-acceptance message. Rotation keeps the same account address.
Because the current key authorizes the outer transaction, rotating a lost or unavailable key
requires an independent recovery mechanism. The upgradeable presets can adopt verifier changes at
the same account address through a self-authorized class upgrade.

Ownership acceptance follows the existing account protocol: the proof binds the account address
and current-owner GUID, not a chain ID, nonce, or expiry. The current owner must still authorize
every rotation; acceptance proofs are not one-time authorizations.

### Build profile

Build deployable Falcon preset artifacts from this repository with
`scarb --release build -p openzeppelin_presets`. The workspace dev profile produces Falcon Sierra
artifacts that cannot be lowered to CASM. Only the workspace's `target/release` Falcon preset
artifacts are suitable for declaration. A consuming project that embeds the component must
likewise use a declaration profile with inlining enabled.

The `openzeppelin_corelib_imports` dependency exposes internal, unstable Cairo APIs through an
edition-2023 compatibility package. Compiler upgrades require rebuilding, testing, and checking
resource limits again. A successful local build does not verify a public network's supported
Sierra version or permitted libfuncs.

### Validation resources

With Scarb 2.18.0 and Starknet Foundry 0.63.0, the reference-vector transaction validations use
approximately 45.6 million Sierra gas for the hint strategy and 55.5 million for direct. Against
Starknet's [documented 100 million validation-gas limit](https://docs.starknet.io/learn/cheatsheets/chain-info),
that leaves roughly 54% and 44% headroom for these vectors. These measurements are not worst-case
bounds or public-network deployment checks. Measure the complete validation path when adding
guardians, multisignature logic, or other account features, and recheck after compiler or network
gas-schedule changes.

### Interfaces

- [`ISRC6`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#ISRC6)
- [`IFeltArrayDeployable`](../interfaces/src/account/accounts.cairo)
- [`IFeltArrayPublicKey`](../interfaces/src/account/accounts.cairo)
- [`IFeltArrayPublicKeyCamel`](../interfaces/src/account/accounts.cairo)
- [`ISRC9_V2`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#ISRC9_V2)

### Components

- [`AccountComponent`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#AccountComponent)
- [`EthAccountComponent`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#EthAccountComponent)
- [`Falcon512AccountComponent`](src/falcon_512/account.cairo)
- [`SRC9Component`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#SRC9Component)
