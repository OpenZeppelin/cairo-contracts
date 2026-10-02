# OpenZeppelin Contracts for Cairo

[![Lint and test](https://github.com/OpenZeppelin/cairo-contracts/actions/workflows/test.yml/badge.svg)](https://github.com/OpenZeppelin/cairo-contracts/actions/workflows/test.yml)
[![License](https://img.shields.io/github/license/OpenZeppelin/cairo-contracts)](https://github.com/OpenZeppelin/cairo-contracts/blob/main/LICENSE)
[![Docs](https://img.shields.io/badge/docs-%F0%9F%93%84-yellow)](https://docs.openzeppelin.com/contracts-cairo/)

**A library for secure smart contract development** written in Cairo for [Starknet](https://starkware.co/product/starknet/), a decentralized ZK Rollup.

> [!TIP]
> :mage: **Not sure how to get started?** Check out [Contracts Wizard for Cairo](https://wizard.openzeppelin.com/cairo) — an interactive smart contract generator.

## Usage

### Prepare the environment

Install [Scarb](https://docs.swmansion.com/scarb/download), which includes the Cairo compiler.
Contracts for Cairo 4.x uses Scarb and Cairo **2.18.0**. For repository development and testing,
use the toolchain pinned in [Scarb.toml](Scarb.toml) and follow
[Development setup](CONTRIBUTING.md#development-setup).

### Set up your project

Create a new project and `cd` into it.

```bash
scarb new my_project && cd my_project
```

The contents of `my_project` should look like this:

```bash
$ ls

Scarb.toml src
```

### Install the library

Edit `Scarb.toml` and add:

```toml
[dependencies]
openzeppelin = "4.0.1"
```

The umbrella package exposes the contract libraries. Add an individual package to compile only
the modules your application needs:

```toml
[dependencies]
openzeppelin_token = "4.0.1"
```

Build the project to download it:

```bash
scarb build
```

Use [published releases](https://github.com/OpenZeppelin/cairo-contracts/releases) and the
documentation for the version you install. The `main` branch can contain unreleased changes.

### Using the library

Open `src/lib.cairo` and write your contract.

With the `openzeppelin_token` dependency above, this is an ERC20-compliant contract:

```cairo
#[starknet::contract]
mod MyToken {
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl, DefaultConfig};
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    // ERC20 Mixin
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        let name = "MyToken";
        let symbol = "MTK";

        self.erc20.initializer(name, symbol);
        self.erc20.mint(recipient, initial_supply);
    }
}
```

## Packages

The `openzeppelin` package re-exports the contract libraries. Package READMEs list their public
modules; package manifests specify their versions. `openzeppelin_interfaces`,
`openzeppelin_utils` and `openzeppelin_testing` have independent versions.

| Package | Purpose |
| --- | --- |
| [`openzeppelin_access`](packages/access/README.md) | Ownership and role-based permissions |
| [`openzeppelin_account`](packages/account/README.md) | Starknet accounts and account extensions |
| [`openzeppelin_finance`](packages/finance/README.md) | Vesting |
| [`openzeppelin_governance`](packages/governance/README.md) | Governor, votes, timelock and multisig |
| [`openzeppelin_interfaces`](packages/interfaces/README.md) | Shared ABI traits and dispatchers |
| [`openzeppelin_introspection`](packages/introspection/README.md) | SRC5 interface introspection |
| [`openzeppelin_merkle_tree`](packages/merkle_tree/README.md) | Merkle proof verification |
| [`openzeppelin_presets`](packages/presets/README.md) | Deployable contract presets |
| [`openzeppelin_security`](packages/security/README.md) | Initialization, pausing and reentrancy protection |
| [`openzeppelin_token`](packages/token/README.md) | Token standards and extensions |
| [`openzeppelin_upgrades`](packages/upgrades/README.md) | Contract class upgrades |
| [`openzeppelin_utils`](packages/utils/README.md) | Cryptography, deployment and data structures |
| [`openzeppelin_macros`](packages/macros/README.md) | Procedural macros; add as a separate dependency |
| [`openzeppelin_testing`](packages/testing/README.md) | Foundry helpers; add as a separate dev dependency |

## Learn

### Documentation

Check out the [full documentation site](https://docs.openzeppelin.com/contracts-cairo)!
AI integrators can start with [llms.txt](llms.txt) for package catalogs, examples, API references
and audit reports.

### Cairo

- [Cairo book](https://book.cairo-lang.org/)
- [Cairo language documentation](https://docs.cairo-lang.org/)
- [Starknet documentation](https://docs.starknet.io/)
- [Cairopractice](https://cairopractice.com/)

### Tooling

- [Scarb](https://docs.swmansion.com/scarb)

## Development

> [!NOTE]
> You can track our roadmap and future milestones in our [Github Project](https://github.com/orgs/OpenZeppelin/projects/29/).

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, build, test and coverage commands, commit and
PR conventions, and documentation updates. Read the [Code of Conduct](CODE_OF_CONDUCT.md),
[Cairo guidelines](GUIDELINES.md), and [architecture](ARCHITECTURE.md) before contributing.
Release maintainers should follow [RELEASING.md](RELEASING.md).

## Security

This project is maintained by OpenZeppelin with the goal of providing a secure and reliable library of smart contract components
for the Starknet ecosystem. We address security through risk management in various areas such as engineering and open source best
practices, scoping and API design, multi-layered review processes, and incident response preparedness.

Refer to [SECURITY.md](SECURITY.md) for more details.

The [audit index](audits/README.md) lists reports with their audited commits and scope.

Smart contracts are an evolving technology and carry a high level of technical risk and uncertainty. Although OpenZeppelin is well known for its security audits, using OpenZeppelin Contracts for Cairo is not a substitute for a security audit.

## License

OpenZeppelin Contracts for Cairo is released under the [MIT License](LICENSE).
