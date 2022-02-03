# Utilities

> Expect this module to evolve (as it has already done).

## Table of Contents

* [Constants](#constants)
  * [`MAX_UINT256`](#max_uint256)
  * [`ZERO_ADDRESS`](#zero_address)
  * [`TRUE`](#-true-)
  * [`FALSE`](#-false-)
* [Strings](#strings)
  * [`str_to_felt`](#str_to_felt)
  * [`felt_to_str`](#felt_to_str)
* [Uint256](#uint256)
  * [`uint`](#uint)
  * [`to_uint`](#to_uint)
  * [`from_uint`](#from_uint)
  * [`add_uint`](#add_uint)
  * [`sub_uint`](#sub_uint)
* [Assertions](#assertions)
  * [`assert_revert`](#assert_revert)
  * [`assert_events_emitted`](#assert_events_emitted)
* [Signer](#signer)

## Constants

The Cairo programming language includes myriad quirks relative to other programming languages. To ease the readability of Cairo Contract tests, this project includes reusable constant variables. 

### `MAX_UINT256`

The maximum value in a 256-bit integer represented in a tuple of two 128-bit integers to accomodate uint256 structs in Cairo. 

### `ZERO_ADDRESS`

When a user calls a contract directly, the sender of the transaction is `0`. Copious tests go toward checking that users cannot send transactions as address `0`. Using the `ZERO_ADDRESS` constant enhances the readability of tests.

### `TRUE`

Booleans are represented as binary in Cairo; therefore, `TRUE` represents `1`.

### `FALSE`

Booleans are represented as binary in Cairo; therefore, `FALSE` represents `0`.

## Strings

Cairo currently only provides support for short string literals (less than 32 characters). Note that short strings aren't really strings, rather, they're representations of Cairo field elements. The following methods provide a simple conversion to/from field elements. 

### `str_to_felt`

Takes an ASCII string and converts it to a field element via big endian representation.


### `felt_to_str`

Takes an integer and converts it to an ASCII string by trimming the null bytes and decoding the remaining bits.

## Uint256

Cairo's native data type is a field element (felt). Felts equate to 252 bits which poses a problem regarding 256-bit integer integrationg. To resolve the bit discrepancy, Cairo represents 256-bit integers as a struct of two 128-bit integers. Further, the low bits precede the high bits e.g.

```
1 = (1, 0)
1 << 128 = (0, 1)
(1 << 128) - 1 = (340282366920938463463374607431768211455, 0)
```

### `uint`

Converts a simple integer into a uint256-ish tuple.

> Note `to_uint` should be used in favor of `uint`, as `uint` only returns the low bits of the tuple.


### `to_uint`

Converts an integer into a uint256-ish tuple.

```python
x = to_uint(340282366920938463463374607431768211456)
print(x)
# prints (0, 1)
```

### `from_uint`

Converts a uin256-ish tuple into an integer.

```python
x = (0, 1)
y = from_uint(x)
print(y)
# prints 340282366920938463463374607431768211456
```

### `add_uint`

Performs addition between two uint256-ish tuples and returns the sum as a uint256-ish tuple.

```python
x = (0, 1)
y = (1, 0)
z = add_uint(x, y)
print(z)
# prints (1, 1)
```

### `sub_uint`

Performs subtraction between two uint256-ish tuples and returns the difference as a uint256-ish tuple.

```python
x = (0, 1)
y = (1, 0)
z = sub_uint(x, y)
print(z)
# prints (340282366920938463463374607431768211455, 0)
```

## Assertions

In order to abstract away some of the verbosity regarding test assertions on StarkNet transactions, this project includes the following helper methods:

### `assert_revert`

An asynchronous wrapper method that executes a try-except pattern for transactions that should fail with the StarkNet error code: `TRANSACTION_FAILED`. To successfully use this wrapper, the transaction method should be wrapped with `assert_revert`; however, `await` should precede the wrapper itself like this:

```python
await assert_revert(signer.send_transaction(
    account, contract.contract_address, 'foo', [
        recipient,
        *token
    ])
)
```

### `assert_event_emitted`

A helper method that checks a transaction receipt for the contract emitting the event (`from_address`), the emitted event (`name`), and the arguments emitted (`data`). To use `assert_event_emitted`:

```python
# capture the tx receipt
tx_exec_info = await signer.send_transaction(
    account, contract.contract_address, 'foo', [
        recipient,
        *token
    ])

# insert arguments to assert
assert_event_emitted(
    tx_exec_info,
    from_address=contract.contract_address,
    name='Foo_emitted',
    data=[
        account.contract_address,
        recipient,
        *token
    ]
)
```


## Signer

`Signer` is used to perform transactions on a given Account, crafting the tx and managing nonces. See the [Account documentation](../docs/Account.md#signer-utility) for in-depth information.