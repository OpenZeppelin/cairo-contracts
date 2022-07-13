# Proxies

> Expect rapid iteration as this pattern matures and more patterns potentially emerge.

## Table of Contents

* [Quickstart](#quickstart)
* [Solidity/Cairo upgrades comparison](#solidity/cairo-upgrades-comparison)
  * [Constructors](#constructors)
  * [Storage](#storage)
* [Proxies](#proxies2)
  * [Proxy contract](#proxy-contract)
  * [Implementation contract](#implementation-contract)
* [Upgrades library API](#upgrades-library-api)
  * [Methods](#methods)
  * [Events](#events)
* [Using proxies](#using-proxies)
  * [Contract upgrades](#contract-upgrades)
  * [Declaring contracts](#declaring-contracts)
  * [Handling method calls](#handling-method-calls)
* [Presets](#presets)

## Quickstart

The general workflow is:

1. declare an implementation [contract class](https://starknet.io/docs/hello_starknet/intro.html#declare-the-contract-on-the-starknet-testnet)
2. deploy proxy contract with the implementation contract's class hash set in the proxy's constructor calldata
3. initialize the implementation contract by sending a call to the proxy contract. This will redirect the call to the implementation contract class and behave like the implementation contract's constructor

In Python, this would look as follows:

```python
    # declare implementation contract
    IMPLEMENTATION = await starknet.declare(
        "path/to/implementation.cairo",
    )

    # deploy proxy
    PROXY = await starknet.deploy(
        "path/to/proxy.cairo",
        constructor_calldata=[
            IMPLEMENTATION.class_hash,  # set implementation contract class hash
        ]
    )

    # users should only interact with the proxy contract
    await signer.send_transaction(
        account, PROXY.contract_address, 'initialize', [
            arg_1,
            arg_2
        ]
    )
```

## Solidity/Cairo upgrades comparison

### Constructors

OpenZeppelin Contracts for Solidity requires the use of an alternative library for upgradeable contracts. Consider that in Solidity constructors are not part of the deployed contract's runtime bytecode; rather, a constructor's logic is executed only once when the contract instance is deployed and then discarded. This is why proxies can't imitate the construction of its implementation, therefore requiring a different initialization mechanism.

The constructor problem in upgradeable contracts is resolved by the use of initializer methods. Initializer methods are essentially regular methods that execute the logic that would have been in the constructor. Care needs to be exercised with initializers to ensure they can only be called once. Thus, OpenZeppelin offers an [upgradeable contracts library](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable) where much of this process is abstracted away.
See OpenZeppelin's [Writing Upgradeable Contracts](https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable) for more info.

The Cairo programming language does not support inheritance. Instead, Cairo contracts follow the [Extensibility Pattern](../docs/Extensibility.md) which already uses initializer methods to mimic constructors. Upgradeable contracts do not, therefore, require a separate library with refactored constructor logic.

### Storage

OpenZeppelin's alternative Upgrades library also implements [unstructured storage](https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies#unstructured-storage-proxies) for its upgradeable contracts. The basic idea behind unstructured storage is to pseudo-randomize the storage structure of the upgradeable contract so it's based on variable names instead of declaration order, which makes the chances of storage collision during an upgrade extremely unlikely.

The StarkNet compiler, meanwhile, already creates pseudo-random storage addresses by hashing the storage variable names (and keys in mappings) by default. In other words, StarkNet already uses unstructured storage and does not need a second library to modify how storage is set. See StarkNet's [Contracts Storage documentation](https://starknet.io/documentation/contracts/#contracts_storage) for more information.

<h2 id="proxies2">Proxies</h2>

A proxy contract is a contract that delegates function calls to another contract. This type of pattern decouples state and logic. Proxy contracts store the state and redirect function calls to an implementation contract that handles the logic. This allows for different patterns such as upgrades, where implementation contracts can change but the proxy contract (and thus the state) does not; as well as deploying multiple proxy instances pointing to the same implementation. This can be useful to deploy many contracts with identical logic but unique initialization data.

In the case of contract upgrades, it is achieved by simply changing the proxy's reference to the class hash of the declared implementation. This allows developers to add features, update logic, and fix bugs without touching the state or the contract address to interact with the application.

### Proxy contract

The [Proxy contract](../src/openzeppelin/upgrades/Proxy.cairo) includes two core methods:

1. The `__default__` method is a fallback method that redirects a function call and associated calldata to the implementation contract.

2. The `__l1_default__` method is also a fallback method; however, it redirects the function call and associated calldata to a layer one contract. In order to invoke `__l1_default__`, the original function call must include the library function `send_message_to_l1`. See Cairo's [Interacting with L1 contracts](https://www.cairo-lang.org/docs/hello_starknet/l1l2.html) for more information.

Since this proxy is designed to work both as an [UUPS-flavored upgrade proxy](https://eips.ethereum.org/EIPS/eip-1822) as well as a non-upgradeable proxy, it does not know how to handle its own state. Therefore it requires the implementation contract class to be declared beforehand, so its class hash can be passed to the Proxy on construction time.

When interacting with the contract, function calls should be sent by the user to the proxy. The proxy's fallback function redirects the function call to the implementation contract to execute.

### Implementation contract

The implementation contract, also known as the logic contract, receives the redirected function calls from the proxy contract. The implementation contract should follow the [Extensibility pattern](../docs/Extensibility.md#the-pattern) and import directly from the [Proxy library](../src/openzeppelin/upgrades/library.cairo).

The implementation contract should:

* import `Proxy` namespace
* initialize the proxy immediately after contract deployment with `Proxy.initializer`.

If the implementation is upgradeable, it should:

* include a method to upgrade the implementation (i.e. `upgrade`)
* use access control to protect the contract's upgradeability.

The implementation contract should NOT:

* be deployed like a regular contract. Instead, the implementation contract should be declared (which creates a `DeclaredClass` containing its hash and abi)
* set its initial state with a traditional constructor (decorated with `@constructor`). Instead, use an initializer method that invokes the Proxy `constructor`.

> Note that the Proxy `constructor` includes a check the ensures the initializer can only be called once; however, `_set_implementation` does not include this check. It's up to the developers to protect their implementation contract's upgradeability with access controls such as [`assert_only_admin`](#assert_only_admin).

For a full implementation contract example, please see:

* [Proxiable implementation](../tests/mocks/proxiable_implementation.cairo)

## Upgrades library API

### Methods

```cairo
func initializer(proxy_admin: felt):
end

func assert_only_admin():
end

func get_implementation_hash() -> (implementation: felt):
end

func get_admin() -> (admin: felt):
end

func _set_admin(new_admin: felt):
end

func _set_implementation_hash(new_implementation: felt):
end
```

#### `initializer`

Initializes the proxy contract with an initial implementation.

Parameters:

```cairo
proxy_admin: felt
```

Returns:

None.

#### `assert_only_admin`

Reverts if called by any account other than the admin.

Parameters:

None.

Returns:

None.

#### `get_implementation`

Returns the current implementation hash.

Parameters:

None.

Returns:

```cairo
implementation: felt
```

#### `get_admin`

Returns the current admin.

Parameters:

None.

Returns:

```cairo
admin: felt
```

#### `_set_admin`

Sets `new_admin` as the admin of the proxy contract.

Parameters:

```cairo
new_admin: felt
```

Returns:

None.

#### `_set_implementation_hash`

Sets `new_implementation` as the implementation's contract class. This method is included in the proxy contract's constructor and can be used to upgrade contracts.

Parameters:

```cairo
new_implementation: felt
```

Returns:

None.

### Events

```cairo
func Upgraded(implementation: felt):
end

func AdminChanged(previousAdmin: felt, newAdmin: felt):
end
```

#### `Upgraded`

Emitted when a proxy contract sets a new implementation class hash.

Parameters:

```cairo
implementation: felt
```

#### `AdminChanged`

Emitted when the `admin` changes from `previousAdmin` to `newAdmin`.

Parameters:

```cairo
previousAdmin: felt
newAdmin: felt
```

## Using proxies

### Contract upgrades

To upgrade a contract, the implementation contract should include an `upgrade` method that, when called, changes the reference to a new deployed contract like this:

```python
    # declare first implementation
    IMPLEMENTATION = await starknet.declare(
        "path/to/implementation.cairo",
    )

    # deploy proxy
    PROXY = await starknet.deploy(
        "path/to/proxy.cairo",
        constructor_calldata=[
            IMPLEMENTATION.class_hash,  # set implementation hash
        ]
    )

    # declare implementation v2
    IMPLEMENTATION_V2 = await starknet.declare(
        "path/to/implementation_v2.cairo",
    )

    # call upgrade with the new implementation contract class hash
    await signer.send_transaction(
        account, PROXY.contract_address, 'upgrade', [
            IMPLEMENTATION_V2.class_hash
        ]
    )
```

For a full deployment and upgrade implementation, please see:

* [Upgrades V1](../tests/mocks/upgrades_v1_mock.cairo)
* [Upgrades V2](../tests/mocks/upgrades_v2_mock.cairo)

### Declaring contracts

StarkNet contracts come in two forms: contract classes and contract instances. Contract classes represent the uninstantiated, stateless code; whereas, contract instances are instantiated and include the state. Since the Proxy contract references the implementation contract by its class hash, declaring an implementation contract proves sufficient (as opposed to a full deployment). For more information on declaring classes, see [StarkNet's documentation](https://starknet.io/docs/hello_starknet/intro.html#declare-contract).

### Handling method calls

As with most StarkNet contracts, interacting with a proxy contract requires an [account abstraction](../docs/Account.md#quickstart). One notable difference with proxy contracts versus other contract implementations is that calling `@view` methods also requires an account abstraction. As of now, direct calls to default entrypoints are only supported by StarkNet's `syscalls` from other contracts i.e. account contracts. The differences in getter methods written in Python, for example, are as follows:

```python
# standard ERC20 call
result = await erc20.totalSupply().call()

# upgradeable ERC20 call
result = await signer.send_transaction(
        account, PROXY.contract_address, 'totalSupply', []
    )
```

## Presets

Presets are pre-written contracts that extend from our library of contracts. They can be deployed as-is or used as templates for customization.

Some presets include:

* [ERC20_Upgradeable](../src/openzeppelin/token/erc20/ERC20_Upgradeable.cairo)
* more to come! have an idea? [open an issue](https://github.com/OpenZeppelin/cairo-contracts/issues/new/choose)!
