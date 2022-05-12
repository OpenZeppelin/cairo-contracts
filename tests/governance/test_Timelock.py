import pytest
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.public.abi import get_selector_from_name
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils import (
    Signer,
    assert_event_emitted,
    assert_revert,
    contract_path,
    get_block_timestamp,
    set_block_timestamp,
)


proposer_signer = Signer(123456789987654321)
executor_signer = Signer(987654321123456789)

TRUE = 1
FALSE = 0
DAY = 86400

TIMELOCK_ADMIN_ROLE = 1
PROPOSER_ROLE = 2
CANCELLER_ROLE = 3
EXECUTOR_ROLE = 4


@pytest.fixture(scope="module")
async def timelock_factory():
    starknet = await Starknet.empty()

    proposer_account = await starknet.deploy(
        contract_path("openzeppelin/account/Account.cairo"),
        constructor_calldata=[proposer_signer.public_key],
    )

    executor_account = await starknet.deploy(
        contract_path("openzeppelin/account/Account.cairo"),
        constructor_calldata=[executor_signer.public_key],
    )

    timelock = await starknet.deploy(
        contract_path("openzeppelin/governance/timelock/Timelock.cairo"),
        constructor_calldata=[
            proposer_account.contract_address,
            executor_account.contract_address,
            DAY,
        ],
    )

    return starknet, timelock, proposer_account, executor_account


@pytest.mark.asyncio
async def test_constructor(timelock_factory):
    _, timelock, proposer_account, executor_account = timelock_factory

    execution_info = await timelock.hasRole(
        TIMELOCK_ADMIN_ROLE, timelock.contract_address
    ).call()
    assert execution_info.result == (TRUE,)

    execution_info = await timelock.hasRole(
        PROPOSER_ROLE, proposer_account.contract_address
    ).call()
    assert execution_info.result == (TRUE,)

    execution_info = await timelock.hasRole(
        CANCELLER_ROLE, proposer_account.contract_address
    ).call()
    assert execution_info.result == (TRUE,)

    execution_info = await timelock.hasRole(
        EXECUTOR_ROLE, executor_account.contract_address
    ).call()
    assert execution_info.result == (TRUE,)

    execution_info = await timelock.getMinDelay().call()
    assert execution_info.result == (DAY,)


@pytest.mark.asyncio
async def test_schedule(timelock_factory):
    starknet, timelock, proposer_account, _ = timelock_factory

    initializable = await starknet.deploy(
        contract_path("openzeppelin/security/initializable.cairo")
    )

    init_call = (
        initializable.contract_address,
        get_selector_from_name("initialize"),
        0,
        0,
    )

    execution_info = await timelock.hashOperation([init_call], [], 0, 0).call()
    (operation_hash,) = execution_info.result

    call_array = [1, *init_call, *[0], 0, 0, 2 * DAY]

    block_timestamp = get_block_timestamp(starknet.state)

    schedule_exec_info = await proposer_signer.send_transaction(
        proposer_account, timelock.contract_address, "schedule", call_array
    )

    execution_info = await timelock.getTimestamp(operation_hash).call()
    assert execution_info.result == (block_timestamp + (2 * DAY),)

    execution_info = await timelock.isOperation(operation_hash).call()
    assert execution_info.result == (TRUE,)

    execution_info = await timelock.isOperationPending(operation_hash).call()
    assert execution_info.result == (TRUE,)

    execution_info = await timelock.isOperationReady(operation_hash).call()
    assert execution_info.result == (FALSE,)

    assert_event_emitted(
        schedule_exec_info,
        timelock.contract_address,
        name="OperationScheduled",
        data=[
            operation_hash,  # id
            *[1, *init_call],  # calls
            *[0],  # calldata
            0,
            2 * DAY,
        ],
    )


@pytest.mark.asyncio
async def test_revert_min_delay_too_low(timelock_factory):
    starknet, timelock, proposer_account, _ = timelock_factory

    initializable = await starknet.deploy(
        contract_path("openzeppelin/security/initializable.cairo")
    )

    init_call = (
        initializable.contract_address,
        get_selector_from_name("initialize"),
        0,
        0,
    )
    call_array = [1, *init_call, *[0], 0, 0, int(DAY / 2)]

    schedule_fun = proposer_signer.send_transaction(
        proposer_account, timelock.contract_address, "schedule", call_array
    )
    await assert_revert(schedule_fun, "Timelock: insufficient delay")


@pytest.mark.asyncio
async def test_reschedule_fails(timelock_factory):
    starknet, timelock, proposer_account, _ = timelock_factory

    initializable = await starknet.deploy(
        contract_path("openzeppelin/security/initializable.cairo")
    )

    init_call = (
        initializable.contract_address,
        get_selector_from_name("initialize"),
        0,
        0,
    )
    call_array = [1, *init_call, *[0], 0, 0, 2 * DAY]

    await proposer_signer.send_transaction(
        proposer_account, timelock.contract_address, "schedule", call_array
    )
    await assert_revert(
        proposer_signer.send_transaction(
            proposer_account, timelock.contract_address, "schedule", call_array
        ),
        "Timelock: operation already scheduled",
    )


