# ERC20

The ERC20 token standard is a specification for [fungible tokens](https://docs.openzeppelin.com/contracts/4.x/tokens#different-kinds-of-tokens), a type of token where all the units are exactly equal to each other. The `ERC20.cairo` contract implements an approximation of [EIP-20](https://eips.ethereum.org/EIPS/eip-20) in Cairo for StarkNet.

## Table of Contents

- [Interface](#interface)
  * [ERC20 compatibility](#erc20-compatibility)
- [Usage](#usage)
- [Extensibility](#extensibility)
- [API Specification](#api-specification)
  * [Methods](#-methods-)
    * [`name`](#-name-)
    * [`symbol`](#-symbol-)
    * [`decimals`](#-decimals-)
    * [`totalSupply`](#-total-supply-)
    * [`balanceOf`](#-balance-of-)
    * [`allowance`](#-allowance-)
    * [`transfer`](#-transfer-)
    * [`transferFrom`](#-transferfrom-)
    * [`approve`](#-approve-)
  * [Events](#-events-)
    * [`Transfer (event)`](#-transfer-(event)-)
    * [`Approval (event)`](#-approval-(event)-)

## Interface

```jsx
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
- it returns `1` as success to imitate a `bool`
- it makes use of Cairo's short strings to simulate `name` and `symbol`

But some differences can still be found, such as:

- `decimals` returns a 252-bit `felt`, meaning it can be much larger than the standard's 8-bit `uint8`. However, compliant implementations should not return a value that is not representable in `uint8`.
- `transfer`, `transferFrom` and `approve` will never return anything different from true (`1`) because they will revert on any error
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

> Note that decimals should not exceed `2^8` to be ERC20 compatible.

As most StarkNet contracts, it expects to be called by another contract and it identifies it through `get_caller_address` (analogous to Solidity's `this.address`). This is why we need an Account contract to interact with it. For example:

```python
signer = Signer(PRIVATE_KEY)
amount = uint(100)

account = await starknet.deploy(
    "contracts/Account.cairo",
    constructor_calldata=[signer.public_key]
)

await signer.send_transaction(account, erc20.contract_address, 'transfer', [recipient_address, *amount])
```

## Extensibility

There's no clear contract extensibility pattern for Cairo smart contracts yet. In the meantime the best way to extend our contracts is copypasting and modifying them at your own risk.

For example, you could:

- Implement a pausing mechanism
- Add roles such as owner or minter
- Modify the `_transfer` function to perform actions [before](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol#L229) or after [transfers](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol#L240)

## API Specification

### Methods

```jsx
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

```jsx
name: felt
```

#### `symbol`

Returns the ticker symbol of the token.

Parameters: None.

Returns:

```jsx
symbol: felt
```

#### `decimals`

Returns the number of decimals the token uses - e.g. 8 means to divide the token amount by 100000000 to get its user representation.

Parameters: None.

Returns:

```jsx
decimals: felt
```

#### `totalSupply`

Returns the amount of tokens in existence.

Parameters: None.

Returns:

```jsx
totalSupply: Uint256
```

#### `balanceOf`

Returns the amount of tokens owned by `account`.

Parameters:

```jsx
account: felt
```

Returns:

```jsx
balance: Uint256
```

#### `allowance`

Returns the remaining number of tokens that `spender` will be allowed to spend on behalf of `owner` through `transferFrom`. This is zero by default.

This value changes when `approve` or `transferFrom` are called.

Parameters:

```jsx
owner: felt
spender: felt
```

Returns:

```jsx
remaining: Uint256
```

#### `transfer`

Moves `amount` tokens from the caller’s account to `recipient`. It returns `1` representing a bool if it succeeds.

Emits a [Transfer](#-transfer-(event)-) event.

Parameters:

```jsx
recipient: felt
amount: Uint256
```

Returns:

```jsx
success: felt
```

#### `transferFrom`

Moves `amount` tokens from `sender` to `recipient` using the allowance mechanism. `amount` is then deducted from the caller’s allowance. It returns `1` representing a bool if it succeeds.

Emits a [Transfer](#-transfer-(event)-) event.

Parameters:

```jsx
sender: felt
recipient: felt
amount: Uint256
```

Returns:

```jsx
success: felt
```

#### `approve`

Sets `amount` as the allowance of `spender` over the caller’s tokens. It returns `1` representing a bool if it succeeds.

Emits an [Approval](#-approval-(event)-) event.

Parameters:

```jsx
spender: felt
amount: Uint256
```

Returns:

```jsx
success: felt
```

### Events

```jsx
func Transfer(from_: felt, to: felt, value: Uint256):
end

func Approval(owner: felt, spender: felt, value: Uint256):
end
```

#### `Transfer (event)`

Emitted when `value` tokens are moved from one account (`from_`) to another (`to`). 

Note that `value` may be zero.

Parameters:

```jsx
from_: felt
to: felt
value: Uint256
```

#### `Approval (event)`

Emitted when the allowance of a `spender` for an `owner` is set by a call to [approve](#-approve-). `value` is the new allowance.

Parameters:

```jsx
owner: felt
spender: felt
value: Uint256
```
