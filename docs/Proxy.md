# Proxy

> Expect rapid iteration as this pattern matures and more patterns potentially emerge. 

## Table of Contents
* [The immutability problem](#the-immutability-problem)
* [Proxies](#proxies)
  * [Proxy contract](#proxy-contract) 
  * [Implementation contract](#implementation-contract)
* [Using proxies](#using-proxies)
  * [Deploy and upgrade contracts](#deploy-and-upgrade-contracts)
  * [Handling method calls](#handling-method-calls)
* [Presets](#presets)

## The immutability problem

The immutable nature of smart contracts indeed is a feature. Upon deployment, the deterministic logic of a smart contract will execute regardless of external factors. The myriad benefits of immutability are well-documented; however, this very feature is not without its drawbacks such as the inability to add new features or fix bugs. The consquences of these limitations range from cumbersome to devastating. 

One of the best approaches to the immutability problem lies in utilizing proxy contracts. 

## Proxies

A proxy contract is a contract that delegates function calls to another contract. This type of pattern compartmentalizes state and logic. Proxy contracts store the state and redirect function calls to an implementation contract that handles the logic. With this pattern, implementation contracts can change but the proxy contract (and thus the state) do not. Upgradeability is then achieved by simply changing the reference to the implementation contract in the proxy contract. This allows developers to add features, update logic, and fix bugs without touching the state or the contract address to interact with the application. 

### Proxy contract

The [Proxy contract](../contracts/proxy/Proxy.cairo) includes two core methods:  

1. The `__default__` method is a fallback method that redirects a function call and associated calldata to the implementation contract. 

2. The `__l1_default__` method is also a fallback method; however, it redirects the function call and associated calldata to a layer one contract. In order to invoke `__l1_default__`, the original function call must include the library function `send_message_to_l1`. See Cairo's [Interacting with L1 contracts](https://www.cairo-lang.org/docs/hello_starknet/l1l2.html) for more information.

Deploying a Proxy contract requires only that the implementation contract is first deployed. The Proxy contract accepts the implementation contract's address in the constructor. When interacting with the contract, function calls should be sent by the user to the Proxy. The Proxy's fallback function redirects the function call to the implementation contract to execute.


### Implementation contract

The implementation contract, also known as the logic contract, receives the redirected function calls from the Proxy contract. The upgradeable pattern should follow the [extensibility pattern](../docs/Extensibility.md#the-pattern) and import directly from the [Proxy library](../contracts/proxy/library.cairo). 

The implementation contract should:
- import `Proxy_initializer` and `Proxy_set_implementation`
- initialize the Proxy immediately after contract deployment
- include a method to upgrade the implementation (i.e. `upgrade`)
- use access control to protect the contract's upgradeability

The implementation contract should NOT:
- deploy with a traditional constructor—use an initializer method instead that invokes `Proxy_initializer` and the implementation contract's initializer

Note that the imported `Proxy_initializer` includes a check the ensures the initializer can only be called once; however, `Proxy_set_implementation` does not include this check. It's up to the developers to protect their implementation contract's upgradeability with access controls such as `Proxy_only_admin`. 

For a full implementation contract example, please see:
- [Dummy implementation](../tests/mocks/dummy_implementation.cairo)

## Using proxies 

### Deploy and upgrade contracts

Putting this all together, the basic flow of deployment is as follows:
- deploy implementation contract
- deploy Proxy contract with the implementation contract's address set in the proxy's constructor calldata
- initialize the implementation contract by sending a call to the Proxy contract. This will redirect the call to the implementation contract and behave like the implementation contract's constructor

Proxy and implementation contract deployments should look like this:

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

    # users should interact with the proxy contract
    await signer.send_transaction(
        account, PROXY.contract_address, 'foo', [
            arg_1,
            arg_2
        ]
    )
```

To upgrade, deploy the upgraded implementation contract and then call the `upgrade` method like this:

```python
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

For deployment and upgrade implementation, please see:
- [Proxy test](../tests/test_Proxy.py)
- [ERC20_Upgradeable test](../tests/test_ERC20_Upgradeable.py)

### Handling method calls

As with most StarkNet contracts, interacting with a Proxy contract requires an [account abstraction](../docs/Account.md#quickstart). One notable difference with Proxy contracts versus other contract implementations is that calling `@view` methods also requires an account abstraction. The differences written in Python, for example, are as follows:

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
- [ERC20_Upgradeable](../contracts/token/ERC20_Upgradeable.cairo)
- more to come!
