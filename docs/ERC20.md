# ERC20

The ERC20 token standard is a specification for [fungible tokens](https://docs.openzeppelin.com/contracts/4.x/tokens#different-kinds-of-tokens), a type of token where all the units are exactly equal to each other. The `ERC20.cairo` contract implements an approximation of [EIP-20](https://eips.ethereum.org/EIPS/eip-20) in Cairo for StarkNet.

## Table of Contents

- [Interface](#interface)
  - [ERC20 compatibility](#erc20-compatibility)
- [Usage](#usage)
- [Extensibility](#extensibility)
- [Presets](#presets)
  - [ERC20 (basic)](#erc20-basic)
  - [ERC20_Mintable](#erc20_mintable)
  - [ERC20_Pausable](#erc20_pausable)
  - [ERC20_Upgradeable](#erc20_upgradeable)
- [API Specification](#api-specification)
  - [Methods](#methods)
    - [`name`](#name)
    - [`symbol`](#symbol)
    - [`decimals`](#decimals)
    - [`totalSupply`](#totalsupply)
    - [`balanceOf`](#balanceof)
    - [`allowance`](#allowance)
    - [`transfer`](#transfer)
    - [`transferFrom`](#transferfrom)
    - [`approve`](#approve)
  - [Events](#events)
    - [`Transfer (event)`](#transfer-event)
    - [`Approval (event)`](#approval-event)

## Interface

```cairo
@contract_interface
namespace IERC20:
    func name() -> (name: felt):
    end

    func symbol() -> (symbol: felt):
    end

    func decimals() -> (decimals: felt):
    end

    func totalSupply() -> (totalSupply: Uint256):
    end

    func balanceOf(account: felt) -> (balance: Uint256):
    end

    func allowance(owner: felt, spender: felt) -> (remaining: Uint256):
    end

    func transfer(recipient: felt, amount: Uint256) -> (success: felt):
    end

    func transferFrom(
            sender: felt,
            recipient: felt,
            amount: Uint256
        ) -> (success: felt):
    end

    func approve(spender: felt, amount: Uint256) -> (success: felt):
    end
end
```

### ERC20 compatibility

Although StarkNet is not EVM compatible, this implementation aims to be as close as possible to the ERC20 standard, in the following ways:

- it uses Cairo's `uint256` instead of `felt`
- it returns `TRUE` as success
- it accepts a `felt` argument for `decimals` in the constructor calldata with a max value of 2^8 (imitating `uint8` type)
- it makes use of Cairo's short strings to simulate `name` and `symbol`

But some differences can still be found, such as:

- `transfer`, `transferFrom` and `approve` will never return anything different from `TRUE` because they will revert on any error
- function selectors are calculated differently between [Cairo](https://github.com/starkware-libs/cairo-lang/blob/7712b21fc3b1cb02321a58d0c0579f5370147a8b/src/starkware/starknet/public/abi.py#L25) and [Solidity](https://solidity-by-example.org/function-selector/)

## Usage

Use cases go from medium of exchange currency to voting rights, staking, and more.

Considering that the constructor method looks like this:

```python
func constructor(
    name: felt,               # Token name as Cairo short string
    symbol: felt,             # Token symbol as Cairo short string
    decimals: felt            # Token decimals (usually 18)
    initial_supply: Uint256,  # Amount to be minted
    recipient: felt           # Address where to send initial supply to
):
```

To create a token you need to deploy it like this:

```python
erc20 = await starknet.deploy(
    "contracts/token/ERC20.cairo",
    constructor_calldata=[
        str_to_felt("Token"),     # name
        str_to_felt("TKN"),       # symbol
        18,                       # decimals
        (1000, 0),                # initial supply
        account.contract_address  # recipient
    ]
)
```

As most StarkNet contracts, it expects to be called by another contract and it identifies it through `get_caller_address` (analogous to Solidity's `this.address`). This is why we need an Account contract to interact with it. For example:

```python
signer = MockSigner(PRIVATE_KEY)
amount = uint(100)

account = await starknet.deploy(
    "contracts/Account.cairo",
    constructor_calldata=[signer.public_key]
)

await signer.send_transaction(account, erc20.contract_address, 'transfer', [recipient_address, *amount])
```

## Extensibility

ERC20 contracts can be extended by following the [extensibility pattern](../docs/Extensibility.md#the-pattern). The basic idea behind integrating the pattern is to import the requisite ERC20 methods from the ERC20 library and incorporate the extended logic thereafter. For example, let's say you wanted to implement a pausing mechanism. The contract should first import the ERC20 methods and the extended logic from the [pausable library](../src/openzeppelin/security/pausable.cairo) i.e. `Pausable_pause`, `Pausable_unpause`. Next, the contract should expose the methods with the extended logic therein like this:

```python
@external
func transfer{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: Uint256) -> (success: felt):
    Pausable_when_not_paused()            # imported extended logic
    ERC20_transfer(recipient, amount)     # imported library method
    return (TRUE)
end
```

Note that extensibility does not have to be only library-based like in the above example. For instance, an ERC20 contract with a pausing mechanism can define the pausing methods directly in the contract or even import the `pausable` methods from the library and tailor them further.

Some other ways to extend ERC20 contracts may include:

- Implementing a minting mechanism
- Creating a timelock
- Adding roles such as owner or minter

For full examples of the extensibility pattern being used in ERC20 contracts, see [Presets](#presets).

## Presets

The following contract presets are ready to deploy and can be used as-is for quick prototyping and testing. Each preset mints an initial supply which is especially necessary for presets that do not expose a `mint` method.

### ERC20 (basic)

The [`ERC20`](../src/openzeppelin/token/erc20/ERC20.cairo) preset offers a quick and easy setup for deploying a basic ERC20 token.

### ERC20_Mintable

The [`ERC20_Mintable`](../src/openzeppelin/token/erc20/ERC20_Mintable.cairo) preset allows the contract owner to mint new tokens.

### ERC20_Pausable

The [`ERC20_Pausable`](../src/openzeppelin/token/erc20/ERC20_Pausable.cairo) preset allows the contract owner to pause/unpause all state-modifying methods i.e. `transfer`, `approve`, etc. This preset proves useful for scenarios such as preventing trades until the end of an evaluation period and having an emergency switch for freezing all token transfers in the event of a large bug.

### ERC20_Upgradeable

The [`ERC20_Upgradeable`](../src/openzeppelin/token/erc20/ERC20_Upgradeable.cairo) preset allows the contract owner to upgrade a contract by deploying a new ERC20 implementation contract while also maintaing the contract's state. This preset proves useful for scenarios such as eliminating bugs and adding new features. For more on upgradeability, see [Contract upgrades](Proxies.md#contract-upgrades).

## API Specification

### Methods

```cairo
func name() -> (name: felt):
end

func symbol() -> (symbol: felt):
end

func decimals() -> (decimals: felt):
end

func totalSupply() -> (totalSupply: Uint256):
end

func balanceOf(account: felt) -> (balance: Uint256):
end

func allowance(owner: felt, spender: felt) -> (remaining: Uint256):
end

func transfer(recipient: felt, amount: Uint256) -> (success: felt):
end

func transferFrom(
        sender: felt,
        recipient: felt,
        amount: Uint256
    ) -> (success: felt):
end

func approve(spender: felt, amount: Uint256) -> (success: felt):
end
```

#### `name`

Returns the name of the token.

Parameters: None.

Returns:

```cairo
name: felt
```

#### `symbol`

Returns the ticker symbol of the token.

Parameters: None.

Returns:

```cairo
symbol: felt
```

#### `decimals`

Returns the number of decimals the token uses - e.g. 8 means to divide the token amount by 100000000 to get its user representation.

Parameters: None.

Returns:

```cairo
decimals: felt
```

#### `totalSupply`

Returns the amount of tokens in existence.

Parameters: None.

Returns:

```cairo
totalSupply: Uint256
```

#### `balanceOf`

Returns the amount of tokens owned by `account`.

Parameters:

```cairo
account: felt
```

Returns:

```cairo
balance: Uint256
```

#### `allowance`

Returns the remaining number of tokens that `spender` will be allowed to spend on behalf of `owner` through `transferFrom`. This is zero by default.

This value changes when `approve` or `transferFrom` are called.

Parameters:

```cairo
owner: felt
spender: felt
```

Returns:

```cairo
remaining: Uint256
```

#### `transfer`

Moves `amount` tokens from the caller’s account to `recipient`. It returns `1` representing a bool if it succeeds.

Emits a [Transfer](#transfer-event) event.

Parameters:

```cairo
recipient: felt
amount: Uint256
```

Returns:

```cairo
success: felt
```

#### `transferFrom`

Moves `amount` tokens from `sender` to `recipient` using the allowance mechanism. `amount` is then deducted from the caller’s allowance. It returns `1` representing a bool if it succeeds.

Emits a [Transfer](#transfer-event) event.

Parameters:

```cairo
sender: felt
recipient: felt
amount: Uint256
```

Returns:

```cairo
success: felt
```

#### `approve`

Sets `amount` as the allowance of `spender` over the caller’s tokens. It returns `1` representing a bool if it succeeds.

Emits an [Approval](#approval-event) event.

Parameters:

```cairo
spender: felt
amount: Uint256
```

Returns:

```cairo
success: felt
```

### Events

```cairo
func Transfer(from_: felt, to: felt, value: Uint256):
end

func Approval(owner: felt, spender: felt, value: Uint256):
end
```

#### `Transfer (event)`

Emitted when `value` tokens are moved from one account (`from_`) to another (`to`).

Note that `value` may be zero.

Parameters:

```cairo
from_: felt
to: felt
value: Uint256
```

#### `Approval (event)`

Emitted when the allowance of a `spender` for an `owner` is set by a call to [approve](#approve). `value` is the new allowance.

Parameters:

```cairo
owner: felt
spender: felt
value: Uint256
```
