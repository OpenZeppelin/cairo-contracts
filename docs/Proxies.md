# Proxies

> Expect rapid iteration as this pattern matures and more patterns potentially emerge. 

## Table of Contents
* [Quickstart](#quickstart)
* [Proxies](#proxies)
  * [Proxy contract](#proxy-contract) 
  * [Implementation contract](#implementation-contract)
* [Upgrades library API](#upgrades-library-api)
  * [Methods](#methods)
  * [Events](#events)
* [Using proxies](#using-proxies)
  * [Contract upgrades](#contract-upgrades)
  * [Handling method calls](#handling-method-calls)
* [Presets](#presets)

## Quickstart

The general workflow is:
1. deploy implementation contract
2. deploy proxy contract with the implementation contract's address set in the proxy's constructor calldata
3. initialize the implementation contract by sending a call to the proxy contract. This will redirect the call to the implementation contract and behave like the implementation contract's constructor

In Python, this would look as follows:

```python
    # deploy implementation
    IMPLEMENTATION = await starknet.deploy(
        "path/to/implementation.cairo",
        constructor_calldata=[]
    )

    # deploy proxy
    PROXY = await starknet.deploy(
        "path/to/proxy.cairo",
        constructor_calldata=[
            IMPLEMENTATION.contract_address,  # set implementation address
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

## Proxies

A proxy contract is a contract that delegates function calls to another contract. This type of pattern decouples state and logic. Proxy contracts store the state and redirect function calls to an implementation contract that handles the logic. This allows for different patterns such as upgrades, where implementation contracts can change but the proxy contract (and thus the state) does not; as well as deploying multiple proxy instances pointing to the same implementation. This can be useful to deploy many contracts with identical logic but unique initialization data.

In the case of contract upgrades, it is achieved by simply changing the proxy's reference to the implementation contract. This allows developers to add features, update logic, and fix bugs without touching the state or the contract address to interact with the application. 

### Proxy contract

The [Proxy contract](../openzeppelin/upgrades/Proxy.cairo) includes two core methods:  

1. The `__default__` method is a fallback method that redirects a function call and associated calldata to the implementation contract. 

2. The `__l1_default__` method is also a fallback method; however, it redirects the function call and associated calldata to a layer one contract. In order to invoke `__l1_default__`, the original function call must include the library function `send_message_to_l1`. See Cairo's [Interacting with L1 contracts](https://www.cairo-lang.org/docs/hello_starknet/l1l2.html) for more information.

Since this proxy is designed to work both as an [UUPS-flavored upgrade proxy](https://eips.ethereum.org/EIPS/eip-1822) as well as a non-upgradeable proxy, it does not know how to handle its own state. Therefore it requires the implementation contract to be deployed beforehand, so its address can be passed to the Proxy on construction time.

When interacting with the contract, function calls should be sent by the user to the proxy. The proxy's fallback function redirects the function call to the implementation contract to execute.


### Implementation contract

The implementation contract, also known as the logic contract, receives the redirected function calls from the proxy contract. The implementation contract should follow the [Extensibility pattern](../docs/Extensibility.md#the-pattern) and import directly from the [Proxy library](../openzeppelin/upgrades/library.cairo).
 

The implementation contract should:
- import `Proxy_initializer` and `Proxy_set_implementation`
- initialize the proxy immediately after contract deployment.

If the implementation is upgradeable, it should:
- include a method to upgrade the implementation (i.e. `upgrade`)
- use access control to protect the contract's upgradeability.

The implementation contract should NOT:
- deploy with a traditional constructor. Instead, use an initializer method that invokes `Proxy_initializer`.

> Note that the imported `Proxy_initializer` includes a check the ensures the initializer can only be called once; however, `Proxy_set_implementation` does not include this check. It's up to the developers to protect their implementation contract's upgradeability with access controls such as [`Proxy_only_admin`](#Proxy_only_admin). 

For a full implementation contract example, please see:
- [Proxiable implementation](../tests/mocks/proxiable_implementation.cairo)

## Upgrades library API

### Methods
```jsx
func Proxy_initializer(proxy_admin: felt):
end

func Proxy_set_implementation(new_implementation: felt):
end

func Proxy_only_admin():
end

func Proxy_get_admin() -> (admin: felt):
end

func Proxy_get_implementation() -> (implementation: felt):
end

func Proxy_set_admin(new_admin: felt):
end
```

#### `Proxy_initializer`

Initializes the proxy contract with an initial implementation.

Parameters:

```jsx
proxy_admin: felt
```

Returns:

None.

#### `Proxy_set_implementation`

Sets the implementation contract. This method is included in the proxy contract's constructor and is furthermore used to upgrade contracts.

Parameters:

```jsx
new_implementation: felt
```

Returns:

None.

#### `Proxy_only_admin`

Throws if called by any account other than the admin.

Parameters:

None.

Returns:

None.

#### `Proxy_get_admin`

Returns the current admin.

Parameters:

None.

Returns:

```jsx
admin: felt
```

#### `Proxy_get_implementation`

Returns the current implementation address.

Parameters:

None.

Returns:

```jsx
implementation: felt
```

#### `Proxy_set_admin`

Sets the admin of the proxy contract.

Parameters:

```jsx
new_admin: felt
```

Returns:

None.

### Events

```jsx
func Upgraded(implementation: felt):
end
```

#### `Upgraded`

Emitted when a proxy contract sets a new implementation address.

Parameters:

```jsx
implementation: felt
```

## Using proxies 

### Contract upgrades

To upgrade a contract, the implementation contract should include an `upgrade` method that, when called, changes the reference to a new deployed contract like this:


```python
    # deploy first implementation
    IMPLEMENTATION = await starknet.deploy(
        "path/to/implementation.cairo",
        constructor_calldata=[]
    )

    # deploy proxy
    PROXY = await starknet.deploy(
        "path/to/proxy.cairo",
        constructor_calldata=[
            IMPLEMENTATION.contract_address,  # set implementation address
        ]
    )

    # deploy implementation v2
    IMPLEMENTATION_V2 = await starknet.deploy(
        "path/to/implementation_v2.cairo",
        constructor_calldata=[]
    )

    # call upgrade with the new implementation contract address
    await signer.send_transaction(
        account, PROXY.contract_address, 'upgrade', [
            IMPLEMENTATION_V2.contract_address
        ]
    )
```

For a full deployment and upgrade implementation, please see:
- [Upgrades V1](../tests/mocks/upgrades_v1_mock.cairo)
- [Upgrades V2](../tests/mocks/upgrades_v2_mock.cairo)

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
- [ERC20_Upgradeable](../openzeppelin/token/erc20/ERC20_Upgradeable.cairo)
- more to come! have an idea? [open an issue](https://github.com/OpenZeppelin/cairo-contracts/issues/new/choose)!
