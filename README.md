# OpenZeppelin Contracts for Cairo

[![Tests and linter](https://github.com/OpenZeppelin/cairo-contracts/actions/workflows/python-app.yml/badge.svg)](https://github.com/OpenZeppelin/cairo-contracts/actions/workflows/python-app.yml)

**A library for secure smart contract development** written in Cairo for [StarkNet](https://starkware.co/product/starknet/), a decentralized ZK Rollup.

## Security Advisory ⚠️

- A critical [vulnerability](https://github.com/OpenZeppelin/cairo-contracts/issues/344) was found in an **unreleased** version of the Account contract. It was [introduced in March 25th](https://github.com/OpenZeppelin/cairo-contracts/pull/233) and has been [patched as of June 1st](https://github.com/OpenZeppelin/cairo-contracts/pull/347). If you copied the Account contract code into your project during that period, please update to the patched version. Note that 0.1.0 users are not affected.

## Usage

> ## ⚠️ WARNING! ⚠️
>
> This repo contains highly experimental code.
> Expect rapid iteration.
> **Use at your own risk.**

### First time?

Before installing Cairo on your machine, you need to install `gmp`:

```bash
sudo apt install -y libgmp3-dev # linux
brew install gmp # mac
```

> If you have any troubles installing gmp on your Apple M1 computer, [here’s a list of potential solutions](https://github.com/OpenZeppelin/nile/issues/22).

### Set up your project

Create a directory for your project, then `cd` into it and create a Python virtual environment.

```bash
mkdir my-project
cd my-project
python3 -m venv env
source env/bin/activate
```

Install the [Nile](https://github.com/OpenZeppelin/nile) development environment and then run `init` to kickstart a new project. Nile will create the project directory structure and install [the Cairo language](https://www.cairo-lang.org/docs/quickstart.html), a [local network](https://github.com/Shard-Labs/starknet-devnet/), and a [testing framework](https://docs.pytest.org/en/6.2.x/).

```bash
pip install cairo-nile
nile init
```

### Install the library

```bash
pip install openzeppelin-cairo-contracts
```

### Use a basic preset

Presets are ready-to-use contracts that you can deploy right away. They also serve as examples of how to use library modules. [Read more about presets](docs/Extensibility.md#presets).

```cairo
# contracts/MyToken.cairo

%lang starknet

from openzeppelin.token.erc20.ERC20 import constructor
```

Compile and deploy it right away:

```bash
nile compile

nile deploy MyToken <name> <symbol> <decimals> <initial_supply> <recipient> --alias my_token
```

> Note that `<initial_supply>` is expected to be two integers i.e. `1` `0`. See [Uint256](docs/Utilities.md#Uint256) for more information.

### Write a custom contract using library modules

[Read more about libraries](docs/Extensibility.md#libraries).

```cairo
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from openzeppelin.security.pausable import Pausable
from openzeppelin.token.erc20.library import ERC20

(...)

@external
func transfer{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: Uint256) -> (success: felt):
    Pausable.assert_not_paused()
    ERC20.transfer(recipient, amount)
    return (TRUE)
end
```

## Learn

### Contract documentation

- [Account](docs/Account.md)
- [ERC20](docs/ERC20.md)
- [ERC721](docs/ERC721.md)
- [Contract extensibility pattern](docs/Extensibility.md)
- [Proxies and upgrades](docs/Proxies.md)
- [Security](docs/Security.md)
- [Utilities](docs/Utilities.md)

### Cairo

- [StarkNet official documentation](https://www.cairo-lang.org/docs/hello_starknet/index.html#hello-starknet)
- [Cairo language documentation](https://www.cairo-lang.org/docs/hello_cairo/index.html#hello-cairo)
- Perama's [Cairo by example](https://perama-v.github.io/cairo/by-example/)
- [Cairo 101 workshops](https://www.youtube.com/playlist?list=PLcIyXLwiPilV5RBZj43AX1FY4FJMWHFTY)

### Nile

- [Getting started with StarkNet using Nile](https://medium.com/coinmonks/starknet-tutorial-for-beginners-using-nile-6af9c2270c15)
- [How to manage smart contract deployments with Nile](https://medium.com/@martriay/manage-your-starknet-deployments-with-nile-%EF%B8%8F-e849d40546dd)

## Development

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

Install dependencies:

```bash
python -m pip install .
```

### Compile the contracts

```bash
nile compile --directory src

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
platform linux -- Python 3.7.2, pytest-7.1.2, py-1.11.0, pluggy-1.0.0
rootdir: /home/readme/cairo-contracts, configfile: tox.ini
plugins: asyncio-0.18.3, xdist-2.5.0, forked-1.4.0, web3-5.29.0, typeguard-2.13.3
asyncio: mode=auto
gw0 [185] / gw1 [185]
......................................................................................
......................................................................................
............    [100%]
```

### Run Tests in Docker

For M1 users or those who are having trouble with library/python versions you can alternatively run the tests within a docker container. Using the following as a Dockerfile placed in the root directory of the project:

```dockerfile
FROM python:3.7

RUN pip install tox
RUN mkdir cairo-contracts
COPY . cairo-contracts
WORKDIR cairo-contracts
ENTRYPOINT tox
```

After its placed there run:

```bash
docker build -t cairo-tests .
docker run cairo-tests
```

### Parallel Testing

This repo utilizes the [pytest-xdist](https://pytest-xdist.readthedocs.io/en/latest/) plugin which runs tests in parallel. This feature increases testing speed; however, conflicts with a shared state can occur since tests do not run in order. To overcome this, independent cached versions of contracts being tested should be provisioned to each test case. Here's a simple fixture example:

```python
from utils import get_contract_class, cached_contract

@pytest.fixture(scope='module')
def foo_factory():
    # get contract class
    foo_cls = get_contract_class('path/to/foo.cairo')

    # deploy contract
    starknet = await Starknet.empty()
    foo = await starknet.deploy(contract_class=foo_cls)

    # copy the state and cache contract
    state = starknet.state.copy()
    cached_foo = cached_contract(state, foo_cls, foo)

    return cached_foo
```

See [Memoization](docs/Utilities.md#memoization) in the Utilities documentation for a more thorough example on caching contracts.

> Note that this does not apply for stateless libraries such as SafeMath.

## Security

> ⚠️ Warning! ⚠️
> This project is still in a very early and experimental phase. It has never been audited nor thoroughly reviewed for security vulnerabilities. Do not use in production.

Refer to [SECURITY.md](SECURITY.md) for more details.

## Contribute

OpenZeppelin Contracts for Cairo exists thanks to its contributors. There are many ways you can participate and help build high quality software. Check out the [contribution](CONTRIBUTING.md) guide!

### Markdown linter

To keep the markdown files neat and easy to edit, we utilize DavidAnson's [markdownlint](https://github.com/DavidAnson/markdownlint) linter. You can find the listed rules [here](https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md). Note that the following rules are disabled:

- `MD013: line length`

  - to enable paragraphs without internal line breaks

- `MD033: inline HTML`

  - to enable .md files to have duplicate headers and separate them by identifiers

Before creating a PR, check that documentation changes are compliant with our markdown rules by running:

```bash
tox -e lint
```

## License

OpenZeppelin Contracts for Cairo is released under the [MIT License](LICENSE).
