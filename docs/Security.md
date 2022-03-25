# Security

 The following documentation provides context, reasoning, and examples of methods and constants found in `openzeppelin/security/`. 
 
 > Expect this module to evolve. 

 ## Table of Contents 

 * [Reentrancy Guard](#Reentrancy Guard) 
 
 ## Reentrancy Guard 
 
 A reentrancy attack occurs when the caller is able to obtain more resources than allowed by recursively calling a target’s function. Unlike the Solidity, cairo does not support modifiers, so instead, to deal with reentrancy attacks, we have a cairo contract, reentrancy_guard.cairo with two functions `ReentrancyGuard_start` and `ReentrancyGuard_end`. The protected function must be called `ReentrancyGuard_start` before the first function statement, and `ReentrancyGuard_end` before the return statement.