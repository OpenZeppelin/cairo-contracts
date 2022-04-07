# Security

 The following documentation provides context, reasoning, and examples of methods and constants found in `openzeppelin/security/`. 
 
 > Expect this module to evolve. 

 ## Table of Contents 

 * [Reentrancy Guard](#Reentrancy-Guard) 
 
 ## Reentrancy Guard 
 
A [reentrancy attack](https://gus-tavo-guim.medium.com/reentrancy-attack-on-smart-contracts-how-to-identify-the-exploitable-and-an-example-of-an-attack-4470a2d8dfe4) occurs when the caller is able to obtain more resources than allowed by recursively calling a target’s function.

Since Cairo does not support modifiers like Solidity, the [`reentrancy_guard`](../src/openzeppelin/security/reentrancy_guard.cairo) library exposes two methods `ReentrancyGuard_start` and `ReentrancyGuard_end` to protect functions against reentrancy attacks. The protected function must call `ReentrancyGuard_start` before the first function statement, and `ReentrancyGuard_end` before the return statement, as shown below:

```
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

