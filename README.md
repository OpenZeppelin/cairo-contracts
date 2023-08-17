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
openzeppelin = { git = "https://github.com/OpenZeppelin/cairo-contracts.git", tag = "v0.7.0" }
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

For example, this how to extend the ERC20 standard contract:

```cairo
#[starknet::contract]
mod MyToken {
    use starknet::ContractAddress;
    use openzeppelin::token::erc20::ERC20;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(
        ref self: ContractState,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        let name = 'MyToken';
        let symbol = 'MTK';

        let mut unsafe_state = ERC20::unsafe_new_contract_state();
        ERC20::InternalImpl::initializer(ref unsafe_state, name, symbol);
        ERC20::InternalImpl::_mint(ref unsafe_state, recipient, initial_supply);
    }

    #[external(v0)]
    fn name(self: @ContractState) -> felt252 {
        let unsafe_state = ERC20::unsafe_new_contract_state();
        ERC20::ERC20Impl::name(@unsafe_state)
    }

    ...
}
```

### Unsupported

`DualCase` dispatchers rely on Sierra's ability to catch a revert to resume execution. Currently, Starknet live chains (testnets and mainnet) don't implement that behavior. Starknet's testing framework does support it.

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

### Set up the project

Clone the repository:

```bash
git clone git@github.com:OpenZeppelin/cairo-contracts.git
```

`cd` into it and build:

```bash
$ cd cairo-contracts
$ scarb build

Compiling lib(openzeppelin) openzeppelin v0.7.0 (~/cairo-contracts/Scarb.toml)
Compiling starknet-contract(openzeppelin) openzeppelin v0.7.0 (~/cairo-contracts/Scarb.toml)
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

## Contribute

OpenZeppelin Contracts for Cairo exists thanks to its contributors. There are many ways you can participate and help build high quality software. Check out the [contribution](CONTRIBUTING.md) guide!

## License

OpenZeppelin Contracts for Cairo is released under the [MIT License](LICENSE).
