# Security

 The following documentation provides context, reasoning, and examples of methods and constants found in `openzeppelin/security/`.

 > Expect this module to evolve.

## Table of Contents

* [Initializable](#initializable)
* [Reentrancy Guard](#Reentrancy-Guard)

## Initializable

The Initializable library provides a simple mechanism that mimics the functionality of a constructor. More specifically, it enables logic to be performed once and only once which is commonly used to setup a contract's initial state. This is especially useful for proxy contracts and upgradeable contracts since they first need to be deployed before the state of the implementation contract can be set (see [constructors](../docs/Proxies.md#constructors) for more info).

> Please note that Initializable should only be used once and only on one function. Subsequent uses will clash.

The basic design utilizes Cairo booleans and leverages the initial state of storage variables (`0` or `FALSE` as a boolean). Once `initialize` is invoked, then the `initialized` storage variable equates to `TRUE`. The recommended pattern with Initializable is to include a check that the Initializable state is `False` and invoke `initialize` in the target function like this:

```cairo
from openzeppelin.security.initializable import Initializable

@external
func foo{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (initialized) = Initializable.initialized()
    assert initialized = FALSE

    Initializable.initialize()
    return ()
end
```

## Reentrancy Guard

A [reentrancy attack](https://gus-tavo-guim.medium.com/reentrancy-attack-on-smart-contracts-how-to-identify-the-exploitable-and-an-example-of-an-attack-4470a2d8dfe4) occurs when the caller is able to obtain more resources than allowed by recursively calling a target’s function.

Since Cairo does not support modifiers like Solidity, the [`reentrancy_guard`](../src/openzeppelin/security/reentrancy_guard.cairo) library exposes two methods `ReentrancyGuard_start` and `ReentrancyGuard_end` to protect functions against reentrancy attacks. The protected function must call `ReentrancyGuard_start` before the first function statement, and `ReentrancyGuard_end` before the return statement, as shown below:

```cairo
from openzeppelin.security.reentrancy_guard import (
    ReentrancyGuard_start,
    ReentrancyGuard_end
)

func test_function{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
   ReentrancyGuard_start()
   # function body
   ReentrancyGuard_end()
   return ()
end
```