@pytest.mark.asyncio
async def test_schedule_salt(timelock_factory):
    starknet, timelock, proposer_account, _ = timelock_factory

    initializable = await starknet.deploy(
        contract_path("openzeppelin/security/initializable.cairo")
    )

    init_call = (
        initializable.contract_address,
        get_selector_from_name("initialize"),
        0,
        0,
    )

    execution_info = await timelock.hashOperation([init_call], [], 0, 0).call()
    (operation_hash,) = execution_info.result

    execution_info = await timelock.hashOperation([init_call], [], 0, 1).call()
    (operation_hash_salt,) = execution_info.result

    call_array = [1, *init_call, *[0], 0, 0, 2 * DAY]
    call_array_salt = [1, *init_call, *[0], 0, 1, 2 * DAY]

    block_timestamp = get_block_timestamp(starknet.state)

    schedule_exec_info = await proposer_signer.send_transaction(
        proposer_account, timelock.contract_address, "schedule", call_array
    )
    schedule_salt_exec_info = await proposer_signer.send_transaction(
        proposer_account, timelock.contract_address, "schedule", call_array_salt
    )

    execution_info = await timelock.getTimestamp(operation_hash).call()
    assert execution_info.result == (block_timestamp + (2 * DAY),)

    execution_info = await timelock.getTimestamp(operation_hash_salt).call()
    assert execution_info.result == (block_timestamp + (2 * DAY),)

    execution_info = await timelock.isOperation(operation_hash).call()
    assert execution_info.result == (TRUE,)

    execution_info = await timelock.isOperation(operation_hash_salt).call()
    assert execution_info.result == (TRUE,)

    execution_info = await timelock.isOperationPending(operation_hash).call()
    assert execution_info.result == (TRUE,)

    execution_info = await timelock.isOperationPending(operation_hash_salt).call()
    assert execution_info.result == (TRUE,)

    execution_info = await timelock.isOperationReady(operation_hash).call()
    assert execution_info.result == (FALSE,)

    execution_info = await timelock.isOperationReady(operation_hash_salt).call()
    assert execution_info.result == (FALSE,)

    assert_event_emitted(
        schedule_exec_info,
        timelock.contract_address,
        name="OperationScheduled",
        data=[
            operation_hash,  # id
            *[1, *init_call],  # calls
            *[0],  # calldata
            0,
            2 * DAY,
        ],
    )

    assert_event_emitted(
        schedule_salt_exec_info,
        timelock.contract_address,
        name="OperationScheduled",
        data=[
            operation_hash_salt,  # id
            *[1, *init_call],  # calls
            *[0],  # calldata
            0,
            2 * DAY,
        ],
    )


@pytest.mark.asyncio
async def test_cancel(timelock_factory):
    starknet, timelock, proposer_account, _ = timelock_factory

    initializable = await starknet.deploy(
        contract_path("openzeppelin/security/initializable.cairo")
    )

    init_call = (
        initializable.contract_address,
        get_selector_from_name("initialize"),
        0,
        0,
    )

    execution_info = await timelock.hashOperation([init_call], [], 0, 0).call()
    (operation_hash,) = execution_info.result

    call_array = [1, *init_call, *[0], 0, 0, 2 * DAY]

    await proposer_signer.send_transaction(
        proposer_account, timelock.contract_address, "schedule", call_array
    )

    execution_info_cancel = await proposer_signer.send_transaction(
        proposer_account, timelock.contract_address, "cancel", [operation_hash]
    )

    execution_info = await timelock.getTimestamp(operation_hash).call()
    assert execution_info.result == (0,)

    execution_info = await timelock.isOperation(operation_hash).call()
    assert execution_info.result == (FALSE,)

    execution_info = await timelock.isOperationPending(operation_hash).call()
    assert execution_info.result == (FALSE,)

    execution_info = await timelock.isOperationReady(operation_hash).call()
    assert execution_info.result == (FALSE,)

    assert_event_emitted(
        execution_info_cancel,
        timelock.contract_address,
        "OperationCancelled",
        [operation_hash],
    )


@pytest.mark.asyncio
async def test_cancel_not_pending(timelock_factory):
    starknet, timelock, proposer_account, executor_account = timelock_factory

    initializable = await starknet.deploy(
        contract_path("openzeppelin/security/initializable.cairo")
    )

    init_call = (
        initializable.contract_address,
        get_selector_from_name("initialize"),
        0,
        0,
    )

    execution_info = await timelock.hashOperation([init_call], [], 0, 0).call()
    (operation_hash,) = execution_info.result

    call_array = [1, *init_call, *[0], 0, 0, 2 * DAY]
    exec_array = [1, *init_call, *[0], 0, 0]

    await proposer_signer.send_transaction(
        proposer_account, timelock.contract_address, "schedule", call_array
    )

    set_block_timestamp(starknet.state, 2 * DAY)

    await executor_signer.send_transaction(
        executor_account, timelock.contract_address, "execute", exec_array
    )

    await assert_revert(
        proposer_signer.send_transaction(
            proposer_account, timelock.contract_address, "cancel", [operation_hash]
        ),
        "Timelock: operation cannot be cancelled",
    )

    set_block_timestamp(starknet.state, 0)


