# OpenZeppelin Cairo Contracts
[![Tests and linter](https://github.com/OpenZeppelin/cairo-contracts/actions/workflows/python-app.yml/badge.svg)](https://github.com/OpenZeppelin/cairo-contracts/actions/workflows/python-app.yml)

**A library for secure smart contract development** written in Cairo for [StarkNet](https://starkware.co/product/starknet/), a decentralized ZK Rollup.

> ## ⚠️ WARNING! ⚠️
> This is repo contains highly experimental code.
> Expect rapid iteration.
> **Do not use in production.**

## Installation

### First time?

Before installing Cairo on your machine, you need to install `gmp`:
```bash
sudo apt install -y libgmp3-dev # linux
brew install gmp # mac
```
> If you have any troubles installing gmp on your Apple M1 computer, [here’s a list of potential solutions](https://github.com/OpenZeppelin/nile/issues/22).

### Set up the project
Clone the repository

```bash
git clone git@github.com:OpenZeppelin/cairo-contracts.git
```

`cd` into it and create a Python virtual environment:

```bash
cd cairo-contracts
python3 -m venv env
source env/bin/activate
```

Install the [Nile](https://github.com/OpenZeppelin/nile) dev environment and then run `install` to get [the Cairo language](https://www.cairo-lang.org/docs/quickstart.html), a [local network](https://github.com/Shard-Labs/starknet-devnet/), and a [testing framework](https://docs.pytest.org/en/6.2.x/).
```bash
pip install cairo-nile
nile install
```

## Usage

### Compile the contracts
```bash
nile compile

🤖 Compiling all Cairo contracts in the contracts directory
🔨 Compiling contracts/IAccount.cairo
🔨 Compiling contracts/Account.cairo
🔨 Compiling contracts/AddressRegistry.cairo
🔨 Compiling contracts/Initializable.cairo
🔨 Compiling contracts/Ownable.cairo
🔨 Compiling contracts/token/ERC721.cairo
🔨 Compiling contracts/token/ERC20.cairo
🔨 Compiling contracts/token/IERC20.cairo
✅ Done
```

### Run tests

```bash
pytest

====================== test session starts ======================
platform linux -- Python 3.7.2, pytest-6.2.5, py-1.11.0, pluggy-1.0.0
rootdir: /home/readme/cairo-contracts
plugins: asyncio-0.16.0, web3-5.24.0, typeguard-2.13.0
collected 19 items                                                                                               

tests/test_Account.py ....                                 [ 21%]
tests/test_AddressRegistry.py ..                           [ 31%]
tests/test_ERC20.py ..........                             [ 84%]
tests/test_Initializable.py .                              [ 89%]
tests/test_Ownable.py ..                                   [100%]
```

### Extending Cairo contracts

There's no clear contract extensibility pattern for Cairo smart contracts yet. In the meantime the best way to extend our contracts is copypasting and modifying them at your own risk. Remember this contracts are still under development and they have not gone through any audit or security review whatsoever.

- For Accounts, we suggest changing how `is_valid_signature` works to explore different signature validation schemes such as multisig, or some guardian logic like in [Argent's account](https://github.com/argentlabs/argent-contracts-starknet/blob/de5654555309fa76160ba3d7393d32d2b12e7349/contracts/ArgentAccount.cairo).
- For ERC20 tokens we suggest removing or protecting the `mint` method, temporarily in place for testing purposes. You can customize token name, symbol, and may be worth exploring pre/post transfer checks.


## Learn

### Contract documentation
* [Account](docs/Account.md)
* [ERC20](docs/ERC20.md)
* [ERC721](docs/ERC721.md)
### Cairo
* [StarkNet official documentation](https://www.cairo-lang.org/docs/hello_starknet/index.html#hello-starknet)
* [Cairo language documentation](https://www.cairo-lang.org/docs/hello_cairo/index.html#hello-cairo)
* Perama's [Cairo by example](https://perama-v.github.io/cairo/by-example/)
* [Cairo 101 workshops](https://www.youtube.com/playlist?list=PLcIyXLwiPilV5RBZj43AX1FY4FJMWHFTY)
### Nile
* [Getting started with StarkNet using Nile](https://medium.com/coinmonks/starknet-tutorial-for-beginners-using-nile-6af9c2270c15)
* [How to manage smart contract deployments with Nile](https://medium.com/@martriay/manage-your-starknet-deployments-with-nile-%EF%B8%8F-e849d40546dd)

## Security

This project is still in a very early and experimental phase. It has never been audited nor thoroughly reviewed for security vulnerabilities. Do not use in production.

Please report any security issues you find to security@openzeppelin.org.

## License

OpenZeppelin Cairo Contracts is released under the [MIT License](LICENSE).
