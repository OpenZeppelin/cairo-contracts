# Timelock

The Timelock library provides a means of enforcing time delays on the execution of transactions. This is considered good practice regarding governance systems because it allows users the opportunity to exit the system if they disagree with a decision before it is executed.

> Note that the Timelock contract itself executes transactions, not the user. The Timelock should, therefore, hold associated funds, ownership, and access control roles.

## Table of Contents

* [AccessControl and roles](#accesscontrol-and-roles)
* [Setup](#setup)
* [Standard lifecycle](#standard-lifecycle)
  * [Scheduling](#scheduling)
  * [Executing](#scheduling)
  * [Canceling](#scheduling)
* [Batching and dependencies](batching-and-dependencies)
* [Updating the minimum delay](#updating-the-minimum-delay)
* [Timelock library API](#timelock-library-api)
  * [Methods](#methods)
    * [initializer](#initializer)
    * [assert_only_role_or_open_role](#assert_only_role_or_open_role)
    * [is_operation](#is_operation)
    * [is_operation_pending](#is_operation_pending)
    * [is_operation_ready](#is_operation_ready)
    * [is_operation_done](#is_operation_done)
    * [get_timestamp](#get_timestamp)
    * [get_min_delay](#get_min_delay)
    * [hash_operation](#hash_operation)
    * [schedule](#schedule)
    * [cancel](#cancel)
    * [execute](#execute)
    * [update_delay](#update_delay)
    * [_iter_role](#_iter_role)
  * [Events](#events)
    * [CallScheduled](#callscheduled)
    * [CallExecuted](#callexecuted)
    * [Cancelled](#cancelled)
    * [MinDelayChange](#mindelaychange)

## AccessControl and roles

The Timelock library leverages the AccessControl library to grant roles and restrict access to sensitive functions. Timelock utilizes the following roles:

* **Proposer** - The Proposer role is in charge of queueing operations.

* **Executor** - The Executor role is in charge of executing already available operations: we can assign this role to the special zero address to allow anyone to execute (if operations can be particularly time sensitive, the Governor should be made Executor instead).

* **Canceller** - The Canceller role is in charge of cancelling operations.

* **Timelock admin** - Lastly, there is the Admin role, which can grant and revoke the three previous roles: this is a very sensitive role that will be granted automatically to both the deployer and timelock itself. The deployer should, however, renounce after setup.

## Setup

In order to deploy a timelock implementation, we need to set up a constructor to both pass the `minDelay` and `deployer` account address and grant the 'proposer', 'executor', and 'canceller' roles. Here's an example constructor:

```cairo
from openzeppelin.security.timelock import (
    Timelock,
    PROPOSER_ROLE,
    CANCELLER_ROLE,
    EXECUTOR_ROLE
)

from openzeppelin.access.accesscontrol import AccessControl

@constructor
func constructor{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        minDelay: felt,         # the minimum delay
        deployer: felt,         # deployer account address
        proposers_len: felt,    # proposer array length
        proposers: felt*,       # array of addresses to grant 'PROPOSER_ROLE'
        executors_len: felt,    # executor array length
        executors: felt*,       # array of addresses to grant 'EXECUTOR_ROLE'
        cancellers_len: felt,   # canceller array length
        cancellers: felt*       # array of addresses to grant 'CANCELLER_ROLE'
    ):
    alloc_locals
    AccessControl.initializer()
    Timelock.initializer(minDelay, deployer)

    # grant proposer, executor, and canceller roles
    Timelock._iter_roles(proposers_len, proposers, PROPOSER_ROLE)
    Timelock._iter_roles(executors_len, executors, EXECUTOR_ROLE)
    Timelock._iter_roles(cancellers_len, cancellers, CANCELLER_ROLE)
    return ()
end
```

To deploy the contract in Python:

```python
starknet = Starknet.empty()
timelock = await starknet.deploy(
    "path/to/Timelock.cairo",
    constructor_calldata=[
        12345,                        # minimum delay (in seconds)
        deployer.contract_address,    # deployer address
        1,                            # number of proposers
        proposer_1.contract_address
        2,                            # number of executors
        executor_1.contract_address
        executor_2.contract_address
        3,                            # number of cancellers
        canceller_1.contract_address
        canceller_2.contract_address
        canceller_3.contract_address
    ]
)


```

## Standard lifecycle

### Scheduling

### Executing

### Cancelling

## Batching and dependencies

## Updating the minimum delay

## API Specification

### Methods

#### `initializer`

Initializes the timelock contract and sets the `min_delay` and `deployer` account. Role assignments must take place within the implementing contract's constructor (the same constructor invoking this method).

> At construction, both the `deployer` and the timelock itself are administrators. This helps further configuration of the timelock by the `deployer`. After configuration is done, it is recommended that the `deployer` renounces its admin position and relies on timelocked operations to perform future maintenance.

Parameters:

```cairo
min_delay: felt
deployer: felt
```

Returns:

None.

#### `assert_only_role_or_open_role`

Reverts if caller does not have the specified `role`. In addition to checking the sender’s role, the zero address's role is also considered. Granting a role to the zero address is equivalent to enabling this role for everyone.

Parameters:

```cairo
role: felt
```

Returns:

None.

#### `is_operation`

Returns whether an id corresponds to a registered operation. This includes both Pending, Ready and Done operations.

Parameters:

```cairo
id: felt
```

Returns:

```cairo
registered: felt
```

#### `is_operation_pending`

Returns whether an operation is pending or not.

Parameters:

```cairo
id: felt
```

Returns:

```cairo
pending: felt
```

#### `is_operation_ready`

Returns whether an operation is ready or not.

Parameters:

```cairo
id: felt
```

Returns:

```cairo
ready: felt
```

#### `is_operation_done`

Returns whether an operation is done or not.

Parameters:

```cairo
id: felt
```

Returns:

```cairo
done: felt
```

#### `get_timestamp`

Returns the timestamp at with an operation becomes ready (`0` for unset operations, `1` for done operations).

Parameters:

```cairo
id: felt
```

Returns:

```cairo
timestamp: felt
```

#### `get_min_delay`

Returns the minimum delay for an operation to become valid.

This value can be changed by executing an operation that calls [update_delay](#update_delay).

Parameters:

None.

Returns:

```cairo
duration: felt
```

#### `hash_operation`

Returns the identifier of an operation containing one or more transactions.

Parameters:

```cairo
call_array_len: felt
call_array: AccountCallArray*
calldata_len: felt
calldata: felt*
predecessor: felt
salt: felt
```

Returns:

```cairo
hash: felt
```

#### `schedule`

Schedule an operation containing one or more transactions.

Emits a [CallScheduled](#callscheduled) event.

Requirements:

* the caller must have the 'proposer' role.

Parameters:

```cairo
call_array_len: felt
call_array: AccountCallArray*
calldata_len: felt
calldata: felt*
predecessor: felt
salt: felt
delay: felt
```

Returns:

None.

#### `cancel`

Cancel an operation.

Requirements:

* the caller must have the 'canceller' role.

Parameters:

```cairo
id: felt
```

Returns:

None.

#### `execute`

Execute an (ready) operation containing one or more transactions.

Emits a [CallExecuted](#callexecuted) event for each transaction.

Requirements:

* the caller must have the 'executor' role.

Parameters:

```cairo
call_array_len: felt
call_array: AccountCallArray*
calldata_len: felt
calldata: felt*
predecessor: felt
salt: felt
```

Returns:

None.

#### `update_delay`

Changes the minimum timelock duration for future operations.

Emits a [MinDelayChange](#mindelaychange) event.

Requirements:

* the caller must be the timelock itself. This can only be achieved by scheduling and later executing an operation where the timelock is the target and the data is the ABI-encoded call to this function.

Parameters:

```cairo
new_delay: felt
```

Returns:

None.

#### `_iter_role`

Iterates `addresses` array and grants `role` to each address. A helper function for assigning timelock roles during construction.

Parameters:

```cairo
addresses_len: felt,
addresses: felt*,
role: felt
```

Returns:

None.

### Events

#### `CallScheduled`

Emitted when a call is scheduled as part of operation `id`.

Parameters:

```cairo
id: felt
index: felt
target: felt
selector: felt
calldata_len: felt
calldata: felt*
predecessor: felt
delay: felt
```

#### `CallExecuted`

Emitted when a call is performed as part of operation `id`.

Parameters:

```cairo
id: felt
index: felt
target: felt
selector: felt
calldata_len: felt
calldata: felt*
```

#### `Cancelled`

Emitted when operation `id` is cancelled.

Parameters:

```cairo
id: felt
```

#### `MinDelayChange`

Emitted when the minimum delay for future operations is modified.

Parameters:

```cairo
oldDuration: felt
newDuration: felt
```
