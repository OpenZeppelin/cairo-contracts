# Timelock

In a governance system, the `Timelock` contract is in charge of introducing a delay between a proposal and its execution.

When this contract is used as the owner of a contract, it enforces a timelock on all operations requiring ownership. This gives time to users of the controlled contract to take action before a potentially dangerous operation is applied.

By default this contract is self administered meaning maintainance tasks should be timelocked too (eg. changing the minimum delay between a proposal and its execution).

## Table of Contents
* [Quickstart](#quickstart)
* [Proposals and execution](#proposals-and-execution)
* [Access control](#access-control)
* [API Specification](#api-specification)

## Quickstart
A basic usage of this contract is:

1. The `Timelock` contract is deployed specifying:
    - a minimum delay between proposal and execution of operations
    - a proposer account, able to propose batches of transactions
    - an executor account, able to execute proposed batches of transactions

2. Batches of transactions can now be proposed (or cancelled) by the proposer account

3. Proposed batches of transactions can now be executed by the executor account

In Python, proposing a batch of transactions looks like:

```python
from starkware.starknet.testing.starknet import Starknet
proposer_signer = Signer(456)
executor_signer = Signer(789)

# 1. Deploy accounts
proposer_account = await starknet.deploy(
    "contracts/Account.cairo",
    constructor_calldata=[proposer_signer.public_key]
)

executor_account = await starknet.deploy(
    "contracts/Account.cairo",
    constructor_calldata=[executor_signer.public_key]
)

# 2. Deploy Timelock contract (specifies 1 day as minimum delay)
timelock = await starknet.deploy(
    "contracts/governance/timelock/Timelock.cairo",
    constructor_calldata=[
        proposer_account.contract_address, 
        executor_account.contract_address, 
        86400
    ]
)

# 3. Propose a batch of transactions

await proposer_signer.send_transaction(proposer_account, timelock.contract_address, 'schedule', [some_parameters])
```

You can then execute the proposal (when specified delay passed) as:

```python

await executor_signer.send_transaction(executor_account, timelock.contract_address, 'execute', [some_parameters])
```

Or, you can cancel the proposal like this:

```python
execution_info = await timelock.hashOperation(parameters...).call()
(operation_id,) = execution_info.result

await proposer_signer.send_transaction(proposer_account, timelock.contract_address, 'cancel', [operation_id])
```

## Proposals and execution
The idea behind proposals is to batch transactions that needs a timelock before execution. A proposal consists of:

- a list of transactions
- a predecessor proposal hash (in case there is a dependency to another proposal)
- a delay specifying when in the future the proposal should be executed starting from the time it's scheduled
- a salt (used to hash the proposal)

An unique hash to identify the proposal is produced starting from these parameters (eg. in case it is needed as a dependency).

A proposer can use the `schedule` method to make a proposal. The hash associated to the scheduled proposal can be retrieved by calling the `hashOperation` method.

### `TimelockCall` and `Call`

Timelock contract need a `TimelockCall` type to represent calls that can be made by it. The idea is similar to the one in the [Account](./Account.md#call-and-multicall-format) contract:

```c#
# Internal representation
struct Call:
    member to: felt
    member selector: felt
    member calldata_len: felt
    member calldata: felt*
end

# External calls arguments
struct TimelockCall:
    member to: felt
    member selector: felt
    member data_offset: felt
    member data_len: felt
end
```

Proposers need to pass as arguments a list of `TimelockCall` and calldata separately.

### Proposals state

A proposal can be in different states:

- **Pending**: proposal can not be executed because delay is not expired.
- **Ready**: proposal's delay is expired.
- **Executed**: proposal was executed.

### Scheduling a proposal
A proposal can be scheduled only by accounts that have the `PROPOSER_ROLE` role.

The execution flow for a proposal starts by proposing it. A proposer can schedule operations by using the `schedule` method that accepts these arguments:

- `call_array_len`: the number of transactions
- `call_array`: a list of `TimelockCall`
- `calldata_len`: the length of calldata
- `calldata`: actual calldata
- `predecessor`: the hash of the predecessor
- `salt`
- `delay`: the delay needed for this proposal to be ready to execute (should be greater than or equal to minimum delay)  

We illustrate the process by using Python and the `Signer` utility class to send transactions with an account:

```python

# At this point the proposer account should already be deployed

DAY = 86400

call_arguments = [
    1, # call_array_len
    *[ # call_array
        *(
            contract_to_call.contract_address, # to
            get_selector_from_name('method_to_call'), # selector
            0, # calldata offset
            0, # calldata len
        ),
    ],
    *[0], # [calldata_len | ...calldata]
    0, # predecessor
    0, # salt
    DAY # delay
]

await proposer.send_transaction(
    proposer_account, 
    timelock.contract_address, 
    'schedule', 
    call_arguments
)
```

You can also retrieve the hash assigned to the proposal by calling `hashOperation`:

```python
call = (
    contract_to_call.contract_address,
    get_selector_from_name("method_to_call"),
    0,
    0,
)

execution_info = await timelock.hashOperation([call], [], 0, 0).call()
(operation_hash,) = execution_info.result

print(f'proposal hash: {operation_hash}')
```

### Cancelling a proposal

It is possible to delete **pending** proposals by users with `PROPOSER_ROLE` role:

```python
call = (
    contract_to_call.contract_address,
    get_selector_from_name("method_to_call"),
    0,
    0,
)

execution_info = await timelock.hashOperation([call], [], 0, 0).call()
(operation_hash,) = execution_info.result

await signer.send_transaction(
    proposer_account, 
    timelock.contract_address, 
    'cancel', 
    [operation_hash]
)
```

### Executing a proposal

It is possible to execute **ready** proposals by users with `EXECUTOR_ROLE` role:

```python
call = (
    contract_to_call.contract_address,
    get_selector_from_name("method_to_call"),
    0,
    0,
)

execute_arguments = [
    1, # call_array_len
    *[call], # call_array
    *[0], # [calldata_size | ...calldata]
    0, # predecessor
    0 # salt
]

await signer.send_transaction(
    executor_account, 
    timelock.contract_address, 
    'execute', 
    execute_arguments
)
```

## Access Control
By default the `Timelock` contract implements access control on the timelock.

There are three roles:

- **Proposer** (`PROPOSER_ROLE`), able to propose and cancel batches of transactions. This role is assigned on deploy of the contract by the deployer.

- **Executor** (`EXECUTOR_ROLE`), able to execute batches of transactions. This role is assigned on deploy of the contract by the deployer.

- **Timelock admin** (`TIMELOCK_ADMIN_ROLE`), able to change the timelock minimum delay. This role is assigned on deploy to the contract itself and to the deployer. Deployer should later renounce this role.

*Note that access control is implemented by the `Timelock` contract and is not implicit in the timelock library (`contracts/governance/timelock/library.cairo`) so that developers can implement their own authentication model.*

## API Specification

### Methods

#### `isOperation`

Returns `TRUE` if a given operation was proposed.

##### Parameters:

```jsx
id : felt
```

##### Returns:

```jsx
is_operation : felt
```

#### `isOperationPending`

Returns `TRUE` if a given operation is in a pending state.

##### Parameters:

```jsx
id : felt
```

##### Returns:

```jsx
is_pending : felt
```

#### `isOperationReady`

Returns `TRUE` if a given operation is in a ready state.

##### Parameters:

```jsx
id : felt
```

##### Returns:

```jsx
is_ready : felt
```

#### `isOperationDone`

Returns `TRUE` if a given operation is executed.

##### Parameters:

```jsx
id : felt
```

##### Returns:

```jsx
is_done : felt
```

#### `getTimestamp`

Returns the operation timestamp.
Returns 0 if the operation does not exist.
Returns 1 if the operation is executed.

##### Parameters:

```jsx
id : felt
```

##### Returns:

```jsx
timestamp : felt
```

#### `getMinDelay`

Returns the minimum delay.

##### Parameters:

None.

##### Returns:

```jsx
min_delay : felt
```

#### `hashOperation`

Returns `TRUE` if a given operation is in a pending state.

##### Parameters:

```jsx
call_array_len: felt
call_array: TimelockCall*
calldata_len: felt
calldata: felt*
predecessor: felt
salt: felt
```

##### Returns:

```jsx
hash : felt
```

#### `schedule`

Schedules an operation.

##### Parameters:

```jsx
call_array_len: felt
call_array: TimelockCall*
calldata_len: felt
calldata: felt*
predecessor: felt
salt: felt
delay: felt
```

##### Returns:

Nothing.

#### `cancel`

Cancels an operation.

##### Parameters:

```jsx
id: felt
```

##### Returns:

Nothing.

#### `execute`

Executes an operation.

##### Parameters:

```jsx
call_array_len: felt
call_array: TimelockCall*
calldata_len: felt
calldata: felt*
predecessor: felt
salt: felt
```

##### Returns:

Nothing.

#### `updateDelay`

Updates the minimum delay.

##### Parameters:

```jsx
new_delay: felt
```

##### Returns:

Nothing.


### Events

#### `CallScheduled` (event)

Emitted when a call is scheduled.

##### Parameters:

```jsx
id: felt
index: felt
target: felt
selector: felt
calldata_len: felt
calldata: felt*
predecessor: felt
```

#### `CallExecuted` (event)

Emitted when the call at position `index` of operation `id` is executed.

##### Parameters:

```jsx
id: felt
index: felt 
target: felt 
selector: felt 
calldata_len: felt 
calldata: felt*
```

#### `Cancelled` (event)

Emitted when the operation `id` is cancelled.

##### Parameters:

```jsx
id: felt
```

#### `MinDelayChange` (event)

Emitted when the minimum delay is changed.

##### Parameters:

```jsx
old_duration: felt
new_duration: felt
```



