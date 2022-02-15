# Proxy

## Table of Contents
* [The immutability problem](#the-immutability-problem)
* [Using proxies](#using-proxies)
  * [Proxy contract](#proxy-contract) 
  * [Proxy library](#proxy-library) 
  * [Implementation contract](#implementation-contract)
* [Presets](#presets)

## The immutability problem

The immutable nature of smart contracts indeed is a feature. Upon deployment, the deterministic logic of a smart contract will execute regardless of external factors. The myriad benefits of immutability are well-documented; however, this very feature is not without its drawbacks such as the inability to add new features or fix bugs. The consquences of these limitations range from cumbersome to devastating. 

One of the best approaches to the immutability problem lies in utilizing proxy contracts. 

## Using proxies

A proxy contract is a contract that delegates function calls to another contract. This type of pattern compartmentalizes state and logic. Proxy contracts store the state and redirect function calls to an implementation contract that handles the logic. With this pattern, implementation contracts can change but the proxy contract (and thus the state) do not. This allows developers to add features, update logic, and fix bugs without touching the state or the contract address to interact with the application. 

### Proxy contract

The Proxy contract includes two core methods: `__default__` and `__l1_default__`. The `__default__` method is a fallback method that redirects a function call and associated calldata to the implementation contract. 

The `__l1_default__` method is also a fallback method; however, it redirects the function call and associated calldata to a layer one contract. In order to invoke `__l1_default__`, the original function call must include the library function `send_message_to_l1`. See Cairo's [Interacting with L1 contracts](https://www.cairo-lang.org/docs/hello_starknet/l1l2.html) for more information.

Deploying a Proxy contract requires only that the implementation contract is first deployed. The Proxy contract accepts the implementation contract's address in the constructor. When interacting with the contract, function calls should be sent by the user to the Proxy. The Proxy's fallback function redirects the function call to the implementation contract to execute. For example:

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

    # transactions should be sent to the proxy contract address
    await signer.send_transaction(
        account, PROXY.contract_address, 'foo', [
            arg_1,
            arg_2
        ]
    )
```

### Proxy library


