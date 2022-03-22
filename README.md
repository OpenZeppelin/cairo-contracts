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
nile compile --directory openzeppelin

🤖 Compiling all Cairo contracts in the openzeppelin directory
🔨 Compiling openzeppelin/introspection/ERC165.cairo
🔨 Compiling openzeppelin/introspection/IERC165.cairo
🔨 Compiling openzeppelin/token/erc721/ERC721_Mintable_Burnable.cairo
🔨 Compiling openzeppelin/token/erc721/ERC721_Mintable_Pausable.cairo
🔨 Compiling openzeppelin/token/erc721/library.cairo
🔨 Compiling openzeppelin/token/erc721/interfaces/IERC721_Metadata.cairo
🔨 Compiling openzeppelin/token/erc721/interfaces/IERC721.cairo
🔨 Compiling openzeppelin/token/erc721/interfaces/IERC721_Receiver.cairo
🔨 Compiling openzeppelin/token/erc721/utils/ERC721_Holder.cairo
🔨 Compiling openzeppelin/token/erc20/ERC20_Mintable.cairo
🔨 Compiling openzeppelin/token/erc20/ERC20.cairo
🔨 Compiling openzeppelin/token/erc20/library.cairo
🔨 Compiling openzeppelin/token/erc20/ERC20_Pausable.cairo
🔨 Compiling openzeppelin/token/erc20/interfaces/IERC20.cairo
🔨 Compiling openzeppelin/token/erc721_enumerable/ERC721_Enumerable_Mintable_Burnable.cairo
🔨 Compiling openzeppelin/token/erc721_enumerable/library.cairo
🔨 Compiling openzeppelin/token/erc721_enumerable/interfaces/IERC721_Enumerable.cairo
🔨 Compiling openzeppelin/security/pausable.cairo
🔨 Compiling openzeppelin/security/safemath.cairo
🔨 Compiling openzeppelin/security/initializable.cairo
🔨 Compiling openzeppelin/access/ownable.cairo
🔨 Compiling openzeppelin/account/IAccount.cairo
🔨 Compiling openzeppelin/account/Account.cairo
🔨 Compiling openzeppelin/account/AddressRegistry.cairo
🔨 Compiling openzeppelin/utils/constants.cairo
✅ Done
```

### Run tests

Run tests using [tox](https://tox.wiki/en/latest/), tox automatically creates an isolated testing environment:

```bash
tox

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

## Learn

### Contract documentation
* [Account](docs/Account.md)
* [ERC20](docs/ERC20.md)
* [ERC721](docs/ERC721.md)
* [Contract extensibility pattern](docs/Extensibility.md)
* [Proxies and upgrades](docs/Proxies.md)
* [Utilities](docs/Utilities.md)
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
