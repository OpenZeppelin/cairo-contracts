# Accounts

Unlike Ethereum where accounts are directly derived from a private key, there's no native account concept on StarkNet.

Instead, signature validation has to be done at the contract level. To relieve smart contract applications such as ERC20 tokens or exchanges from this responsibility, we make use of Account contracts to deal with transaction authentication.

A more detailed writeup on the topic can be found on [Perama's blogpost](https://perama-v.github.io/cairo/account-abstraction/).

## Table of Contents

* [Quickstart](#quickstart)
* [Standard Interface](#standard-interface)
* [Keys, signatures and signers](#keys-signatures-and-signers)
  * [Signer](#signer)
  * [MockSigner utility](#mocksigner-utility)
  * [MockEthSigner utility](#mockethsigner-utility)
* [Account entrypoint](#account-entrypoint)
* [Call and AccountCallArray format](#call-and-accountcallarray-format)
  * [Call](#call)
  * [AccountCallArray](#accountcallarray)
* [Multicall transactions](#multicall-transactions)
* [API Specification](#api-specification)
  * [`get_public_key`](#get_public_key)
  * [`get_nonce`](#get_nonce)
  * [`set_public_key`](#set_public_key)
  * [`is_valid_signature`](#is_valid_signature)
  * [`__execute__`](#__execute__)
  * [`is_valid_eth_signature`](#is_valid_eth_signature)
  * [`eth_execute`](#eth_execute)
  * [`_unsafe_execute`](#_unsafe_execute)
* [Presets](#presets)
  * [Account](#account)
  * [Eth Account](#eth-account)
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
signer = MockSigner(123456789987654321)
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

The [`IAccount.cairo`](../src/openzeppelin/account/IAccount.cairo) contract interface contains the standard account interface proposed in [#41](https://github.com/OpenZeppelin/cairo-contracts/discussions/41) and adopted by OpenZeppelin and Argent. It implements [EIP-1271](https://eips.ethereum.org/EIPS/eip-1271) and it is agnostic of signature validation and nonce management strategies.

```cairo
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
        ) -> (is_valid: felt):
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

### Signer

The signer is responsible for creating a transaction signature with the user's private key for a given transaction. This implementation utilizes [Nile's Signer](https://github.com/OpenZeppelin/nile/blob/main/src/nile/signer.py) class to create transaction signatures through the `Signer` method `sign_transaction`.

`sign_transaction` expects the following parameters per transaction:

* `sender` the contract address invoking the tx
* `calls` a list containing a sublist of each call to be sent. Each sublist must consist of:
    1. `to` the address of the target contract of the message
    2. `selector` the function to be called on the target contract
    3. `calldata` the parameters for the given `selector`
* `nonce` an unique identifier of this message to prevent transaction replays. Current implementation requires nonces to be incremental
* `max_fee` the maximum fee a user will pay

Which returns:

* `calls` a list of calls to be bundled in the transaction
* `calldata` a list of arguments for each call
* `sig_r` the transaction signature
* `sig_s` the transaction signature

While the `Signer` class performs much of the work for a transaction to be sent, it neither manages nonces nor invokes the actual transaction on the Account contract. To simplify Account management, most of this is abstracted away with `MockSigner`.

### MockSigner utility

The `MockSigner` class in [utils.py](../tests/utils.py) is used to perform transactions on a given Account, crafting the transaction and managing nonces.

The flow of a transaction starts with checking the nonce and converting the `to` contract address of each call to hexadecimal format. The hexadecimal conversion is necessary because Nile's `Signer` converts the address to a base-16 integer (which requires a string argument). Note that directly converting `to` to a string will ultimately result in an integer exceeding Cairo's `FIELD_PRIME`.

The values included in the transaction are passed to the `sign_transaction` method of Nile's `Signer` which creates and returns a signature. Finally, the `MockSigner` instance invokes the account contract's `__execute__` with the transaction data.

Users only need to interact with the following exposed methods to perform a transaction:

* `send_transaction(account, to, selector_name, calldata, nonce=None, max_fee=0)` returns a future of a signed transaction, ready to be sent.

* `send_transactions(account, calls, nonce=None, max_fee=0)` returns a future of batched signed transactions, ready to be sent.

To use `MockSigner`, pass a private key when instantiating the class:

```python
from utils import MockSigner

PRIVATE_KEY = 123456789987654321
signer = MockSigner(PRIVATE_KEY)
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

### MockEthSigner utility

The `MockEthSigner` class in [utils.py](../tests/utils.py) is used to perform transactions on a given Account with a secp256k1 curve key pair, crafting the transaction and managing nonces. It differs from the `MockSigner` implementation by:

* not using the public key but its derived address instead (the last 20 bytes of the keccak256 hash of the public key and adding `0x` to the beginning)
* signing the message with a secp256k1 curve address

## Account entrypoint

`__execute__` acts as a single entrypoint for all user interaction with any contract, including managing the account contract itself. That's why if you want to change the public key controlling the Account, you would send a transaction targeting the very Account contract:

```python
await signer.send_transaction(account, account.contract_address, 'set_public_key', [NEW_KEY])
```

Or if you want to update the Account's L1 address on the `AccountRegistry` contract, you would

```python
await signer.send_transaction(account, registry.contract_address, 'set_L1_address', [NEW_ADDRESS])
```

You can read more about how messages are structured and hashed in the [Account message scheme  discussion](https://github.com/OpenZeppelin/cairo-contracts/discussions/24). For more information on the design choices and implementation of multicall, you can read the [How should Account multicall work discussion](https://github.com/OpenZeppelin/cairo-contracts/discussions/27).

The `__execute__` method has the following interface:

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

* `call_array_len` is the number of calls
* `call_array` is an array representing each `Call`
* `calldata_len` is the number of calldata parameters
* `calldata` is an array representing the function parameters
* `nonce` is an unique identifier of this message to prevent transaction replays. Current implementation requires nonces to be incremental

> Note that the scheme of building multicall transactions within the `__execute__` method will change once StarkNet allows for pointers in struct arrays. In which case, multiple transactions can be passed to (as opposed to built within) `__execute__`.

## `Call` and `AccountCallArray` format

The idea is for all user intent to be encoded into a `Call` representing a smart contract call. Users can also pack multiple messages into a single transaction (creating a multicall transaction). Cairo currently does not support arrays of structs with pointers which means the `__execute__` function cannot properly iterate through mutiple `Call`s. Instead, this implementation utilizes a workaround with the `AccountCallArray` struct. See [Multicall transactions](#multicall-transactions).

### `Call`

A single `Call` is structured as follows:

```cairo
struct Call:
    member to: felt
    member selector: felt
    member calldata_len: felt
    member calldata: felt*
end
```

Where:

* `to` is the address of the target contract of the message
* `selector` is the selector of the function to be called on the target contract
* `calldata_len` is the number of calldata parameters
* `calldata` is an array representing the function parameters

### `AccountCallArray`

`AccountCallArray` is structured as:

```cairo
struct AccountCallArray:
    member to: felt
    member selector: felt
    member data_offset: felt
    member data_len: felt
end
```

Where:

* `to` is the address of the target contract of the message
* `selector` is the selector of the function to be called on the target contract
* `data_offset` is the starting position of the calldata array that holds the `Call`'s calldata
* `data_len` is the number of calldata elements in the `Call`

## Multicall transactions

A multicall transaction packs the `to`, `selector`, `calldata_offset`, and `calldata_len` of each call into the `AccountCallArray` struct and keeps the cumulative calldata for every call in a separate array. The `__execute__` function rebuilds each message by combining the `AccountCallArray` with its calldata (demarcated by the offset and calldata length specified for that particular call). The rebuilding logic is set in the internal `_from_call_array_to_call`.

This is the basic flow:

1. The user sends the messages for the transaction through a Signer instantiation which looks like this:

    ```python
    await signer.send_transaction(
            account, [
                (contract_address, 'contract_method', [arg_1]),
                (contract_address, 'another_method', [arg_1, arg_2])
            ]
        )
    ```

    The `_from_call_to_call_array` method in [utils.py](../tests/utils.py) converts each call into the `AccountCallArray` format and cumulatively stores the calldata of every call into a single array. Next, both arrays (as well as the `sender`, `nonce`, and `max_fee`) are used to create the transaction hash. The Signer then invokes `__execute__` with the signature and passes `AccountCallArray`, calldata, and nonce as arguments.

2. The `__execute__` method takes the `AccountCallArray` and calldata and builds an array of `Call`s (MultiCall).

> It should be noted that every transaction utilizes `AccountCallArray`. A single `Call` is treated as a bundle with one message.

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
    ) -> (is_valid: felt):
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

### `get_public_key`

Returns the public key associated with the Account contract.

Parameters:

None.

Returns:

```cairo
public_key: felt
```

### `get_nonce`

Returns the current transaction nonce for the Account.

Parameters:

None.

Returns:

```cairo
nonce: felt
```

### `set_public_key`

Sets the public key that will control this Account. It can be used to rotate keys for security, change them in case of compromised keys or even transferring ownership of the account.

Parameters:

```cairo
public_key: felt
```

Returns:

None.

### `is_valid_signature`

This function is inspired by [EIP-1271](https://eips.ethereum.org/EIPS/eip-1271) and returns `TRUE` if a given signature is valid, otherwise it reverts. In the future it will return `FALSE` if a given signature is invalid (for more info please check [this issue](https://github.com/OpenZeppelin/cairo-contracts/issues/327)).

Parameters:

```cairo
hash: felt
signature_len: felt
signature: felt*
```

Returns:

```cairo
is_valid: felt
```

> returns `TRUE` if a given signature is valid. Otherwise, reverts. In the future it will return `FALSE` if a given signature is invalid (for more info please check [this issue](https://github.com/OpenZeppelin/cairo-contracts/issues/327)).

### `__execute__`

This is the only external entrypoint to interact with the Account contract. It:

1. Validates the transaction signature matches the message (including the nonce)
2. Increments the nonce
3. Calls the target contract with the intended function selector and calldata parameters
4. Forwards the contract call response data as return value

Parameters:

```cairo
call_array_len: felt
call_array: AccountCallArray*
calldata_len: felt
calldata: felt*
nonce: felt
```

> Note that the current signature scheme expects a 2-element array like `[sig_r, sig_s]`.

Returns:

```cairo
response_len: felt
response: felt*
```

### `is_valid_eth_signature`

Returns `TRUE` if a given signature in the secp256k1 curve is valid, otherwise it reverts. In the future it will return `FALSE` if a given signature is invalid (for more info please check [this issue](https://github.com/OpenZeppelin/cairo-contracts/issues/327)).

Parameters:

```cairo
signature_len: felt
signature: felt*
```

Returns:

```cairo
is_valid: felt
```

> returns `TRUE` if a given signature is valid. Otherwise, reverts. In the future it will return `FALSE` if a given signature is invalid (for more info please check [this issue](https://github.com/OpenZeppelin/cairo-contracts/issues/327)).

### `eth_execute`

This follows the same idea as the vanilla version of `execute` with the sole difference that signature verification is on the secp256k1 curve.

Parameters:

```cairo
call_array_len: felt
call_array: AccountCallArray*
calldata_len: felt
calldata: felt*
nonce: felt
```

> Note that the current signature scheme expects a 7-element array like `[sig_v, uint256_sig_r_low, uint256_sig_r_high, uint256_sig_s_low, uint256_sig_s_high, uint256_hash_low, uint256_hash_high]` given that the parameters of the verification are bigger than a felt.

Returns:

```cairo
response_len: felt
response: felt*
```

### `_unsafe_execute`

It's an internal method that performs the following tasks:

1. Increments the nonce.
2. Takes the input and builds a `Call` for each iterated message. See [Multicall transactions](#multicall-transactions) for more information.
3. Calls the target contract with the intended function selector and calldata parameters
4. Forwards the contract call response data as return value

## Presets

The following contract presets are ready to deploy and can be used as-is for quick prototyping and testing. Each preset differs on the signature type being used by the Account.

### Account

The [`Account`](../src/openzeppelin/account/Account.cairo) preset uses StarkNet keys to validate transactions.

### Eth Account

The [`EthAccount`](../src/openzeppelin/account/EthAccount.cairo) preset supports Ethereum addresses, validating transactions with secp256k1 keys.

## Account differentiation with ERC165

Certain contracts like ERC721 require a means to differentiate between account contracts and non-account contracts. For a contract to declare itself as an account, it should implement [ERC165](https://eips.ethereum.org/EIPS/eip-165) as proposed in [#100](https://github.com/OpenZeppelin/cairo-contracts/discussions/100). To be in compliance with ERC165 specifications, the idea is to calculate the XOR of `IAccount`'s EVM selectors (not StarkNet selectors). The resulting magic value of `IAccount` is 0x50b70dcb.

Our ERC165 integration on StarkNet is inspired by OpenZeppelin's Solidity implementation of [ERC165Storage](https://docs.openzeppelin.com/contracts/4.x/api/utils#ERC165Storage) which stores the interfaces that the implementing contract supports. In the case of account contracts, querying `supportsInterface` of an account's address with the `IAccount` magic value should return `TRUE`.

## Extending the Account contract

Account contracts can be extended by following the [extensibility pattern](../docs/Extensibility.md#the-pattern).

To implement custom account contracts, a pair of `validate` and `execute` functions should be exposed. This is why the Account library comes with different flavors of such pairs, like the vanilla `is_valid_signature` and `execute`, or the Ethereum flavored `is_valid_eth_signature` and `eth_execute` pair.

Account contract developers are encouraged to implement the [standard Account interface](https://github.com/OpenZeppelin/cairo-contracts/discussions/41) and incorporate the custom logic thereafter.

To implement alternative `execute` functions, make sure to check their corresponding `validate` function before calling the `_unsafe_execute` building block, as each of the current presets is doing. Do not expose `_unsafe_execute` directly.

Some other validation schemes to look out for in the future:

* multisig
* guardian logic like in [Argent's account](https://github.com/argentlabs/argent-contracts-starknet/blob/de5654555309fa76160ba3d7393d32d2b12e7349/contracts/ArgentAccount.cairo)

## L1 escape hatch mechanism

[unknown, to be defined]

## Paying for gas

[unknown, to be defined]
