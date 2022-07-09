# Timelock

The Timelock library provides a means of enforcing time delays on the execution of transactions. This is considered good practice regarding governance systems because it allows users the opportunity to exit the system if they disagree with a decision before it is executed.

> Note that the Timelock contract itself executes transactions, not the user. The Timelock should, therefore, hold associated funds, ownership, and access control roles.

## Table of Contents

* [Terminology](#terminology)
* [Operations](#operations)
  * [Structure](#structure)
  * [Lifecycle](#lifecycle)
* [AccessControl and roles](#accesscontrol-and-roles)
  * [Calculating role identifiers](#calculating-role-identifiers)
* [Setup](#setup)
* [Usage](#usage)
* [Batching calls](#batching-calls)
* [Predecessors](#predecessors)
* [Updating the minimum delay](#updating-the-minimum-delay)
* [Notable differences with Solidity](#notable-differences-with-solidity)
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

## Terminology

* **Operation**: A transaction (or a set of transactions) that is the subject of the timelock. It has to be scheduled by a proposer and executed by an executor. The timelock enforces a minimum delay between the proposition and the execution (see operation lifecycle). If the operation contains multiple transactions, they are executed atomically. Operations are identified by the hash of their content.

* **Operation status**:

  * _Unset_: An operation that is not part of the timelock mechanism.
  * _Pending_: An operation that has been scheduled, before the timer expires.
  * _Ready_: An operation that has been scheduled, after the timer expires.
  * _Done_: An operation that has been executed.

* **Predecessor**: An (optional) dependency between operations. An operation can depend on another operation (its predecessor), forcing the execution order of these two operations.

* **Role**:

  * _Admin_: An address (smart contract or account) that is in charge of granting the roles of Proposer and Executor.

  * _Proposer_: An address (smart contract or account) that is in charge of scheduling operations.

  * _Executor_: An address (smart contract or account) that is in charge of executing operations once the timelock has expired. This role can be given to the zero address to allow anyone to execute operations.

  * _Canceller_: An address (smart contract or account) that is in charge of cancelling operations.

## Operations

### Structure

Operations executed by the Timelock can contain one or multiple subsequent calls. All calls must be passed within an array. This implementation utilizes the [AccountCallArray](./Account.md#accountcallarray) struct from the [Account library](../src/openzeppelin/account/library.cairo). For a more in-depth look at the struct, see the [Account docs](./Account.md).

Operations contain:

1. `call_array_len`: number of calls.

2. `call_array`: list of calls formatted in [AccountCallArray](#./Account.md#accountcallarray).

3. `calldata_len`: length of total calldata elements.

4. `calldata`: list of all calldata elements with all calls.

5. `predecessor`: specifies a dependency between operations. This dependency is optional. Use `0` if the operation does not have any dependency.

6. `salt`: used to disambiguate two otherwise identical operations. This can be any random value.

### Lifecycle

Timelocked operations are identified by a unique id (their hash) and follow a specific lifecycle:

`Unset` → `Pending` → `Pending` + `Ready` → `Done`

* By calling schedule, a proposer moves the operation from the Unset to the Pending state. This starts a timer that must be longer than the minimum delay. The timer expires at a timestamp accessible through the [get_timestamp](#get_timestamp) method.

* Once the timer expires, the operation automatically gets the `Ready` state. At this point, it can be executed.

* By calling [execute](#execute), an executor triggers the operation’s underlying transactions and moves it to the `Done` state. If the operation has a predecessor, it has to be in the `Done` state for this transition to succeed.

* [cancel](#cancel) allows proposers to cancel any `Pending` operation. This resets the operation to the `Unset` state. It is thus possible for a proposer to re-schedule an operation that has been cancelled. In this case, the timer restarts when the operation is re-scheduled.

## AccessControl and roles

The Timelock library leverages the [AccessControl](../src/openzeppelin/access/accesscontrol.cairo) library to grant roles and restrict access to sensitive functions. Timelock utilizes the following roles:

* **Admin** - The admins are in charge of managing proposers and executors. For the timelock to be self-governed, this role should only be given to the timelock itself. Upon deployment, both the timelock and the deployer have this role. After further configuration and testing, the deployer can renounce this role such that all further maintenance operations have to go through the timelock process.

* **Proposer** - The proposers are in charge of scheduling operations. This is a critical role, that should be given to governing entities. This could be an account, a multisig, or a DAO.

* **Executor** - The executors are in charge of executing the operations scheduled by the proposers once the timelock expires. Logic dictates that multisig or DAO that are proposers should also be executors in order to guarantee operations that have been scheduled will eventually be executed. However, having additional executors can reduce the cost (the executing transaction does not require validation by the multisig or DAO that proposed it), while ensuring whoever is in charge of execution cannot trigger actions that have not been scheduled by the proposers. Alternatively, it is possible to allow any address to execute a proposal once the timelock has expired by granting the executor role to the zero address.

* **Canceller** - The Canceller role is in charge of cancelling operations. The Solidity implementation of Timelock appoints proposers as cancellers as well for backwards compatibility. This implementation, nevertheless, does not enforce this approach.

> **Warning** A live contract without at least one proposer and one executor is locked. Make sure these roles are filled by reliable entities before the deployer renounces its administrative rights in favour of the timelock contract itself. See the [AccessControl](#./Access.md#accesscontrol) documentation to learn more about role management.

### Calculating role identifiers

FINISH ME!!!!!!!!!!!!

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

## Usage

> Note that the following examples use the [Timelock mock contract](../tests/mocks/Timelock.cairo) which exposes all of the Timelock methods.

To start off the Timelock lifecycle, a proposer must first schedule an operation. We'll use the basic [Contract.cairo contract](../tests/mocks/Contract.cairo) for the following snippets. To ease the readbility of these operations, here are the transaction details of which the following examples will be using.

```python
from starkware.starknet.public.abi import get_selector_from_name

ACCOUNT_CALL_ARRAY = [
    1,                                           # number of calls
    CONTRACT.contract_address,                   # target contract
    get_selector_from_name("increase_balance"),  # selector
    0,                                           # calldata offset
    1,                                           # calldata length in call
]

CALLDATA = [
    1,              # calldata length
    123,            # calldata value
]

PREDECESSOR = 0     # predecessor is `0` if none
SALT = 5417         # random number associated with this operation
DELAY = 12345       # time before operation can be executed
```

Before scheduling an operation, users may want to track an operation's status. To do so, we'll need to get the operation's hash identifier.

```python
hash_id = await timelock.hashOperation(
    *ACCOUNT_CALL_ARRAY,
    *CALLDATA,
    PREDECESSOR,
    SALT
    ).call()
```

To schedule an operation resulting in the same hash id as above, a proposer must pass the exact same arguments (with `DELAY`) to `schedule`.

```python
await signer.send_transaction(
    proposer, timelock.contract_address, "schedule", [
       *ACCOUNT_CALL_ARRAY,
       *CALLDATA,
       PREDECESSOR,
       SALT,
       DELAY
    ]
)
```

After the operation is scheduled and at least `DELAY` time has passed (12,345 seconds in this example), an executor can execute the operation.

```python
await signer.send_transaction(
    executor, timelock.contract_address, "execute", [
        *ACCOUNT_CALL_ARRAY,
        *CALLDATA,
        PREDECESSOR,
        SALT
    ]
)
```

Cancelling an operation that's still pending requires that the canceller first acquires the target operation's hash identifier.

```python
# acquire operation's hash id
hash_id = await timelock.hashOperation(
    *ACCOUNT_CALL_ARRAY,
    *CALLDATA,
    PREDECESSOR,
    SALT
    ).call()

# cancel operation
await signer.send_transaction(
    canceller, timelock.contract_address, "cancel", [hash_id]
)
```

## Batching calls

An operation can consist of multiple calls (batched calls). These calls will be executed in the order they're passed. To set up an operation with batched calls, let's add a second call to the example operation:

```python
from starkware.starknet.public.abi import get_selector_from_name

ACCOUNT_CALL_ARRAY_2 = [
    2,                                           # number of calls

    # call #1
    CONTRACT.contract_address,                   # target contract
    get_selector_from_name("increase_balance"),  # selector
    0,                                           # calldata offset
    1,                                           # calldata length in call

    # call #2
    CONTRACT.contract_address,                   # target contract
    get_selector_from_name("increase_balance"),  # selector
    1,                                           # calldata offset
    1,                                           # calldata length in call
]

CALLDATA_2 = [
    2,              # calldata length
    123,            # call #1 calldata value
    456             # call #2 calldata value
]

PREDECESSOR = 0     # predecessor is `0` if none
SALT = 5417         # random number associated with this operation
DELAY = 12345       # time before operation can be executed
```

And the proposer makes the function call to the Timelock contract just as before.

```python
await signer.send_transaction(
    proposer, timelock.contract_address, "schedule", [
       *ACCOUNT_CALL_ARRAY_2,
       *CALLDATA_2,
       PREDECESSOR,
       SALT,
       DELAY
    ]
)
```

## Predecessors

Suppose you wanted to execute an operation after and only after the execution of another operation—this is the perfect opportunity to include a predecessor. To further exemplify, imagine setting up a timelock mechanism that mints and transfers tokens to users. Before the contract can transfer tokens, they first need to be minted. In this example, the mint function must be the predecessor in the transfer operation.

We can retrieve the hash identifier of an operation with `hash_operation` and insert this id as the predecessor of the dependent call.

```python
# schedule predecessor call
await signer.send_transaction(
    proposer, timelock.contract_address, "schedule", [
       *ACCOUNT_CALL_ARRAY,
       *CALLDATA,
       0,        # predecessor is `0` if none
       SALT,
       DELAY
    ]
)

# get predecessor's hash id
hash_id = await timelock.hashOperation(
    *ACCOUNT_CALL_ARRAY,
    *CALLDATA,
    0,           # predecessor is `0` if none
    SALT
    ).call()

# schedule new call with the predecessor's hash id
await signer.send_transaction(
    proposer, timelock.contract_address, "schedule", [
       *ACCOUNT_CALL_ARRAY,
       *CALLDATA,
       hash_id,   # predecessor's hash id
       SALT,
       DELAY
    ]
)
```

> Note that [utils.py](../tests/utils.py) includes `timelock_hash_chain()` which also computes the operation hash identifier.

## Updating the minimum delay

In the event that changing the minimum delay appears necessary, the timelock contract and only the timelock contract can update the delay. In other words, the proposers and executors must schedule and execute an operation with the timelock contract set as the target address; therefore, the [update_delay](#update_delay) call comes from the timelock contract itself.

```python
    update_delay_call = from_call_to_call_array(
        [[timelock.contract_address, "updateDelay", [NEW_MIN_DELAY]]]
    )

    # schedule operation
    await signer.send_transaction(
        proposer, timelock.contract_address, "schedule", [
            1,                                      # number of calls
            timelock.contract_address,              # target address
            get_selector_from_name("updateDelay"),  # selector
            0,                                      # calldata offset
            1,                                      # total calldata length

            1,                                      # call's calldata length
            86400,                                  # new minimum delay

            0,                                      # predecessor
            SALT,                                   # SALT
            MIN_DELAY                               # delay
        ])
```

## Notable differences with Solidity

FINISH ME!!!!!!!!!!!!!!

## Timelock library API

```cairo
func initializer(min_delay: felt, deployer: felt):
end

func assert_only_role_or_open_role(role: felt):
end

func is_operation(id: felt) -> (registered: felt):
end

func is_operation_pending(id: felt) -> (pending: felt):
end

func is_operation_ready(id: felt) -> (ready: felt):
end

func is_operation_done(id_ felt) -> (done: felt):
end

func get_timestamp(id: felt) -> (timestamp: felt):
end

func get_min_delay() -> (duration: felt):
end

func hash_operation(
        call_array_len: felt,
        call_array: AccountCallArray*,
        calldata_len: felt,
        calldata: felt*,
        predecessor: felt,
        salt: felt
    ) -> (hash: felt):
end

func schedule(
        call_array_len: felt,
        call_array: AccountCallArray*,
        calldata_len: felt,
        calldata: felt*,
        predecessor: felt,
        salt: felt,
        delay: felt
    ):
end

func cancel(id: felt):
end

func execute(
        call_array_len: felt,
        call_array: AccountCallArray*,
        calldata_len: felt,
        calldata: felt*,
        predecessor: felt,
        salt: felt
    ):
end

func update_delay(new_delay: felt):
end

func _iter_role(
        addresses_len: felt,
        addresses: felt*,
        role: felt
    ):
end
```

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
