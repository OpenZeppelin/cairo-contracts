# Access

> Expect these modules to evolve.

Access control—that is, "who is allowed to do this thing"—is incredibly important in the world of smart contracts. The access control of your contract may govern who can mint tokens, vote on proposals, freeze transfers, and many other things. It is therefore critical to understand how you implement it, lest someone else [steals your whole system](https://blog.openzeppelin.com/on-the-parity-wallet-multisig-hack-405a8c12e8f7/).

## Table of Contents

* [Ownable](#ownable)
  * [Quickstart](#quickstart)
  * [Ownable library functions](#ownable-library-functions)
    * [`assert_only_owner`](#assert_only_owner)
    * [`owner`](#owner)
    * [`transfer_ownership`](#transfer_ownership)
    * [`renounce_ownership`](#renounce_ownership)
  * [Ownable events](#ownable-events)
    * [`OwnershipTransferred`](#ownershiptransferred)

## Ownable

The most common and basic form of access control is the concept of ownership: there’s an account that is the `owner` of a contract and can do administrative tasks on it. This approach is perfectly reasonable for contracts that have a single administrative user.

OpenZeppelin Contracts provides Ownable for implementing ownership in your contracts.

### Quickstart

This library's initializer simply consists of assigning an owner within the constructor of a Cairo contract like this:

```cairo
from openzeppelin.access.ownable import Ownable

@constructor
func constructor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(owner: felt):
    Ownable.initializer(owner)
    return ()
end
```

To restrict a function's access to the owner only, add in the `assert_only_owner` method like this:

```cairo
from openzeppelin.access.ownable import Ownable

func protected_function{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    Ownable.assert_only_owner()
    return ()
end
```

### Ownable library functions

```cairo
func assert_only_owner():
end

func owner() -> (owner: felt):
end

func transfer_ownership(new_owner: felt):
end

func renounce_ownership():
end
```

#### `assert_only_owner`

Reverts if called by any account other than the owner.

Parameters:

None.

Returns:

None.

#### `owner`

Returns the address of the current owner.

Parameters:

None.

Returns:

```cairo
owner: felt
```

#### `transfer_ownership`

Transfers ownership of the contract to a new account (`new_owner`). Can only be called by the current owner.

Emits a [`OwnershipTransferred`](#ownershiptransferred) event.

Parameters:

```cairo
new_owner: felt
```

Returns:

None.

#### `renounce_ownership`

Leaves the contract without owner. It will not be possible to call functions with `assert_only_owner` anymore. Can only be called by the current owner.

Emits a [`OwnershipTransferred`](#ownershiptransferred) event.

Parameters:

None.

Returns:

None.

### Ownable events

```cairo
func OwnershipTransferred(previousOwner: felt, newOwner: felt):
end
```

#### OwnershipTransferred

Emitted when ownership of a contract is transferred from `previousOwner` to `newOwner`.

Parameters:

```cairo
previousOwner: felt
newOwner: felt
```
