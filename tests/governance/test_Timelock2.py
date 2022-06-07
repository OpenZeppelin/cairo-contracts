import pytest
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.public.abi import get_selector_from_name
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils import (
    TestSigner, assert_event_emitted, assert_revert, get_contract_def,
    cached_contract, get_block_timestamp, TRUE, FALSE, set_block_timestamp,
)

signer = TestSigner(123456789987654321)

DAY = 86400

#TIMELOCK_ADMIN_ROLE = 0x5f58e3a2316349923ce3780f8d587db2d72378aed66a8261c916544fa6846ca5
#PROPOSER_ROLE = 0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1
#CANCELLER_ROLE = 0xfd643c72710c63c0180259aba6b2d05451e3591a24e58b62239378085726f783
#EXECUTOR_ROLE = 0xd8aa0f3194971a2a116679f7c2090f6939c8d4e01a2a8d7e41d55e5351469e63

TIMELOCK_ADMIN_ROLE = 0x1
PROPOSER_ROLE = 0x2
CANCELLER_ROLE = 0x3
EXECUTOR_ROLE = 0x4


@pytest.fixture(scope="module")
async def contract_defs():
    account_def = get_contract_def("openzeppelin/account/Account.cairo")
    timelock_def = get_contract_def("openzeppelin/governance/timelock/Timelock.cairo")
    init_def = get_contract_def("tests/mocks/Initializable.cairo")

    return account_def, timelock_def, init_def


@pytest.fixture(scope="module")
async def timelock_init(contract_defs):
    account_def, timelock_def, init_def = contract_defs
    starknet = await Starknet.empty()

    proposer = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )
    executor = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )
    timelock = await starknet.deploy(
        contract_def=timelock_def,
        constructor_calldata=[
            proposer.contract_address,
            executor.contract_address,
            DAY,
        ],
    )
    initializable = await starknet.deploy(
        contract_def=init_def,
    )
    initializable2 = await starknet.deploy(
        contract_def=init_def,
    )

    return starknet.state, proposer, executor, timelock, initializable, initializable2


@pytest.fixture(scope="module")
async def total_factory(contract_defs, timelock_init):
    account_def, timelock_def, init_def = contract_defs
    state, proposer, executor, timelock, initializable, initializable2 = timelock_init
    _state = state.copy()
    proposer = cached_contract(_state, account_def, proposer)
    executor = cached_contract(_state, account_def, executor)
    timelock = cached_contract(_state, timelock_def, timelock)
    initializable = cached_contract(_state, init_def, initializable)
    initializable2 = cached_contract(_state, init_def, initializable2)

    return _state, proposer, executor, timelock, initializable, initializable2


@pytest.fixture(scope="module")
async def initializable_factory(total_factory):
    _, _, _, _, initializable, initializable2 = total_factory

    # initializable init_call
    init_call = (
            initializable.contract_address,
            get_selector_from_name("initialize"),
            0,
            0,
        )

    # initializable call_array
    call_array = [1, *init_call, *[0], 0, 0, 2 * DAY]

    return init_call, call_array, initializable, initializable2


@pytest.fixture(scope="module")
async def timelock_factory(total_factory):
    _state, proposer, executor, timelock, *_ = total_factory
    return _state, proposer, executor, timelock


@pytest.mark.asyncio
async def test_constructor(timelock_factory):
    _, proposer, executor, timelock = timelock_factory

    execution_info = await timelock.hasRole(TIMELOCK_ADMIN_ROLE, timelock.contract_address).call()
    assert execution_info.result == (TRUE,)

    execution_info = await timelock.hasRole(PROPOSER_ROLE, proposer.contract_address).call()
    assert execution_info.result == (TRUE,)

    execution_info = await timelock.hasRole(CANCELLER_ROLE, proposer.contract_address).call()
    assert execution_info.result == (TRUE,)

    execution_info = await timelock.hasRole(EXECUTOR_ROLE, executor.contract_address).call()
    assert execution_info.result == (TRUE,)

    execution_info = await timelock.getMinDelay().call()
    assert execution_info.result == (DAY,)


@pytest.mark.asyncio
async def test_schedule(timelock_factory, initializable_factory):
    state, proposer, _, timelock = timelock_factory
    init_call, call_array, *_ = initializable_factory

    execution_info = await timelock.hashOperation([init_call], [], 0, 0).call()
    (operation_hash,) = execution_info.result

    block_timestamp = get_block_timestamp(state)

    await signer.send_transaction(
        proposer, timelock.contract_address, "schedule", call_array
    )

    execution_info = await timelock.getTimestamp(operation_hash).call()
    assert execution_info.result == (block_timestamp + (2 * DAY),)

    execution_info = await timelock.isOperation(operation_hash).call()
    assert execution_info.result == (TRUE,)

    execution_info = await timelock.isOperationPending(operation_hash).call()
    assert execution_info.result == (TRUE,)

    execution_info = await timelock.isOperationReady(operation_hash).call()
    assert execution_info.result == (FALSE,)


