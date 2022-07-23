# Access

> Expect these modules to evolve.

Access control—that is, "who is allowed to do this thing"—is incredibly important in the world of smart contracts. The access control of your contract may govern who can mint tokens, vote on proposals, freeze transfers, and many other things. It is therefore critical to understand how you implement it, lest someone else [steals your whole system](https://blog.openzeppelin.com/on-the-parity-wallet-multisig-hack-405a8c12e8f7/).

## Table of Contents

* [Ownable](#ownable)
  * [Quickstart](#quickstart)
  * [Ownable library API](#ownable-library-api)
    * [`initializer`](#initializer)
    * [`assert_only_owner`](#assert_only_owner)
    * [`owner`](#owner)
    * [`transfer_ownership`](#transfer_ownership)
    * [`renounce_ownership`](#renounce_ownership)
    * [`_transfer_ownership`](#transfer-ownership-internal)
  * [Ownable events](#ownable-events)
    * [`OwnershipTransferred`](#ownershiptransferred)
* [AccessControl](#accesscontrol)
  * [Usage](#usage)
  * [Granting and revoking roles](#granting-and-revoking-roles)
  * [Creating role identifiers](#creating-role-identifiers)
  * [AccessControl library API](#accesscontrol-library-api)
    * [`initializer`](#initializer-accesscontrol)
    * [`assert_only_role`](#assert_only_role)
    * [`has_role`](#has_role)
    * [`get_role_admin`](#get_role_admin)
    * [`grant_role`](#grant_role)
    * [`revoke_role`](#revoke_role)
    * [`renounce_role`](#renounce_role)
    * [`_grant_role`](#grantrole-internal)
    * [`_revoke_role`](#revokerole-internal)
    * [`_set_role_admin`](#setroleadmin)
  * [AccessControl events](#accesscontrol-events)
    * [`RoleGranted`](#rolegranted)
    * [`RoleRevoked`](#rolerevoked)
    * [`RoleAdminChanged`](#roleadminchanged)

## Ownable

The most common and basic form of access control is the concept of ownership: there’s an account that is the `owner` of a contract and can do administrative tasks on it. This approach is perfectly reasonable for contracts that have a single administrative user.

OpenZeppelin Contracts for Cairo provides [Ownable](../src/openzeppelin/access/ownable/library.cairo) for implementing ownership in your contracts.

### Quickstart

Integrating [Ownable](../src/openzeppelin/access/library.cairo) into a contract first requires assigning an owner. The implementing contract's constructor should set the initial owner by passing the owner's address to Ownable's [initializer](#initializer) like this:

```cairo
from openzeppelin.access.ownable.library import Ownable

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

To restrict a function's access to the owner only, add in the `assert_only_owner` method:

```cairo
from openzeppelin.access.ownable.library import Ownable

func protected_function{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    Ownable.assert_only_owner()
    return ()
end
```

### Ownable library API

```cairo
func initializer(owner: felt):
end

func assert_only_owner():
end

func owner() -> (owner: felt):
end

func transfer_ownership(new_owner: felt):
end

func renounce_ownership():
end

func _transfer_ownership(new_owner: felt):
end
```

#### `initializer`

Initializes Ownable access control and should be called in the implementing contract's constructor. Assigns `owner` as the initial owner address of the contract.

This must be called only once.

Parameters:

```cairo
owner: felt
```

Returns:

None.

#### `assert_only_owner`

Reverts if called by any account other than the owner. In case of renounced ownership, any call from the default zero address will also be reverted.

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

<h4 id="transfer-ownership-internal"><code>_transfer_ownership</code></h4>

Transfers ownership of the contract to a new account (`new_owner`). [`internal`](./Extensibility.md#the-pattern) function without access restriction.

Emits a [`OwnershipTransferred`](#ownershiptransferred) event.

Parameters:

```cairo
new_owner: felt
```

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

## AccessControl

While the simplicity of ownership can be useful for simple systems or quick prototyping, different levels of authorization are often needed. You may want for an account to have permission to ban users from a system, but not create new tokens. [Role-Based Access Control (RBAC)](https://en.wikipedia.org/wiki/Role-based_access_control) offers flexibility in this regard.

In essence, we will be defining multiple roles, each allowed to perform different sets of actions. An account may have, for example, 'moderator', 'minter' or 'admin' roles, which you will then check for instead of simply using [assert_only_owner](#assert_only_owner). This check can be enforced through [assert_only_role](#assert_only_role). Separately, you will be able to define rules for how accounts can be granted a role, have it revoked, and more.

Most software uses access control systems that are role-based: some users are regular users, some may be supervisors or managers, and a few will often have administrative privileges.

### Usage

For each role that you want to define, you will create a new *role identifier* that is used to grant, revoke, and check if an account has that role (see [Creating role identifiers](#creating-role-identifiers) for information on creating identifiers).

Here's a simple example of implementing `AccessControl` on a portion of an [ERC20 token contract](../src/openzeppelin/token/erc20/presets/ERC20.cairo) which defines and sets the 'minter' role:

```cairo
from openzeppelin.token.erc20.library import ERC20

from openzeppelin.access.accesscontrol.library import AccessControl


const MINTER_ROLE = 0x4f96f87f6963bb246f2c30526628466840c642dc5c50d5a67777c6cc0e44ab5

@constructor
func constructor{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        name: felt,
        symbol: felt,
        decimals: felt,
        minter: felt
    ):
    ERC20.initializer(name, symbol, decimals)
    AccessControl.initializer()
    AccessControl._grant_role(MINTER_ROLE, minter)
    return ()
end

@external
func mint{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(to: felt, amount: Uint256):
    AccessControl.assert_only_role(MINTER_ROLE)
    ERC20._mint(to, amount)
    return ()
end
```

> Make sure you fully understand how [AccessControl](#accesscontrol) works before using it on your system, or copy-pasting the examples from this guide.

While clear and explicit, this isn’t anything we wouldn’t have been able to achieve with [Ownable](#ownable). Indeed, where `AccessControl` shines is in scenarios where granular permissions are required, which can be implemented by defining *multiple* roles.

Let’s augment our ERC20 token example by also defining a 'burner' role, which lets accounts destroy tokens, and by using `assert_only_role`:

```cairo
from openzeppelin.token.erc20.library import ERC20

from openzeppelin.access.accesscontrol.library import AccessControl


const MINTER_ROLE = 0x4f96f87f6963bb246f2c30526628466840c642dc5c50d5a67777c6cc0e44ab5
const BURNER_ROLE = 0x7823a2d975ffa03bed39c38809ec681dc0ae931ebe0048c321d4a8440aed509

@constructor
func constructor{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        name: felt,
        symbol: felt,
        decimals: felt,
        minter: felt,
        burner: felt
    ):
    ERC20.initializer(name, symbol, decimals)
    AccessControl.initializer()
    AccessControl._grant_role(MINTER_ROLE, minter)
    AccessControl._grant_role(BURNER_ROLE, burner)
    return ()
end

@external
func mint{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(to: felt, amount: Uint256):
    AccessControl.assert_only_role(MINTER_ROLE)
    ERC20._mint(to, amount)
    return ()
end

@external
func burn{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(from_: felt, amount: Uint256):
    AccessControl.assert_only_role(BURNER_ROLE)
    ERC20._burn(from_, amount)
    return ()
end
```

So clean! By splitting concerns this way, more granular levels of permission may be implemented than were possible with the simpler ownership approach to access control. Limiting what each component of a system is able to do is known as the [principle of least privilege](https://en.wikipedia.org/wiki/Principle_of_least_privilege), and is a good security practice. Note that each account may still have more than one role, if so desired.

### Granting and revoking roles

The ERC20 token example above uses `_grant_role`, an [`internal`](./Extensibility.md#the-pattern) function that is useful when programmatically assigning roles (such as during construction). But what if we later want to grant the 'minter' role to additional accounts?

By default, **accounts with a role cannot grant it or revoke it from other accounts**: all having a role does is making the `assert_only_role` check pass. To grant and revoke roles dynamically, you will need help from the role’s *admin*.

Every role has an associated admin role, which grants permission to call the `grant_role` and `revoke_role` functions. A role can be granted or revoked by using these if the calling account has the corresponding admin role. Multiple roles may have the same admin role to make management easier. A role’s admin can even be the same role itself, which would cause accounts with that role to be able to also grant and revoke it.

This mechanism can be used to create complex permissioning structures resembling organizational charts, but it also provides an easy way to manage simpler applications. `AccessControl` includes a special role with the role identifier of `0`, called `DEFAULT_ADMIN_ROLE`, which acts as the **default admin role for all roles**. An account with this role will be able to manage any other role, unless `_set_role_admin` is used to select a new admin role.

Let’s take a look at the ERC20 token example, this time taking advantage of the default admin role:

```cairo
from openzeppelin.token.erc20.library import ERC20

from openzeppelin.access.accesscontrol import AccessControl

from openzeppelin.utils.constants.library import DEFAULT_ADMIN_ROLE


const MINTER_ROLE = 0x4f96f87f6963bb246f2c30526628466840c642dc5c50d5a67777c6cc0e44ab5
const BURNER_ROLE = 0x7823a2d975ffa03bed39c38809ec681dc0ae931ebe0048c321d4a8440aed509

@constructor
func constructor{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        name: felt,
        symbol: felt,
        decimals: felt,
        admin: felt,
    ):
    ERC20.initializer(name, symbol, decimals)
    AccessControl.initializer()

    AccessControl._grant_role(DEFAULT_ADMIN_ROLE, admin)
    return ()
end

@external
func mint{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(to: felt, amount: Uint256):
    AccessControl.assert_only_role(MINTER_ROLE)
    ERC20._mint(to, amount)
    return ()
end

@external
func burn{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(from_: felt, amount: Uint256):
    AccessControl.assert_only_role(BURNER_ROLE)
    ERC20._burn(from_, amount)
    return ()
end
```

Note that, unlike the previous examples, no accounts are granted the 'minter' or 'burner' roles. However, because those roles' admin role is the default admin role, and that role was granted to the 'admin', that same account can call `grant_role` to give minting or burning permission, and `revoke_role` to remove it.

Dynamic role allocation is often a desirable property, for example in systems where trust in a participant may vary over time. It can also be used to support use cases such as [KYC](https://en.wikipedia.org/wiki/Know_your_customer), where the list of role-bearers may not be known up-front, or may be prohibitively expensive to include in a single transaction.

The following example uses the [AccessControl mock contract](../tests/mocks/AccessControl.cairo) which exposes the role management functions. To grant and revoke roles in Python, for example:

```python
MINTER_ROLE = 0x4f96f87f6963bb246f2c30526628466840c642dc5c50d5a67777c6cc0e44ab5
BURNER_ROLE = 0x7823a2d975ffa03bed39c38809ec681dc0ae931ebe0048c321d4a8440aed509

# grants MINTER_ROLE and BURNER_ROLE to account1 and account2 respectively
await signer.send_transactions(
    admin, [
        (accesscontrol.contract_address, 'grantRole', [MINTER_ROLE, account1.contract_address]),
        (accesscontrol.contract_address, 'grantRole', [BURNER_ROLE, account2.contract_address])
    ]
)

# revokes MINTER_ROLE from account1
await signer.send_transaction(
    admin,
    accesscontrol.contract_address,
    'revokeRole',
    [MINTER_ROLE, account1.contract_address]
)
```

### Creating role identifiers

In the Solidity implementation of AccessControl, contracts generally refer to the [keccak256 hash](https://docs.soliditylang.org/en/latest/units-and-global-variables.html?highlight=keccak256#mathematical-and-cryptographic-functions) of a role as the role identifier. For example:

```solidity
bytes32 public constant SOME_ROLE = keccak256("SOME_ROLE")
```

These identifiers take up 32 bytes (256 bits).

Cairo field elements store a maximum of 252 bits. Even further, a declared *constant* field element in a StarkNet contract stores even less (see [cairo_constants](https://github.com/starkware-libs/cairo-lang/blob/167b28bcd940fd25ea3816204fa882a0b0a49603/src/starkware/cairo/lang/cairo_constants.py#L1)). With this discrepancy, this library maintains an agnostic stance on how contracts should create identifiers. Some ideas to consider:

* using the first or last 251 bits of keccak256 hash digests
* using Cairo's [hash2](https://github.com/starkware-libs/cairo-lang/blob/master/src/starkware/cairo/common/hash.cairo)

### AccessControl library API

```cairo
func initializer():
end

func assert_only_role(role: felt):
end

func has_role(role: felt, user: felt) -> (has_role: felt):
end

func get_role_admin(role: felt) -> (admin: felt):
end

func grant_role(role: felt, user: felt):
end

func revoke_role(role: felt, user: felt):
end

func renounce_role(role: felt, user: felt):
end

func _grant_role(role: felt, user: felt):
end

func _revoke_role(role: felt, user: felt):
end

func _set_role_admin(role: felt, admin_role: felt):
end
```

<h4 id="initializer-accesscontrol"><code>initializer</code></h4>

Initializes AccessControl and should be called in the implementing contract's constructor.

This must only be called once.

Parameters:

None.

Returns:

None.

#### `assert_only_role`

Checks that an account has a specific role. Reverts with a message including the required role.

Parameters:

```cairo
role: felt
```

Returns:

None.

#### has_role

Returns `TRUE` if `user` has been granted `role`, `FALSE` otherwise.

Parameters:

```cairo
role: felt
user: felt
```

Returns:

```cairo
has_role: felt
```

#### `get_role_admin`

Returns the admin role that controls `role`. See [grant_role](#grant_role) and [revoke_role](#revoke_role).

To change a role’s admin, use [_set_role_admin](#_set_role_admin).

Parameters:

```cairo
role: felt
```

Returns:

```cairo
admin: felt
```

#### `grant_role`

Grants `role` to `user`.

If `user` had not been already granted `role`, emits a [RoleGranted](#rolegranted) event.

Requirements:

* the caller must have `role`'s admin role.

Parameters:

```cairo
role: felt
user: felt
```

Returns:

None.

#### `revoke_role`

Revokes `role` from `user`.

If `user` had been granted `role`, emits a [RoleRevoked](#rolerevoked) event.

Requirements:

* the caller must have `role`'s admin role.

Parameters:

```cairo
role: felt
user: felt
```

Returns:

None.

#### `renounce_role`

Revokes `role` from the calling `user`.

Roles are often managed via [grant_role](#grant_role) and [revoke_role](#revoke_role): this function’s purpose is to provide a mechanism for accounts to lose their privileges if they are compromised (such as when a trusted device is misplaced).

If the calling `user` had been revoked `role`, emits a [RoleRevoked](#rolerevoked) event.

Requirements:

* the caller must be `user`.

Parameters:

```cairo
role: felt
user: felt
```

Returns:

None.

<h4 id="grantrole-internal"><code>_grant_role</code></h4>

Grants `role` to `user`.

[`internal`](./Extensibility.md#the-pattern) function without access restriction.

Emits a [RoleGranted](#rolegranted) event.

Parameters:

```cairo
role: felt
user: felt
```

Returns:

None.

<h4 id="revokerole-internal"><code>_revoke_role</code></h4>

Revokes `role` from `user`.

[`internal`](./Extensibility.md#the-pattern) function without access restriction.

Emits a [RoleRevoked](#rolerevoked) event.

Parameters:

```cairo
role: felt
user: felt
```

Returns:

None.

<h4 id="setroleadmin"><code>_set_role_admin</code></h4>

[`internal`](./Extensibility.md#the-pattern) function that sets `admin_role` as `role`'s admin role.

Emits a [RoleAdminChanged](#roleadminchanged) event.

Parameters:

```cairo
role: felt
admin_role: felt
```

Returns:

None.

### AccessControl events

```cairo
func RoleGranted(role: felt, account: felt, sender: felt):
end

func RoleRevoked(role: felt, account: felt, sender: felt):
end

func RoleAdminChanged(
    role: felt,
    previousAdminRole: felt,
    newAdminRole: felt
  ):
end
```

#### `RoleGranted`

Emitted when `account` is granted `role`.

`sender` is the account that originated the contract call, an admin role bearer.

Parameters:

```cairo
role: felt
account: felt
sender: felt
```

#### `RoleRevoked`

Emitted when account is revoked role.

`sender` is the account that originated the contract call:

* if using [revoke_role](#revoke_role), it is the admin role bearer
* if using [renounce_role](#renounce_role), it is the role bearer (i.e. `account`).

```cairo
role: felt
account: felt
sender: felt
```

#### `RoleAdminChanged`

Emitted when `newAdminRole` is set as `role`'s admin role, replacing `previousAdminRole`

`DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite `RoleAdminChanged` not being emitted signaling this.

```cairo
role: felt
previousAdminRole: felt
newAdminRole: felt
```
