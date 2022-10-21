# OpenZeppelin Contracts for Cairo

[![Tests and linter](https://github.com/OpenZeppelin/cairo-contracts/actions/workflows/python-app.yml/badge.svg)](https://github.com/OpenZeppelin/cairo-contracts/actions/workflows/python-app.yml)

**A library for secure smart contract development** written in Cairo for [StarkNet](https://starkware.co/product/starknet/), a decentralized ZK Rollup.

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

Presets are ready-to-use contracts that you can deploy right away. They also serve as examples of how to use library modules. [Read more about presets](https://docs.openzeppelin.com/contracts-cairo/0.4.0/extensibility#presets).

```cairo
// contracts/MyToken.cairo

%lang starknet

from openzeppelin.token.erc20.presets.ERC20 import (
    constructor,
    name,
    symbol,
    totalSupply,
    decimals,
    balanceOf,
    allowance,
    transfer,
    transferFrom,
    approve,
    increaseAllowance,
    decreaseAllowance
)
```

Compile and deploy it right away:

```bash
nile compile

nile deploy MyToken <name> <symbol> <decimals> <initial_supply> <recipient> --alias my_token
```

> Note that `<initial_supply>` is expected to be two integers i.e. `1` `0`. See [Uint256](https://docs.openzeppelin.com/contracts-cairo/0.4.0/utilities#uint256) for more information.

### Write a custom contract using library modules

[Read more about libraries](https://docs.openzeppelin.com/contracts-cairo/0.4.0/extensibility#libraries).

```cairo
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from openzeppelin.security.pausable.library import Pausable
from openzeppelin.token.erc20.library import ERC20

(...)

@external
func transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient: felt, amount: Uint256
) -> (success: felt) {
    Pausable.assert_not_paused();
    return ERC20.transfer(recipient, amount);
}
```

## Learn

### Documentation

Check out the [full documentation site](https://docs.openzeppelin.com/contracts-cairo)! Featuring:

- [Accounts](https://docs.openzeppelin.com/contracts-cairo/0.4.0/accounts)
- [ERC20](https://docs.openzeppelin.com/contracts-cairo/0.4.0/erc20)
- [ERC721](https://docs.openzeppelin.com/contracts-cairo/0.4.0/erc721)
- [Contract extensibility pattern](https://docs.openzeppelin.com/contracts-cairo/0.4.0/extensibility)
- [Proxies and upgrades](https://docs.openzeppelin.com/contracts-cairo/0.4.0/proxies)
- [Security](https://docs.openzeppelin.com/contracts-cairo/0.4.0/security)
- [Utilities](https://docs.openzeppelin.com/contracts-cairo/0.4.0/utilities)

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

🤖 Compiling all Cairo contracts in the src directory
🔨 Compiling src/openzeppelin/token/erc20/library.cairo
🔨 Compiling src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo
🔨 Compiling src/openzeppelin/token/erc20/presets/ERC20Pausable.cairo
🔨 Compiling src/openzeppelin/token/erc20/presets/ERC20Upgradeable.cairo
🔨 Compiling src/openzeppelin/token/erc20/presets/ERC20.cairo
🔨 Compiling src/openzeppelin/token/erc20/IERC20.cairo
🔨 Compiling src/openzeppelin/token/erc721/enumerable/library.cairo
🔨 Compiling src/openzeppelin/token/erc721/library.cairo
🔨 Compiling src/openzeppelin/token/erc721/utils/ERC721Holder.cairo
🔨 Compiling src/openzeppelin/token/erc721/presets/ERC721MintablePausable.cairo
🔨 Compiling src/openzeppelin/token/erc721/presets/ERC721MintableBurnable.cairo
🔨 Compiling src/openzeppelin/token/erc721/presets/ERC721EnumerableMintableBurnable.cairo
🔨 Compiling src/openzeppelin/token/erc721/IERC721.cairo
🔨 Compiling src/openzeppelin/token/erc721/IERC721Metadata.cairo
🔨 Compiling src/openzeppelin/token/erc721/IERC721Receiver.cairo
🔨 Compiling src/openzeppelin/token/erc721/enumerable/IERC721Enumerable.cairo
🔨 Compiling src/openzeppelin/access/ownable/library.cairo
🔨 Compiling src/openzeppelin/security/reentrancyguard/library.cairo
🔨 Compiling src/openzeppelin/security/safemath/library.cairo
🔨 Compiling src/openzeppelin/security/pausable/library.cairo
🔨 Compiling src/openzeppelin/security/initializable/library.cairo
🔨 Compiling src/openzeppelin/utils/constants/library.cairo
🔨 Compiling src/openzeppelin/introspection/erc165/library.cairo
🔨 Compiling src/openzeppelin/introspection/erc165/IERC165.cairo
🔨 Compiling src/openzeppelin/upgrades/library.cairo
🔨 Compiling src/openzeppelin/upgrades/presets/Proxy.cairo
🔨 Compiling src/openzeppelin/account/library.cairo
🔨 Compiling src/openzeppelin/account/presets/EthAccount.cairo
🔨 Compiling src/openzeppelin/account/presets/Account.cairo
🔨 Compiling src/openzeppelin/account/presets/AddressRegistry.cairo
🔨 Compiling src/openzeppelin/account/IAccount.cairo
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

@pytest.fixture
def foo_factory():
    # get contract class
    foo_cls = get_contract_class('Foo')

    # deploy contract
    starknet = await Starknet.empty()
    foo = await starknet.deploy(contract_class=foo_cls)

    # copy the state and cache contract
    state = starknet.state.copy()
    cached_foo = cached_contract(state, foo_cls, foo)

    return cached_foo
```

See [Memoization](https://docs.openzeppelin.com/contracts-cairo/0.4.0/utilities#memoization) in the Utilities documentation for a more thorough example on caching contracts.

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
