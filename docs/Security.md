# Security

 The following documentation provides context, reasoning, and examples of methods and constants found in `openzeppelin/security/`.

 > Expect this module to evolve.

## Table of Contents

* [Initializable](#initializable)
* [Reentrancy Guard](#Reentrancy-Guard)

## Initializable

The Initializable library provides a simple mechanism that mimics the functionality of a constructor. More specifically, it enables logic to be performed once and only once which is useful to setup a contract's initial state when a constructor cannot be used.

The recommended pattern with Initializable is to include a check that the Initializable state is `False` and invoke `initialize` in the target function like this:

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

> Please note that this Initializable pattern should only be used on one function.

## Reentrancy Guard

A [reentrancy attack](https://gus-tavo-guim.medium.com/reentrancy-attack-on-smart-contracts-how-to-identify-the-exploitable-and-an-example-of-an-attack-4470a2d8dfe4) occurs when the caller is able to obtain more resources than allowed by recursively calling a target’s function.

Since Cairo does not support modifiers like Solidity, the [`reentrancy_guard`](../src/openzeppelin/security/reentrancy_guard.cairo) library exposes two methods `start` and `end_` to protect functions against reentrancy attacks. The protected function must call `ReentrancyGuard.start` before the first function statement, and `ReentrancyGuard.end_` before the return statement, as shown below:

```cairo
from openzeppelin.security.reentrancy_guard import ReentrancyGuard

func test_function{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
   ReentrancyGuard.start()
   # function body
   ReentrancyGuard.end_()
   return ()
end
```

> Note that `Reentrancy.end_` includes the appended underscore because `end` itself is a [protected keyword](https://github.com/starkware-libs/cairo-lang/blob/master/src/starkware/cairo/lang/ide/vim/syntax/cairo.vim) in Cairo.
