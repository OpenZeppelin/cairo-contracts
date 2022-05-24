# Extensibility

> Expect this pattern to evolve (as it has already done) or even disappear if [proper extensibility features](https://community.starknet.io/t/contract-extensibility-pattern/210/11?u=martriay) are implemented into Cairo.

* [The extensibility problem](#the-extensibility-problem)
* [The pattern ™️](#the-pattern)
  * [Libraries](#libraries)
  * [Contracts](#contracts)
* [Presets](#presets)
* [Function names and coding style](#function-names-and-coding-style)
* [Emulating hooks](#emulating-hooks)

## The extensibility problem

Smart contract development is a critical task. As with all software development, it is error prone; but unlike most scenarios, a bug can result in major losses for organizations as well as individuals. Therefore writing complex smart contracts is a delicate task.

One of the best approaches to minimize introducing bugs is to reuse existing, battle-tested code, a.k.a. using libraries. But code reutilization in StarkNet’s smart contracts is not easy:

* Cairo has no explicit smart contract extension mechanisms such as inheritance or composability
* Using imports for modularity can result in clashes (more so given that arguments are not part of the selector), and lack of overrides or aliasing leaves no way to resolve them
* Any `@external` function defined in an imported module will be automatically re-exposed by the importer (i.e. the smart contract)

To overcome these problems, this project builds on the following guidelines™.

## The pattern

The idea is to have two types of Cairo modules: libraries and contracts. Libraries define reusable logic and storage variables which can then be extended and exposed by contracts. Contracts can be deployed, libraries cannot.

To minimize risk, boilerplate, and avoid function naming clashes, we follow these rules:

### Libraries

Considering four types of functions:

* `internal`: internal to a library, not meant to be used outside the module or imported
* `public`: part of the public API of a library
* `external`: subset of `public` that is ready to be exported as-is by contracts
* `storage`: storage variable functions

Then:

* Must implement `public` and `external` functions under a namespace
* Must implement `internal` functions outside the namespace to avoid exposing them
* Must prefix `public` functions with an underscore (e.g. `ERC20._mint`)
* Must not prefix `external` functions with an underscore (e.g. `ERC20.transfer`)
* Must prefix `storage` functions with the name of the namespace to prevent clashing with other libraries (e.g. `ERC20_balances`)
* Must not implement any `@external`, `@view`, or `@constructor` functions
* Can implement initializers (never as `@constructor` or `@external`)
* Must not call initializers on any function

### Contracts

* Can import from libraries
* Should implement `@external` functions if needed
* Should implement a `@constructor` function that calls initializers
* Must not call initializers in any function beside the constructor

Note that since initializers will never be marked as `@external` and they won’t be called from anywhere but the constructor, there’s no risk of re-initialization after deployment. It’s up to the library developers not to make initializers interdependent to avoid weird dependency paths that may lead to double construction of libraries.

## Presets

Presets are pre-written contracts that extend from our library of contracts. They can be deployed as-is or used as templates for customization.

Some presets are:

* [Account](../src/openzeppelin/account/Account.cairo)
* [ERC165](../tests/mocks/ERC165.cairo)
* [ERC20_Mintable](../src/openzeppelin/token/erc20/ERC20_Mintable.cairo)
* [ERC20_Pausable](../src/openzeppelin/token/erc20/ERC20_Pausable.cairo)
* [ERC20_Upgradeable](../src/openzeppelin/token/erc20/ERC20_Upgradeable.cairo)
* [ERC20](../src/openzeppelin/token/erc20/ERC20.cairo)
* [ERC721_Mintable_Burnable](../src/openzeppelin/token/erc721/ERC721_Mintable_Burnable.cairo)
* [ERC721_Mintable_Pausable](../src/openzeppelin/token/erc721/ERC721_Mintable_Pausable.cairo)
* [ERC721_Enumerable_Mintable_Burnable](../src/openzeppelin/token/erc721_enumerable/ERC721_Enumerable_Mintable_Burnable.cairo)

## Function names and coding style

* Following Cairo's programming style, we use `snake_case` for library APIs (e.g. `ERC20.transfer_from`, `ERC721.safe_transfer_from`).
* But for standard EVM ecosystem compatibility, we implement external functions in contracts using `camelCase` (e.g. `transferFrom` in a ERC20 contract).
* Guard functions such as the so-called "only owner" are prefixed with `assert_` (e.g. `Ownable.assert_only_owner`).

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
    Pausable.assert_not_paused()
    ERC20.transfer(recipient, amount)
    return (TRUE)
end
```