@pytest.mark.asyncio
async def test_execute(timelock_factory):
    starknet, timelock, proposer_account, executor_account = timelock_factory

    initializable = await starknet.deploy(
        contract_path("openzeppelin/security/initializable.cairo")
    )

    init_call = (
        initializable.contract_address,
        get_selector_from_name("initialize"),
        0,
        0,
    )

    execution_info = await initializable.initialized().call()
    assert execution_info.result == (FALSE,)

    execution_info = await timelock.hashOperation([init_call], [], 0, 0).call()
    (operation_hash,) = execution_info.result

    call_array = [1, *init_call, *[0], 0, 0, 2 * DAY]
    exec_array = [1, *init_call, *[0], 0, 0]

    await proposer_signer.send_transaction(
        proposer_account, timelock.contract_address, "schedule", call_array
    )

    set_block_timestamp(starknet.state, 2 * DAY)

    execution_info_exec = await executor_signer.send_transaction(
        executor_account, timelock.contract_address, "execute", exec_array
    )

    execution_info = await timelock.getTimestamp(operation_hash).call()
    assert execution_info.result == (1,)

    execution_info = await timelock.isOperation(operation_hash).call()
    assert execution_info.result == (TRUE,)

    execution_info = await timelock.isOperationPending(operation_hash).call()
    assert execution_info.result == (FALSE,)

    execution_info = await timelock.isOperationReady(operation_hash).call()
    assert execution_info.result == (FALSE,)

    execution_info = await timelock.isOperationDone(operation_hash).call()
    assert execution_info.result == (TRUE,)

    execution_info = await initializable.initialized().call()
    assert execution_info.result == (TRUE,)

    assert_event_emitted(
        execution_info_exec,
        timelock.contract_address,
        "OperationExecuted",
        [
            operation_hash,  # id
            *[1, *init_call],  # calls
            *[0],  # calldata
        ],
    )

    assert_event_emitted(
        execution_info_exec,
        timelock.contract_address,
        "CallExecuted",
        [
            operation_hash,  # id
            0,
            initializable.contract_address,
            get_selector_from_name("initialize"),
            *[0],  # calldata
        ],
    )

    set_block_timestamp(starknet.state, 0)


@pytest.mark.asyncio
async def test_execute_not_ready(timelock_factory):
    starknet, timelock, proposer_account, executor_account = timelock_factory

    initializable = await starknet.deploy(
        contract_path("openzeppelin/security/initializable.cairo")
    )

    init_call = (
        initializable.contract_address,
        get_selector_from_name("initialize"),
        0,
        0,
    )

    execution_info = await initializable.initialized().call()
    assert execution_info.result == (FALSE,)

    execution_info = await timelock.hashOperation([init_call], [], 0, 0).call()
    (operation_hash,) = execution_info.result

    call_array = [1, *init_call, *[0], 0, 0, 2 * DAY]
    exec_array = [1, *init_call, *[0], 0, 0]

    await proposer_signer.send_transaction(
        proposer_account, timelock.contract_address, "schedule", call_array
    )

    await assert_revert(
        executor_signer.send_transaction(
            executor_account, timelock.contract_address, "execute", exec_array
        ),
        "Timelock: operation is not ready",
    )


@pytest.mark.asyncio
async def test_execute_predecessor_not_executed(timelock_factory):
    starknet, timelock, proposer_account, executor_account = timelock_factory

    initializable = await starknet.deploy(
        contract_path("openzeppelin/security/initializable.cairo")
    )

    initializable_2 = await starknet.deploy(
        contract_path("openzeppelin/security/initializable.cairo")
    )

    init_call = (
        initializable.contract_address,
        get_selector_from_name("initialize"),
        0,
        0,
    )

    init_2_call = (
        initializable.contract_address,
        get_selector_from_name("initialize"),
        0,
        0,
    )

    execution_info = await timelock.hashOperation([init_call], [], 0, 0).call()
    (operation_hash,) = execution_info.result

    execution_info = await timelock.hashOperation(
        [init_2_call], [], operation_hash, 0
    ).call()

    (operation_hash_2,) = execution_info.result

    call_array = [1, *init_call, *[0], 0, 0, 2 * DAY]

    call_array_2 = [1, *init_call, *[0], operation_hash, 0, 2 * DAY]
    exec_array_2 = [1, *init_call, *[0], operation_hash, 0]

    await proposer_signer.send_transaction(
        proposer_account, timelock.contract_address, "schedule", call_array
    )

    await proposer_signer.send_transaction(
        proposer_account, timelock.contract_address, "schedule", call_array_2
    )

    set_block_timestamp(starknet.state, 2 * DAY)

    await assert_revert(
        executor_signer.send_transaction(
            executor_account, timelock.contract_address, "execute", exec_array_2
        ),
        "Timelock: missing dependency",
    )

    set_block_timestamp(starknet.state, 0)
