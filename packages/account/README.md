## Account

> **NOTE:** This document is better viewed at [https://docs.openzeppelin.com/contracts-cairo/api/account](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account)

This crate provides components for building account contracts that interact with the network.

- `AccountComponent` validates transactions from signatures over the
  [STARK Curve](https://docs.starknet.io/architecture-and-concepts/cryptography/#the_stark_curve).

- `EthAccountComponent` validates transactions from signatures over the
  [Secp256k1 curve](https://en.bitcoin.it/wiki/Secp256k1).

- `MultisigAccountComponent` validates transactions when a configured quorum of registered
  STARK-curve signers authorizes the same hash.

### Multisig signatures

`MultisigAccountComponent` accepts the canonical felt-array encoding
`[1, n, public_key_1, r_1, s_1, ..., public_key_n, r_n, s_n]`. The first felt is the signature
format version, and `n` is the number of signer records that follow. Signer public keys must be
strictly increasing, which makes every signer distinct, and every `(r, s)` pair must be a valid
STARK-curve signature for the same hash from its associated registered signer.

A signature is valid when its header matches the encoded records, `n` is at least the account
quorum and no greater than the registered signer count, and every supplied record is valid.
`is_valid_signature` returns `starknet::VALIDATED` for a valid signature and `0` otherwise. The
`invoke`, `declare`, and `deploy_account` validation entry points return `starknet::VALIDATED` for
a valid signature and revert when validation fails.

Signature validation verifies every supplied signer record, so its execution cost grows linearly
with `n`. Callers can minimize validation work by supplying the smallest valid signer quorum.
Configure a quorum that fits within Starknet account-validation resource limits: an impractically
high required quorum can prevent the account from authorizing a configuration recovery.

Signer additions, removals, replacements, and quorum changes accept calls only from the account
itself. The current quorum can therefore manage the account configuration through an authorized
account transaction. The governance multisig coordinates proposals and confirmations, while
`MultisigAccountComponent` authenticates account transactions during SRC6 validation.

### Interfaces

- [`ISRC6`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#ISRC6)
- [`IMultisigAccount`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#IMultisigAccount)
- [`IMultisigDeployable`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#IMultisigDeployable)
- [`ISRC9_V2`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#ISRC9_V2)

### Components

- [`AccountComponent`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#AccountComponent)
- [`EthAccountComponent`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#EthAccountComponent)
- [`MultisigAccountComponent`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#MultisigAccountComponent)
- [`SRC9Component`](https://docs.openzeppelin.com/contracts-cairo/3.x/api/account#SRC9Component)
