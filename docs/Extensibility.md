# Extensibility

> Expect this pattern to evolve (as it has already done) or even disappear if [proper extensibility features](https://community.starknet.io/t/contract-extensibility-pattern/210/11?u=martriay) are implemented into Cairo.

* [The extensibility problem](#the-extensibility-problem)
* [The pattern ™️](#the-pattern)
  * [Libraries](#libraries)
  * [Contracts](#contracts)
* [Presets](#presets)
* [Emulating hooks](#emulating-hooks)

## The extensibility problem

Smart contract development is a critical task. As with all software development, it is error prone; but unlike most scenarios, a bug can result in major losses for organizations as well as individuals. Therefore writing complex smart contracts is a delicate task.

One of the best approaches to minimize introducing bugs is to reuse existing, battle-tested code, a.k.a. using libraries. But code reutilization in StarkNet’s smart contracts is not easy:

- Cairo has no explicit smart contract extension mechanisms such as inheritance or composability
- Using imports for modularity can result in clashes (more so given that arguments are not part of the selector), and lack of overrides or aliasing leaves no way to resolve them
- Any `@external` function defined in an imported module will be automatically re-exposed by the importer (i.e. the smart contract)

To overcome these problems, this project builds on the following guidelines™.

## The pattern

The idea is to have two types of Cairo modules: libraries and contracts. Libraries define reusable logic and storage variables which can then be extended and exposed by contracts. Contracts can be deployed, libraries cannot.

To minimize risk, boilerplate, and avoid function naming clashes, we follow these rules:

### Libraries

- All function and storage variable names must be prefixed with the file name to prevent clashing with other libraries (e.g. `ERC20_approve` in the `ERC20` library)
- Must not implement any `@external` or `@view` functions
- Must not implement constructors
- Must not call initializers on any function
- Should implement initializer functions to mimic construction logic if needed (as any other library function, never as `@external`)

### Contracts

- Can import from libraries
- Should implement `@external` functions if needed
- Should implement a constructor that calls initializers
- Must not call initializers in any function beside the constructor

Note that since initializers will never be marked as `@external` and they won’t be called from anywhere but the contract constructor, there’s no risk of re-initialization after deployment. It’s up to the library developers not to make initializers interdependent to avoid weird dependency paths that may lead to double initialization of libraries.

## Presets

Presets are pre-written contracts that extend from our library of contracts. They can be deployed as-is or used as templates for customization.

Some presets are:

- [Account](../openzeppelin/account/Account.cairo)
- [ERC165](../tests/mocks/ERC165.cairo)
- [ERC20_Mintable](../openzeppelin/token/erc20/ERC20_Mintable.cairo)
- [ERC20_Pausable](../openzeppelin/token/erc20/ERC20_Pausable.cairo)
- [ERC20_Upgradeable](../openzeppelin/token/erc20/ERC20_Upgradeable.cairo)
- [ERC20](../openzeppelin/token/erc20/ERC20.cairo)
- [ERC721_Mintable_Burnable](../openzeppelin/token/erc721/ERC721_Mintable_Burnable.cairo)
- [ERC721_Mintable_Pausable](../openzeppelin/token/erc721/ERC721_Mintable_Pausable.cairo)
- [ERC721_Enumerable_Mintable_Burnable](../openzeppelin/token/erc721_enum/ERC721_Enumerable_Mintable_Burnable.cairo)

## Emulating hooks

Unlike the Solidity version of [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts), this library does not implement [hooks](https://docs.openzeppelin.com/contracts/4.x/extending-contracts#using-hooks). The main reason being that Cairo does not support overriding functions.

This is what a hook looks like in Solidity:

```js
abstract contract ERC20Pausable is ERC20, Pausable {
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        require(!paused(), "ERC20Pausable: token transfer while paused");
    }
}
```

Instead, the extensibility pattern allows us to simply extend the library implementation of a function (namely `transfer`) by adding lines before or after calling it. This way, we can get away with:

```python
@external
func transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(recipient: felt, amount: Uint256) -> (success: felt):
    Pausable_when_not_paused()
    ERC20_transfer(recipient, amount)
    return (TRUE)
end
```