@pytest.mark.asyncio
async def test_schedule_emits_event(timelock_factory, initializable_factory):
    _, proposer, _, timelock = timelock_factory
    init_call, call_array, initializable, _ = initializable_factory

    execution_info = await timelock.hashOperation([init_call], [], 0, 0).call()
    (operation_hash,) = execution_info.result

    schedule_exec_info = await signer.send_transaction(
        proposer, timelock.contract_address, "schedule", call_array
    )

    assert_event_emitted(
        schedule_exec_info,
        timelock.contract_address,
        name="CallScheduled",
        data=[
            operation_hash,                         # id
            0,                                      # index
            initializable.contract_address,         # target
            get_selector_from_name("initialize"),   # selector
            *[0],                                   # calldata = *[0]
            0,                                      # predecessor
        ],
    )


@pytest.mark.asyncio
async def test_cancel(timelock_factory, initializable_factory):
    _, proposer, _, timelock = timelock_factory
    init_call, call_array, *_ = initializable_factory

    execution_info = await timelock.hashOperation([init_call], [], 0, 0).call()
    (operation_hash,) = execution_info.result

    await signer.send_transaction(
        proposer, timelock.contract_address, "schedule", call_array
    )

    execution_info_cancel = await signer.send_transaction(
        proposer, timelock.contract_address, "cancel", [operation_hash]
    )

    execution_info = await timelock.getTimestamp(operation_hash).call()
    assert execution_info.result == (0,)

    execution_info = await timelock.isOperation(operation_hash).call()
    assert execution_info.result == (FALSE,)

    execution_info = await timelock.isOperationPending(operation_hash).call()
    assert execution_info.result == (FALSE,)

    execution_info = await timelock.isOperationReady(operation_hash).call()
    assert execution_info.result == (FALSE,)


@pytest.mark.asyncio
async def test_cancel_emits_event(timelock_factory, initializable_factory):
    _, proposer, _, timelock = timelock_factory
    init_call, call_array, *_ = initializable_factory

    execution_info = await timelock.hashOperation([init_call], [], 0, 0).call()
    (operation_hash,) = execution_info.result

    await signer.send_transaction(
        proposer, timelock.contract_address, "schedule", call_array
    )

    execution_info_cancel = await signer.send_transaction(
        proposer, timelock.contract_address, "cancel", [operation_hash]
    )

    assert_event_emitted(
        execution_info_cancel,
        timelock.contract_address,
        "Cancelled",
        [operation_hash],
    )


@pytest.mark.asyncio
async def test_execute(timelock_factory, initializable_factory):
    state, proposer, executor, timelock = timelock_factory
    init_call, call_array, initializable, _ = initializable_factory

    execution_info = await initializable.initialized().call()
    assert execution_info.result == (FALSE,)

    execution_info = await timelock.hashOperation([init_call], [], 0, 0).call()
    (operation_hash,) = execution_info.result

    exec_array = [1, *init_call, *[0], 0, 0]

    await signer.send_transaction(
        proposer, timelock.contract_address, "schedule", call_array
    )

    set_block_timestamp(state, 2 * DAY)

    execution_info_exec = await signer.send_transaction(
        executor, timelock.contract_address, "execute", exec_array
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


@pytest.mark.asyncio
async def test_execute_emits_event(timelock_factory, initializable_factory):
    state, proposer, executor, timelock = timelock_factory
    init_call, call_array, initializable, _ = initializable_factory

    execution_info = await timelock.hashOperation([init_call], [], 0, 0).call()
    (operation_hash,) = execution_info.result

    exec_array = [1, *init_call, *[0], 0, 0]

    await signer.send_transaction(
        proposer, timelock.contract_address, "schedule", call_array
    )

    set_block_timestamp(state, 2 * DAY)

    execution_info_exec = await signer.send_transaction(
        executor, timelock.contract_address, "execute", exec_array
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


@pytest.mark.asyncio
async def test_execute_not_ready(timelock_factory, initializable_factory):
    _, proposer, executor, timelock = timelock_factory
    init_call, call_array, initializable, _ = initializable_factory

    execution_info = await initializable.initialized().call()
    assert execution_info.result == (FALSE,)

    execution_info = await timelock.hashOperation([init_call], [], 0, 0).call()

    exec_array = [1, *init_call, *[0], 0, 0]

    await signer.send_transaction(
        proposer, timelock.contract_address, "schedule", call_array
    )

    await assert_revert(
        signer.send_transaction(
            executor, timelock.contract_address, "execute", exec_array
        ),
        reverted_with="Timelock: operation is not ready",
    )


@pytest.mark.asyncio
async def test_execute_predecessor_not_executed(timelock_factory, initializable_factory):
    state, proposer, executor, timelock = timelock_factory
    init_call, call_array, _, initializable2,  = initializable_factory

    init_2_call = (
        initializable2.contract_address,
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

    await signer.send_transaction(
        proposer, timelock.contract_address, "schedule", call_array
    )

    await signer.send_transaction(
        proposer, timelock.contract_address, "schedule", call_array_2
    )

    set_block_timestamp(state, 2 * DAY)

    await assert_revert(
        signer.send_transaction(
            executor, timelock.contract_address, "execute", exec_array_2
        ),
        "Timelock: missing dependency",
    )
