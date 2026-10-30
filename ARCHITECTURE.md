# Architecture

OpenZeppelin Contracts for Cairo provides reusable components, interfaces, utilities and
contract presets for Starknet. Applications can depend on individual Scarb packages or use the
`openzeppelin` umbrella package. Components separate reusable contract behavior from the
application's choice of exposed API, authorization and composition.

[Coding conventions](GUIDELINES.md) and [contribution procedures](CONTRIBUTING.md) describe how
to work within this design.

## Repository layout

The root [Scarb.toml](Scarb.toml) defines the workspace. [src/lib.cairo](src/lib.cairo) re-exports
the contract library packages under the `openzeppelin` namespace.

| Path | Responsibility and dependencies |
| --- | --- |
| `packages/interfaces` | Shared Starknet ABI traits and dispatchers; depends on Starknet, without component implementations. |
| `packages/introspection` | SRC5 interface registration and queries, using the shared interfaces. |
| `packages/access` | Ownership and role-based access control; uses interfaces and introspection. |
| `packages/account` | Account validation and execution, signature schemes and SRC9 extensions; uses interfaces, introspection, utilities and corelib compatibility imports. |
| `packages/corelib_imports` | Isolates gated Cairo bounded-integer APIs needed by Falcon arithmetic. Its manifest uses edition `2023_10` because the pinned compiler exposes those APIs in that edition. |
| `packages/token` | Token standards and extensions, including vaults; uses access control, interfaces, introspection and utilities. |
| `packages/finance` | Vesting components built on access control, interfaces and token functionality. |
| `packages/governance` | Governor, votes, timelock and multisig components; composes access, token, introspection, interfaces and utilities. |
| `packages/security` | Initializable, pausable and reentrancy-guard components. |
| `packages/upgrades` | Internal class-replacement operations, using Starknet syscalls. |
| `packages/utils` | Cryptography, execution, deployment, nonce and data-structure utilities. |
| `packages/merkle_tree` | Merkle proof and multiproof verification without a Starknet dependency. |
| `packages/presets` | Deployable contracts that compose components and define concrete initialization and authorization. |
| `packages/macros` | Rust procedural macros consumed through Scarb; tested with Cargo. Added directly by consumers that need macros. |
| `packages/testing` | Foundry test helpers for downstream users; a separate dev dependency with its own version and generated API docs. |
| `packages/test_common` | Repository test mocks, fixtures and shared assertions; depends on the implementations it exercises. |
| `scripts/` | Release support, class-hash generation, benchmarks and Falcon reference/generation checks. |
| `sncast_scripts/` | Deployment scripts with their own Scarb manifest. |
| `benches/` | Contract-size benchmark results used by CI. |
| `audits/` | Audit reports and their commit, version and scope index. |

Most packages inherit the workspace version. `openzeppelin_interfaces`, `openzeppelin_utils`
and `openzeppelin_testing` declare independent versions. Manifests are authoritative for
versions and dependency edges. Test-only dependencies may point back to implementation
packages; that does not make them runtime dependencies of deployed contracts.

## Component composition and public APIs

A `#[starknet::component]` module owns its storage, events and implementations. A consuming
contract includes it through `component!`, a `#[substorage(v0)]` field and a component event
variant. The contract explicitly embeds selected implementations using `#[abi(embed_v0)]`.
Mixins group commonly used implementations, including compatibility aliases where supported.
The [ERC20 preset](packages/presets/src/erc20.cairo) is a concrete example.

Internal implementations let a contract choose access rules for operations such as minting or
upgrading. Calling an internal operation does not itself establish application authorization.
For example, the ERC20 preset checks ownership before calling the upgrade component. Hooks and
immutable configuration traits let applications extend transitions without copying the
component implementation; empty hooks and default configurations serve the simple case.

## State and asset handling

Component storage is embedded in the consuming contract. Field names, types, substorage
placement and map keys determine how deployed state is interpreted. Changes to those elements
must be assessed for storage compatibility as well as source compatibility.

Token transitions centralize balance/supply accounting and event emission. Extensions attach
to the relevant hooks; transfer callbacks and external token calls can transfer control to
other contracts. Authorization, accounting order and reentrancy protections must therefore be
assessed across the composed contract. ERC20 amounts use `u256`; metadata such as decimals does
not change the unit stored in balances. Vault conversion and rounding behavior belongs to the
ERC4626 implementation and its tests, rather than a global rounding policy for all modules.

## Upgrades and versioning

[UpgradeableComponent](packages/upgrades/src/upgradeable.cairo) uses Starknet's class-replacement
syscall and emits an upgrade event. It rejects a zero class hash, while the consuming contract
supplies the authorization policy. Class replacement preserves the contract address and
storage; it does not prove that the new code interprets that storage compatibly.

Consumers must assess upgrade compatibility against their deployed layout and the selected
release's [compatibility guidance](https://docs.openzeppelin.com/contracts-cairo/4.x/backwards-compatibility).
A library version number alone is not proof that an existing contract can safely upgrade.
Install released package versions and use their matching documentation; `main` can contain
unreleased APIs. The release procedure lives in [RELEASING.md](RELEASING.md).

## Verification boundaries

Cairo unit tests live with each package, while shared mocks and deployed presets exercise
component integration and ABI behavior. Rust tests validate macro expansion and diagnostics.
Foundry coverage exercises the development profile. CI also runs fuzzing, generated-source
checks, release-profile Falcon tests and resource checks; commands live in
[CONTRIBUTING.md](CONTRIBUTING.md#verification).

Falcon's generated production NTT cannot be lowered by the pinned compiler in Foundry's
non-inlining source-coverage mode. Coverage therefore exercises the generic account path;
separate release tests verify production verifier paths and preset gas budgets. Local tests
and resource budgets do not establish target-network support: deployment and network behavior
need their own verification.

Audit boundaries are the exact commits and scopes in [audits/README.md](audits/README.md).
An audit of a release does not cover later changes on `main` or every downstream composition.
