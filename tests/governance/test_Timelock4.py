import pytest
from itertools import count
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.public.abi import get_selector_from_name
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from starkware.starknet.compiler.compile import compile_starknet_files
from starkware.cairo.common.hash_state import compute_hash_on_elements


from utils import (
    TestSigner, assert_event_emitted, assert_revert, get_contract_def,
    cached_contract, get_block_timestamp, TRUE, FALSE, set_block_timestamp,
    format_calls_for_calls, format_calls_for_signer
)

signer = TestSigner(123456789987654321)

TIMELOCK_ADMIN_ROLE = 0x11
PROPOSER_ROLE = 0x22
CANCELLER_ROLE = 0x33
EXECUTOR_ROLE = 0x44

PROPOSERS = [111, 112, 113, 114]
EXECUTORS = [221, 222, 223, 224]

MIN_DELAY = 86400
BAD_DELAY = 100
HELPER_CALLDATA = 5
PREDECESSOR = get_selector_from_name("decreaseCount")

# random amount for helper contract
INIT_COUNT = 100

# to prevent hash id collisions between tests, the salt is incremented for test case
SALT_IID = count(100)


def gen_operation(address):
    return format_calls_for_calls(
        [
            [address, "increaseCount", [HELPER_CALLDATA]]
        ]
    )


def batch_operations(address):
    return format_calls_for_calls(
        [
            [address, "increaseCount", [HELPER_CALLDATA]],
            [address, "increaseCount", [HELPER_CALLDATA]],
            [address, "increaseCount", [HELPER_CALLDATA]]
        ]
    )


@pytest.fixture(scope="module")
async def contract_defs():
    account_def = get_contract_def("openzeppelin/account/Account.cairo")
    timelock_def = get_contract_def("openzeppelin/governance/timelock/Timelock.cairo")
    helper_def = get_contract_def("tests/mocks/TimelockHelper.cairo")

    return account_def, timelock_def, helper_def


@pytest.fixture(scope="module")
async def timelock_init(contract_defs):
    account_def, timelock_def, helper_def = contract_defs
    starknet = await Starknet.empty()

    proposer = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )
    executor = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )

    # add accounts to proposers and executors arrays
    PROPOSERS.append(proposer.contract_address)
    EXECUTORS.append(executor.contract_address)

    timelock = await starknet.deploy(
        contract_def=timelock_def,
        constructor_calldata=[
            MIN_DELAY,                  # delay
            proposer.contract_address,  # deployer
            len(PROPOSERS),             # proposers length
            *PROPOSERS,                 # proposers array
            len(EXECUTORS),             # executors length
            *EXECUTORS                  # executors array
        ],
    )
    helper = await starknet.deploy(
        contract_def=helper_def,
        constructor_calldata=[INIT_COUNT]
    )

    return starknet.state, proposer, executor, timelock, helper


@pytest.fixture(scope="module")
async def timelock_factory(contract_defs, timelock_init):
    account_def, timelock_def, helper_def = contract_defs
    state, proposer, executor, timelock, helper = timelock_init
    _state = state.copy()
    proposer = cached_contract(_state, account_def, proposer)
    executor = cached_contract(_state, account_def, executor)
    timelock = cached_contract(_state, timelock_def, timelock)
    helper = cached_contract(_state, helper_def, helper)

    return timelock, proposer, executor, helper, state


@pytest.mark.asyncio
async def test_execute(timelock_factory):
    timelock, proposer, executor, helper, state = timelock_factory

    salt = next(SALT_IID)

    # format call array
    call_array = format_calls_for_signer(
        gen_operation(helper.contract_address)
    )

    # schedule operation
    await signer.send_transaction(
        proposer, timelock.contract_address, "schedule", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
            MIN_DELAY                                # delay
        ])

    # get hash id
    operation = gen_operation(helper.contract_address)
    execution_info = await timelock.hashOperation(*operation, 0, salt).call()
    hash_id = execution_info.result.hash

    # check id is ready
    execution_info = await timelock.isOperationReady(hash_id).call()
    assert execution_info.result == (FALSE,)

    execution_info = await timelock.getTimestamp(hash_id).call()
    get_time = execution_info.result.timestamp

    set_block_timestamp(state, get_time)

    get_block = get_block_timestamp(state)
    assert get_block == get_time

    # check id is ready
    execution_info = await timelock.isOperationReady(hash_id).call()
    assert execution_info.result == (TRUE,)
