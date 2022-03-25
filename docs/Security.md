# Security

 The following documentation provides context, reasoning, and examples of methods and constants found in `openzeppelin/security/`. 
 
 > Expect this module to evolve. 

 ## Table of Contents 

 * [Reentrancy Guard](#Reentrancy-Guard) 
 
 ## Reentrancy Guard 
 
A reentrancy attack occurs when the caller is able to obtain more resources than allowed by recursively calling a target’s function.

Since Cairo does not support modifiers like Solidity, the `reentrancy_guard` library exposes two functions `ReentrancyGuard_start` and `ReentrancyGuard_end` to protect functions against reentrancy attacks. The protected function must call `ReentrancyGuard_start` before the first function statement, and `ReentrancyGuard_end` before the return statement.
