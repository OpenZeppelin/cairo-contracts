# Accounts
Unlike Ethereum where accounts are directly derived from a private key, there's no native account concept on StarkNet.

Instead, signature validation has to be done at the contract level. To relieve smart contract applications such as ERC20 tokens or exchanges from this responsibility, we make use of Account contracts to deal with transaction authentication.

A more detailed writeup on the topic can be found on [Perama's blogpost](https://perama-v.github.io/cairo/account-abstraction/).

## Table of Contents

* [Quickstart](#quickstart)
* [Standard Interface](#standard-interface)
* [Keys, signatures and signers](#keys--signatures-and-signers)
    + [Signer utility](#signer-utility)
* [Message format](#message-format)
* [MultiCall](#-multicall-)
* [API Specification](#api-specification)
    - [`get_public_key`](#-get-public-key-)
    - [`get_nonce`](#-get-nonce-)
    - [`set_public_key`](#-set-public-key-)
    - [`is_valid_signature`](#-is-valid-signature-)
    - [`__execute__`](#-__execute__-)
* [Account differentiation with ERC165](#account-differentiation-with-erc165)
* [Extending the Account contract](#extending-the-account-contract)
* [L1 escape hatch mechanism](#l1-escape-hatch-mechanism)
* [Paying for gas](#paying-for-gas)

## Quickstart

The general workflow is: 
1. Account contract is deployed to StarkNet
2. Signed transactions can now be sent to the Account contract which validates and executes them

In Python, this would look as follows:

```python
from starkware.starknet.testing.starknet import Starknet
signer = Signer(123456789987654321)
starknet = await Starknet.empty()

# 1. Deploy Account
account = await starknet.deploy(
    "contracts/Account.cairo",
    constructor_calldata=[signer.public_key]
)

# 2. Send transaction through Account
await signer.send_transaction(account, some_contract_address, 'some_function', [some_parameter])
```

## Standard Interface

The [`IAccount.cairo`](https://github.com/OpenZeppelin/cairo-contracts/blob/8739a1c2c28b1fe0b6ed7a10a66aa7171da41326/contracts/IAccount.cairo) contract interface contains the standard account interface proposed in [#41](https://github.com/OpenZeppelin/cairo-contracts/discussions/41) and adopted by OpenZeppelin and Argent. It implements [EIP-1271](https://eips.ethereum.org/EIPS/eip-1271) and it is agnostic of signature validation and nonce management strategies.

```c#
@contract_interface
namespace IAccount:
    #
    # Getters
    #

    func get_nonce() -> (res : felt):
    end

    #
    # Business logic
    #

    func is_valid_signature(
            hash: felt,
            signature_len: felt,
            signature: felt*
        ):
    end

    func __execute__(
            call_array_len: felt,
            call_array: AccountCallArray*,
            calldata_len: felt,
            calldata: felt*,
            nonce: felt
        ) -> (response_len: felt, response: felt*):
    end
end
```

## Keys, signatures and signers

While the interface is agnostic of signature validation schemes, this implementation assumes there's a public-private key pair controlling the Account. That's why the `constructor` function expects a `public_key` parameter to set it. Since there's also a `set_public_key()` method, accounts can be effectively transferred.

Note that although the current implementation works only with StarkKeys, support for Ethereum's ECDSA algorithm will be added in the future.

### Signer utility

[Signer.py](https://github.com/OpenZeppelin/cairo-contracts/blob/8739a1c2c28b1fe0b6ed7a10a66aa7171da41326/tests/utils/Signer.py) is used to perform transactions on a given Account, crafting the tx and managing nonces.

It exposes three functions:

- `def sign(message_hash)` receives a hash and returns a signed message of it
- `def send_transaction(account, to, selector_name, calldata, nonce=None, max_fee=0)` returns a future of a signed transaction, ready to be sent.
- `def send_transactions(account, calls, nonce=None, max_fee=0)` returns a future of batched signed transactions, ready to be sent.

To use Signer, pass a private key when instantiating the class:

```python
from utils.Signer import Signer

PRIVATE_KEY = 123456789987654321
signer = Signer(PRIVATE_KEY)
```

Then send single transactions with the `send_transaction` method.

```python
await signer.send_transaction(account, contract_address, 'method_name', [])
```

If utilizing multicall, send multiple transactions with the `send_transactions` method.

```python
    await signer.send_transactions(
        account,
        [
            (contract_address, 'method_name', [param1, param2]),
            (contract_address, 'another_method', [])
        ]
    )
```


## Call and MultiCall format

The idea is for all user intent to be encoded into a `Call` representing a smart contract call. If the user wants to send multiple messages in a single transaction, these `Call`s are bundled into a `MultiCall`. It should be noted that every transaction utilizes multicall. A single `Call`, however, is treated as a bundle of one.

A single `Call` is structured as follows:

```c#
struct Call:
    member to: felt
    member selector: felt
    member calldata_len: felt
    member calldata: felt*
end
```

Where:

- `to` is the address of the target contract of the message
- `selector` is the selector of the function to be called on the target contract
- `calldata_len` is the number of calldata parameters
- `calldata` is an array representing the function parameters

`MultiCall` is structured as:

```c#
struct MultiCall:
    member account: felt
    member calls_len: felt
    member calls: Call*
    member nonce: felt
    member max_fee: felt
    member version: felt
end
```

Where:

- `account` is the Account contract address. It is included to prevent transaction replays in case there's another Account contract controlled by the same public keys
- `calls_len` is the number of calls bundled into the transaction
- `calls` is an array representing each `Call`
- `nonce` is an unique identifier of this message to prevent transaction replays. Current implementation requires nonces to be incremental
- `max_fee` is the maximum fee a user will pay
- `version` is a fixed number which is used to invalidate old transactions

This `MultiCall` message is built within the `__execute__` method which has the following interface:
```cairo
func __execute__(
        call_array_len: felt,
        call_array: AccountCallArray*,
        calldata_len: felt,
        calldata: felt*,
        nonce: felt
    ) -> (response_len: felt, response: felt*):
end
```

Where:

- `call_array_len` is the number of calls
- `call_array` is an array representing each `Call`
- `calldata_len` is the number of calldata parameters
- `calldata` is an array representing the function parameters 
- `nonce` is an unique identifier of this message to prevent transaction replays. Current implementation requires nonces to be incremental

`__execute__` acts as a single entrypoint for all user interaction with any contract, including managing the account contract itself. That's why if you want to change the public key controlling the Account, you would send a transaction targeting the very Account contract:

```python
await signer.send_transaction(account, account.contract_address, 'set_public_key', [NEW_KEY])
```

Note that Signer's `send_transaction` and `send_transactions` call `__execute__` under the hood.

Or if you want to update the Account's L1 address on the `AccountRegistry` contract, you would 

```python
await signer.send_transaction(account, registry.contract_address, 'set_L1_address', [NEW_ADDRESS])
```

You can read more about how messages are structured and hashed in the [Account message scheme  discussion](https://github.com/OpenZeppelin/cairo-contracts/discussions/24). For more information on the design choices and implementation of multicall, you can read the [How should Account multicall work discussion](https://github.com/OpenZeppelin/cairo-contracts/discussions/27).

> Note that the scheme of building multicall transactions within the `__execute__` method will change once StarkNet allows for pointers in struct arrays. In which case, multiple transactions can be passed to (as opposed to built within) `__execute__`.


## API Specification

This in a nutshell is the Account contract public API:

```cairo
func get_public_key() -> (res: felt):
end

func get_nonce() -> (res: felt):
end

func set_public_key(new_public_key: felt):
end

func is_valid_signature(hash: felt,
        signature_len: felt,
        signature: felt*
    ):
end

func __execute__(
        call_array_len: felt,
        call_array: AccountCallArray*,
        calldata_len: felt,
        calldata: felt*,
        nonce: felt
    ) -> (response_len: felt, response: felt*):
end
```

#### `get_public_key`

Returns the public key associated with the Account contract.

##### Parameters:

None.

##### Returns:
```
public_key: felt
```

#### `get_nonce`

Returns the current transaction nonce for the Account.

##### Parameters:

None.

##### Returns:

```
nonce: felt
```

#### `set_public_key`

Sets the public key that will control this Account. It can be used to rotate keys for security, change them in case of compromised keys or even transferring ownership of the account.

##### Parameters:
```
public_key: felt
```

##### Returns:

None.

#### `is_valid_signature`

This function is inspired by [EIP-1271](https://eips.ethereum.org/EIPS/eip-1271) and checks whether a given signature is valid, otherwise it reverts.

##### Parameters:
```
hash: felt
signature_len: felt
signature: felt*
```

##### Returns:

None.

#### `__execute__`

This is the only external entrypoint to interact with the Account contract. It:

1. Takes the input and builds a [Multicall](#message-format) message with it
2. Validates the transaction signature matches the message (including the nonce)
3. Increments the nonce
4. Calls the target contract with the intended function selector and calldata parameters
5. Forwards the contract call response data as return value

##### Parameters:
```
call_array_len: felt
call_array: AccountCallArray*
calldata_len: felt
calldata: felt*
nonce: felt
```

> Note that the current signature scheme expects a 2-element array like `[sig_r, sig_s]`.


##### Returns:
```
response_len: felt
response: felt*
```

## Account differentiation with ERC165

Certain contracts like ERC721 require a means to differentiate between account contracts and non-account contracts. For a contract to declare itself as an account, it should implement [ERC165](https://eips.ethereum.org/EIPS/eip-165) as proposed in [#100](https://github.com/OpenZeppelin/cairo-contracts/discussions/100). To be in compliance with ERC165 specifications, the idea is to calculate the XOR of `IAccount`'s EVM selectors (not StarkNet selectors). The resulting magic value of `IAccount` is 0x50b70dcb.

Our ERC165 integration on StarkNet is inspired by OpenZeppelin's Solidity implementation of [ERC165Storage](https://docs.openzeppelin.com/contracts/4.x/api/utils#ERC165Storage) which stores the interfaces that the implementing contract supports. In the case of account contracts, querying `supportsInterface` of an account's address with the `IAccount` magic value should return [`TRUE`](../openzeppelin/utils/constants.cairo) (a constant variable representing `1` in Cairo).

## Extending the Account contract

Account contracts can be extended by following the [extensibility pattern](../docs/Extensibility.md#the-pattern). The basic idea behind integrating the pattern is to import the requisite methods from the Account library and incorporate the extended logic thereafter.

Currently, there's only a single library/preset Account scheme, but we're looking for feedback and new presets to emerge. Some new validation schemes to look out for in the future:
- multisig
- guardian logic like in [Argent's account](https://github.com/argentlabs/argent-contracts-starknet/blob/de5654555309fa76160ba3d7393d32d2b12e7349/contracts/ArgentAccount.cairo)
- [Ethereum signatures](https://github.com/OpenZeppelin/cairo-contracts/issues/161)


## L1 escape hatch mechanism

*[unknown, to be defined]*


## Paying for gas

*[unknown, to be defined]*
