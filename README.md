# OpenZeppelin Contracts for Cairo

[![Lint and test](https://github.com/OpenZeppelin/cairo-contracts/actions/workflows/test.yml/badge.svg)](https://github.com/OpenZeppelin/cairo-contracts/actions/workflows/test.yml)

**A library for secure smart contract development** written in Cairo for [Starknet](https://starkware.co/product/starknet/), a decentralized ZK Rollup.

> **Warning**
> This repo contains highly experimental code.
> It has no code coverage checks.
> It hasn't been audited.
> **Use at your own risk.**

## Usage

> **Warning**
> Expect rapid iteration.
> Some contracts or features are not ready to be deployed.
> Check the **Unsupported** section below.

### Prepare the environment

Simply [install Cairo and scarb](https://docs.swmansion.com/scarb/download).

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

Edit `scarb.toml` and add:

```toml
[dependencies]
openzeppelin = { git = "https://github.com/OpenZeppelin/cairo-contracts.git", tag = "v0.8.0" }
```

Build the project to download it:

```bash
$ scarb build

Updating git repository https://github.com/OpenZeppelin/cairo-contracts
Compiling my_project v0.1.0 (~/my_project/Scarb.toml)
Finished release target(s) in 6 seconds
```

### Using the library

Open `src/lib.cairo` and write your contract.

For example, this is how to write an ERC20-compliant contract:

```cairo
#[starknet::contract]
mod MyToken {
    use openzeppelin::token::erc20::ERC20Component;
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
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
        let name = 'MyToken';
        let symbol = 'MTK';

        self.erc20.initializer(name, symbol);
        self.erc20._mint(recipient, initial_supply);
    }
}
```

### Unsupported

[`DualCase` dispatchers](https://docs.openzeppelin.com/contracts-cairo/0.8.0/interfaces#dualcase_dispatchers) rely on Sierra's ability to catch a revert to resume execution. Currently, Starknet live chains (testnets and mainnet) don't implement that behavior. Starknet's testing framework does support it.

## Learn

<!-- ### Documentation

Check out the [full documentation site](https://docs.openzeppelin.com/contracts-cairo)! Featuring:

- [Accounts](https://docs.openzeppelin.com/contracts-cairo/0.6.1/accounts)
- [ERC20](https://docs.openzeppelin.com/contracts-cairo/0.6.1/erc20)
- [ERC721](https://docs.openzeppelin.com/contracts-cairo/0.6.1/erc721)
- [ERC1155](https://docs.openzeppelin.com/contracts-cairo/0.6.1/erc1155)
- [Contract extensibility pattern](https://docs.openzeppelin.com/contracts-cairo/0.6.1/extensibility)
- [Proxies and upgrades](https://docs.openzeppelin.com/contracts-cairo/0.6.1/proxies)
- [Security](https://docs.openzeppelin.com/contracts-cairo/0.6.1/security)
- [Utilities](https://docs.openzeppelin.com/contracts-cairo/0.6.1/utilities) -->

### Cairo

- [Cairo book](https://book.cairo-lang.org/)
- [Cairo language documentation](https://docs.cairo-lang.org/)
- [Starknet book](https://book.starknet.io/)
- [Starknet documentation](https://docs.starknet.io/documentation/)
- [Cairo 1.0 mini-docs](https://github.com/Starknet-Africa-Edu/Cairo1.0)
- [Cairopractice](https://cairopractice.com/)

### Tooling

- [Scarb](https://docs.swmansion.com/scarb)

## Development

> **Note**: You can track our roadmap and future milestones in our [Github Project](https://github.com/orgs/OpenZeppelin/projects/29/).

OpenZeppelin Contracts for Cairo exists thanks to its contributors. There are many ways you can participate and help build high quality software, make sure to check out the [contribution](CONTRIBUTING.md) guide in advance.

### Set up the project

Clone the repository:

```bash
git clone git@github.com:OpenZeppelin/cairo-contracts.git
```

`cd` into it and build:

```bash
$ cd cairo-contracts
$ scarb build

Compiling lib(openzeppelin) openzeppelin v0.8.0 (~/cairo-contracts/Scarb.toml)
Compiling starknet-contract(openzeppelin) openzeppelin v0.8.0 (~/cairo-contracts/Scarb.toml)
Finished release target(s) in 16 seconds
```

### Run tests

```bash
scarb test
```

## Security

> ⚠️ Warning! ⚠️
> This project is still in a very early and experimental phase. It has never been audited nor thoroughly reviewed for security vulnerabilities. Do not use in production.

Refer to [SECURITY.md](SECURITY.md) for more details.

## License

OpenZeppelin Contracts for Cairo is released under the [MIT License](LICENSE).
