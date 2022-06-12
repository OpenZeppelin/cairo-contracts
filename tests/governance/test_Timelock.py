import pytest
from itertools import count
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.public.abi import get_selector_from_name
from starkware.cairo.common.hash_state import compute_hash_on_elements

from utils import (
    TestSigner, assert_event_emitted, assert_revert, get_contract_def,
    cached_contract, get_block_timestamp, TRUE, FALSE, set_block_timestamp,
    format_calls_for_calls, format_calls_for_signer, to_uint, str_to_felt
)

signer = TestSigner(123456789987654321)

TIMELOCK_ADMIN_ROLE = 0x11
PROPOSER_ROLE = 0x22
CANCELLER_ROLE = 0x33
EXECUTOR_ROLE = 0x44

PROPOSERS = [111, 112, 113, 114]
EXECUTORS = [221, 222, 223, 224]

MIN_DELAY = 86400
NEW_MIN_DELAY = 21600
BAD_DELAY = 100
HELPER_CALLDATA = 5
PREDECESSOR = 101010101
INVALID_ID = 11223344
TOKEN = to_uint(5042)
# random data (mimicking bytes in Solidity)
DATA = [0x42, 0x89, 0x55]

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


def bad_batch(address):
    return format_calls_for_calls(
        [
            [address, "increaseCount", [HELPER_CALLDATA]],
            [address, "increaseCount", []],
            [address, "increaseCount", [HELPER_CALLDATA]]
        ]
    )


@pytest.fixture(scope="module")
async def contract_defs():
    account_def = get_contract_def("openzeppelin/account/Account.cairo")
    timelock_def = get_contract_def("openzeppelin/governance/timelock/Timelock.cairo")
    helper_def = get_contract_def("tests/mocks/TimelockHelper.cairo")
    erc721_def = get_contract_def('openzeppelin/token/erc721/ERC721_Mintable_Burnable.cairo')

    return account_def, timelock_def, helper_def, erc721_def


@pytest.fixture(scope="module")
async def timelock_init(contract_defs):
    account_def, timelock_def, helper_def, erc721_def = contract_defs
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
    erc721 = await starknet.deploy(
        contract_def=erc721_def,
        constructor_calldata=[
            str_to_felt("Non Fungible Token"),  # name
            str_to_felt("NFT"),                 # ticker
            proposer.contract_address           # owner
        ]
    )

    # cache contracts
    _state = starknet.state.copy()
    proposer = cached_contract(_state, account_def, proposer)
    executor = cached_contract(_state, account_def, executor)
    timelock = cached_contract(_state, timelock_def, timelock)
    helper = cached_contract(_state, helper_def, helper)
    erc721 = cached_contract(_state, erc721_def, erc721)

    return _state, proposer, executor, timelock, helper, erc721


@pytest.fixture(scope="module")
async def timelock_factory(timelock_init):
    state, proposer, executor, timelock, helper, _ = timelock_init

    return timelock, proposer, executor, helper, state


@pytest.fixture(scope="module")
async def timelock_with_erc721(timelock_init):
    _, account, _, timelock, _, erc721 = timelock_init

    # mint token to account
    await signer.send_transaction(
        account, erc721.contract_address, 'mint', [
            account.contract_address,
            *TOKEN,
        ]
    )

    return timelock, account, erc721

#
# constructor
#

@pytest.mark.asyncio
@pytest.mark.parametrize('role, addresses, not_role', [
    [PROPOSER_ROLE, PROPOSERS, EXECUTOR_ROLE],
    [CANCELLER_ROLE, PROPOSERS, EXECUTOR_ROLE],
    [EXECUTOR_ROLE, EXECUTORS, PROPOSER_ROLE],
])
async def test_constructor_roles_arrays(timelock_factory, role, addresses, not_role):
    timelock, *_ = timelock_factory

    for i in range(len(addresses)):
        execution_info = await timelock.hasRole(role, addresses[i]).call()
        assert execution_info.result == (TRUE,)

        execution_info = await timelock.hasRole(not_role, addresses[i]).call()
        assert execution_info.result == (FALSE,)


@pytest.mark.asyncio
async def test_constructor(timelock_factory):
    timelock, deployer, *_ = timelock_factory

    # check delay
    execution_info = await timelock.getMinDelay().call()
    assert execution_info.result == (MIN_DELAY,)

    # check self as admin
    execution_info = await timelock.hasRole(TIMELOCK_ADMIN_ROLE, timelock.contract_address).call()
    assert execution_info.result == (TRUE,)

    # check deployer as admin
    execution_info = await timelock.hasRole(TIMELOCK_ADMIN_ROLE, deployer.contract_address).call()
    assert execution_info.result == (TRUE,)


#
# hashOperation
#

@pytest.mark.asyncio
async def test_hashOperation(timelock_factory):
    timelock, _, _, helper, _ = timelock_factory

    salt = next(SALT_IID)

    # hash single operation
    operation = gen_operation(helper.contract_address)
    execution_info = await timelock.hashOperation(*operation, 0, salt).call()

    calculate_hash_operation = compute_hash_on_elements([
        compute_hash_on_elements([
            helper.contract_address,                        # to
            get_selector_from_name("increaseCount"),        # selector
            compute_hash_on_elements([HELPER_CALLDATA])]),  # hashed calldata
        1,                                                  # calldata length
        0,                                                  # predecessor
        salt                                                # salt
    ])

    assert execution_info.result.hash == calculate_hash_operation


@pytest.mark.asyncio
async def test_hashOperation_batch(timelock_factory):
    timelock, _, _, helper, _ = timelock_factory

    salt = next(SALT_IID)

    # hash batched operations
    operation = batch_operations(helper.contract_address)
    execution_info = await timelock.hashOperation(*operation, 0, salt).call()

    call = compute_hash_on_elements([
        helper.contract_address,
        get_selector_from_name("increaseCount"),
        compute_hash_on_elements([HELPER_CALLDATA])
    ])

    calculate_hash_operation = compute_hash_on_elements([
        call,                                               #
        call,                                               # calls
        call,                                               #
        3,                                                  # calldata length
        0,                                                  # predecessor
        salt                                                # salt
    ])
            

    assert execution_info.result.hash == calculate_hash_operation


@pytest.mark.asyncio
async def test_hashOperation_batch_with_predecessor(timelock_factory):
    timelock, _, _, helper, _ = timelock_factory

    salt = next(SALT_IID)

    # hash batched operations with predecessor
    operation = batch_operations(helper.contract_address)
    execution_info = await timelock.hashOperation(*operation, PREDECESSOR, salt).call()

    call = compute_hash_on_elements([
        helper.contract_address,
        get_selector_from_name("increaseCount"),
        compute_hash_on_elements([HELPER_CALLDATA])
    ])

    calculate_hash_operation = compute_hash_on_elements([
        call,                                               #
        call,                                               # calls
        call,                                               #
        3,                                                  # calldata length
        PREDECESSOR,                                        # predecessor
        salt                                                # salt
    ])

    assert execution_info.result.hash == calculate_hash_operation

#
# schedule
#

@pytest.mark.asyncio
async def test_schedule_is_scheduled(timelock_factory):
    timelock, proposer, _, helper, _ = timelock_factory

    salt = next(SALT_IID)

    # get hash id
    operation = gen_operation(helper.contract_address)
    execution_info = await timelock.hashOperation(*operation, 0, salt).call()
    hash_id = execution_info.result.hash

    # check id is not scheduled
    execution_info = await timelock.isOperation(hash_id).call()
    assert execution_info.result == (FALSE,)

    # check id is not pending
    execution_info = await timelock.isOperationPending(hash_id).call()
    assert execution_info.result == (FALSE,)

    # check id is not ready
    execution_info = await timelock.isOperationReady(hash_id).call()
    assert execution_info.result == (FALSE,)

    # check id is not done
    execution_info = await timelock.isOperationDone(hash_id).call()
    assert execution_info.result == (FALSE,)

    # check timestamp
    execution_info = await timelock.getTimestamp(hash_id).call()
    assert execution_info.result == (0,)

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

    # check id is scheduled
    execution_info = await timelock.isOperation(hash_id).call()
    assert execution_info.result == (TRUE,)

    # check id is pending
    execution_info = await timelock.isOperationPending(hash_id).call()
    assert execution_info.result == (TRUE,)

    # check id is not ready
    execution_info = await timelock.isOperationReady(hash_id).call()
    assert execution_info.result == (FALSE,)

    # check id is not done
    execution_info = await timelock.isOperationDone(hash_id).call()
    assert execution_info.result == (FALSE,)

    # check timestamp
    execution_info = await timelock.getTimestamp(hash_id).call()
    assert execution_info.result == (MIN_DELAY,)


@pytest.mark.asyncio
async def test_schedule_emits_event(timelock_factory):
    timelock, proposer, _, helper, _ = timelock_factory

    salt = next(SALT_IID)

    # get hash id
    operation = gen_operation(helper.contract_address)
    execution_info = await timelock.hashOperation(*operation, 0, salt).call()
    hash_id = execution_info.result.hash

    # format call array
    call_array = format_calls_for_signer(
        gen_operation(helper.contract_address)
    )

    # schedule operation
    tx_exec_info = await signer.send_transaction(
        proposer, timelock.contract_address, "schedule", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
            MIN_DELAY                                # delay
        ])

    # check event
    assert_event_emitted(
        tx_exec_info,
        from_address=timelock.contract_address,
        name='CallScheduled',
        data=[
            hash_id,                                 # id
            0,                                       # index
            helper.contract_address,                 # target
            get_selector_from_name("increaseCount"), # selector
            1,                                       # calldata length
            HELPER_CALLDATA,                         # calldata
            0,                                       # predecessor
            MIN_DELAY                                # delay
        ]
    )


@pytest.mark.asyncio
async def test_schedule_prevents_overwriting_active_operation(timelock_factory):
    timelock, proposer, _, helper, _ = timelock_factory

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
    
    # repeated operation should fail
    await assert_revert(signer.send_transaction(
        proposer, timelock.contract_address, "schedule", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
            MIN_DELAY                                # delay
        ]),
        reverted_with="Timelock: operation already scheduled"
    )

@pytest.mark.asyncio
async def test_schedule_prevents_nonproposer_from_committing(timelock_factory):
    timelock, _, nonproposer, helper, _ = timelock_factory

    salt = next(SALT_IID)

    # format call array
    call_array = format_calls_for_signer(
        gen_operation(helper.contract_address)
    )

    # non-proposer invocation should fail
    await assert_revert(signer.send_transaction(
        nonproposer, timelock.contract_address, "schedule", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
            MIN_DELAY                                # delay
        ]),
        reverted_with=f"AccessControl: caller is missing role {PROPOSER_ROLE}"
    )


@pytest.mark.asyncio
async def test_schedule_enforce_minimum_delay(timelock_factory):
    timelock, proposer, _, helper, _ = timelock_factory

    salt = next(SALT_IID)

    # format call array
    call_array = format_calls_for_signer(
        gen_operation(helper.contract_address)
    )

    # delay under threshold should fail
    await assert_revert(signer.send_transaction(
        proposer, timelock.contract_address, "schedule", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
            BAD_DELAY                                # delay
        ]),
        reverted_with="Timelock: insufficient delay"
    )


@pytest.mark.asyncio
async def test_schedule_enforce_overflow_check(timelock_factory):
    timelock, proposer, _, helper, state = timelock_factory

    salt = next(SALT_IID)

    # format call array
    call_array = format_calls_for_signer(
        gen_operation(helper.contract_address)
    )

    # set timestamp otherwise felt can't hold overflowing int
    set_block_timestamp(state, 2**128)

    delay_overflow = 2**128

    # delay overflow should fail
    await assert_revert(signer.send_transaction(
        proposer, timelock.contract_address, "schedule", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
            delay_overflow                           # delay
        ]),
        reverted_with="Timelock: timestamp overflow"
    )

#
# execute
#

@pytest.mark.asyncio
async def test_execute_when_operation_not_scheduled(timelock_factory):
    timelock, _, executor, helper, _ = timelock_factory

    salt = next(SALT_IID)

    # format call array
    call_array = format_calls_for_signer(
        gen_operation(helper.contract_address)
    )

    # execute should fail when not ready
    await assert_revert(signer.send_transaction(
        executor, timelock.contract_address, "execute", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
        ]),
        reverted_with="Timelock: operation is not ready"
    )


@pytest.mark.asyncio
async def test_execute_when_too_early_PART_ONE(timelock_factory):
    timelock, proposer, executor, helper, _ = timelock_factory

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

    # operation should fail when under delay
    await assert_revert(signer.send_transaction(
        executor, timelock.contract_address, "execute", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
        ]),
        reverted_with="Timelock: operation is not ready"
    )


@pytest.mark.asyncio
async def test_execute_when_too_early_PART_TWO(timelock_factory):
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

    current_time = get_block_timestamp(state)
    set_block_timestamp(state, current_time + MIN_DELAY - 1)

    # operation should fail when under delay
    await assert_revert(signer.send_transaction(
        executor, timelock.contract_address, "execute", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
        ]),
        reverted_with="Timelock: operation is not ready"
    )


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

    # check id is pending
    execution_info = await timelock.isOperationPending(hash_id).call()
    assert execution_info.result == (TRUE,)

    # check id is not done
    execution_info = await timelock.isOperationDone(hash_id).call()
    assert execution_info.result == (FALSE,)

    current_time = get_block_timestamp(state)
    set_block_timestamp(state, current_time + MIN_DELAY + 3)

    # execute
    await signer.send_transaction(
        executor, timelock.contract_address, "execute", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
        ])

    # check id is no longer pending
    execution_info = await timelock.isOperationPending(hash_id).call()
    assert execution_info.result == (FALSE,)

    # check id is done
    execution_info = await timelock.isOperationDone(hash_id).call()
    assert execution_info.result == (TRUE,)

    # check helper contract
    execution_info = await helper.getCount().call()
    assert execution_info.result == (INIT_COUNT + HELPER_CALLDATA,)


@pytest.mark.asyncio
async def test_execute_emits_event(timelock_factory):
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

    current_time = get_block_timestamp(state)
    set_block_timestamp(state, current_time + MIN_DELAY + 3)

    # execute
    tx_exec_info = await signer.send_transaction(
        executor, timelock.contract_address, "execute", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
        ])

    # check event
    assert_event_emitted(
        tx_exec_info,
        from_address=timelock.contract_address,
        name='CallExecuted',
        data=[
            hash_id,                                 # id
            0,                                       # index
            helper.contract_address,                 # target
            get_selector_from_name("increaseCount"), # selector
            1,                                       # calldata length
            HELPER_CALLDATA,                         # calldata
        ]
    )


@pytest.mark.asyncio
async def test_execute_prevent_nonexecutor_from_reveal(timelock_factory):
    timelock, proposer, _, helper, state = timelock_factory

    salt = next(SALT_IID)

    set_block_timestamp(state, MIN_DELAY)

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

    # execute with non-executor
    await assert_revert(signer.send_transaction(
        proposer, timelock.contract_address, "execute", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
        ]),
        reverted_with=f"AccessControl: caller is missing role {EXECUTOR_ROLE}"
    )

#
# batch schedule
#

@pytest.mark.asyncio
async def test_schedule_batch_is_scheduled(timelock_factory):
    timelock, proposer, _, helper, state = timelock_factory

    salt = next(SALT_IID)

    # get hash id
    operation = batch_operations(helper.contract_address)
    execution_info = await timelock.hashOperation(*operation, 0, salt).call()
    hash_id = execution_info.result.hash

    # check id is not scheduled
    execution_info = await timelock.isOperation(hash_id).call()
    assert execution_info.result == (FALSE,)

    # check id is not pending
    execution_info = await timelock.isOperationPending(hash_id).call()
    assert execution_info.result == (FALSE,)

    # check id is not ready
    execution_info = await timelock.isOperationReady(hash_id).call()
    assert execution_info.result == (FALSE,)

    # check id is not done
    execution_info = await timelock.isOperationDone(hash_id).call()
    assert execution_info.result == (FALSE,)

    # check timestamp
    execution_info = await timelock.getTimestamp(hash_id).call()
    assert execution_info.result == (0,)

    # format call array
    call_array = format_calls_for_signer(
        batch_operations(helper.contract_address)
    )

    current_time = get_block_timestamp(state)

    # schedule operation
    await signer.send_transaction(
        proposer, timelock.contract_address, "schedule", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
            MIN_DELAY                                # delay
        ])

    # check id is scheduled
    execution_info = await timelock.isOperation(hash_id).call()
    assert execution_info.result == (TRUE,)

    # check id is pending
    execution_info = await timelock.isOperationPending(hash_id).call()
    assert execution_info.result == (TRUE,)

    # check id is not ready
    execution_info = await timelock.isOperationReady(hash_id).call()
    assert execution_info.result == (FALSE,)

    # check id is not done
    execution_info = await timelock.isOperationDone(hash_id).call()
    assert execution_info.result == (FALSE,)

    # check timestamp
    execution_info = await timelock.getTimestamp(hash_id).call()
    assert execution_info.result == (current_time + MIN_DELAY,)


@pytest.mark.asyncio
async def test_schedule_batch_emits_events(timelock_factory):
    timelock, proposer, _, helper, _ = timelock_factory

    salt = next(SALT_IID)

    # get hash id
    operation = batch_operations(helper.contract_address)
    execution_info = await timelock.hashOperation(*operation, 0, salt).call()
    hash_id = execution_info.result.hash

    # format call array
    call_array = format_calls_for_signer(
        batch_operations(helper.contract_address)
    )

    # schedule operations
    tx_exec_info = await signer.send_transaction(
        proposer, timelock.contract_address, "schedule", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
            MIN_DELAY                                # delay
        ])

    # check events
    num_calls = call_array[0]

    for index in range(0, num_calls):
        assert_event_emitted(
            tx_exec_info,
            from_address=timelock.contract_address,
            name='CallScheduled',
            data=[
                hash_id,                                 # id
                index,                                   # index
                helper.contract_address,                 # target
                get_selector_from_name("increaseCount"), # selector
                1,                                       # calldata length
                HELPER_CALLDATA,                         # calldata
                0,                                       # predecessor
                MIN_DELAY                                # delay
            ]
        )


@pytest.mark.asyncio
async def test_schedule_batch_prevents_overwriting_active_operation(timelock_factory):
    timelock, proposer, _, helper, _ = timelock_factory

    salt = next(SALT_IID)

    # format call array
    call_array = format_calls_for_signer(
        batch_operations(helper.contract_address)
    )

    # schedule operation
    await signer.send_transaction(
        proposer, timelock.contract_address, "schedule", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
            MIN_DELAY                                # delay
        ])

    # repeated operation should fail
    await assert_revert(signer.send_transaction(
        proposer, timelock.contract_address, "schedule", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
            MIN_DELAY                                # delay
        ]),
        reverted_with="Timelock: operation already scheduled"
    )


@pytest.mark.asyncio
@pytest.mark.parametrize('bad_params', [
    ["add"],
    ["sub"],
])
async def test_schedule_batch_mismatched_calldata_params(timelock_factory, bad_params):
    timelock, proposer, _, helper, _ = timelock_factory

    salt = next(SALT_IID)

    # format array
    call_array = format_calls_for_signer(
        batch_operations(helper.contract_address)
    )

    # add/remove last calldata element
    def bad_calldata_len(param):
        if param == "add":
            x = call_array[-1]
            call_array.append(x)
        else:
            call_array.pop()
        return call_array

    # wrong calldata length should throw
    await assert_revert(signer.send_transaction(
        proposer, timelock.contract_address, "schedule", [
            *bad_calldata_len(bad_params),           # bad call array
            0,                                       # predecessor
            salt,                                    # salt
            MIN_DELAY                                # delay
        ])
    )


@pytest.mark.asyncio
@pytest.mark.parametrize('bad_params', [
    ["add"],
    ["sub"]
])
async def test_schedule_batch_mismatched_address_params(timelock_factory, bad_params):
    timelock, proposer, _, helper, _ = timelock_factory

    salt = next(SALT_IID)

    # format bad array
    call_array = format_calls_for_signer(
        batch_operations(helper.contract_address)
    )

    def bad_address_len(param):
        x = call_array.copy()
        if param == "add":
            x[0] = call_array[0] + 1
        else:
            x[0] = call_array[0] - 1
        return x

    # wrong address len should throw
    await assert_revert(signer.send_transaction(
        proposer, timelock.contract_address, "schedule", [
            *bad_address_len(bad_params),            # call array
            0,                                       # predecessor
            salt,                                    # salt
            MIN_DELAY                                # delay
        ])
    )


@pytest.mark.asyncio
async def test_schedule_batch_prevents_nonproposer_from_committing(timelock_factory):
    timelock, _, nonproposer, helper, _ = timelock_factory

    salt = next(SALT_IID)

    # format call array
    call_array = format_calls_for_signer(
        batch_operations(helper.contract_address)
    )

    # non-proposer invocation should fail
    await assert_revert(signer.send_transaction(
        nonproposer, timelock.contract_address, "schedule", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
            MIN_DELAY                                # delay
        ]),
        reverted_with=f"AccessControl: caller is missing role {PROPOSER_ROLE}"
    )


@pytest.mark.asyncio
async def test_schedule_batch_enforce_minimum_delay(timelock_factory):
    timelock, proposer, _, helper, _ = timelock_factory

    salt = next(SALT_IID)

    # format call array
    call_array = format_calls_for_signer(
        batch_operations(helper.contract_address)
    )

    # delay under threshold should fail
    await assert_revert(signer.send_transaction(
        proposer, timelock.contract_address, "schedule", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
            BAD_DELAY                                # delay
        ]),
        reverted_with="Timelock: insufficient delay"
    )

#
# execute batch
#


@pytest.mark.asyncio
async def test_execute_batch_when_operation_not_scheduled(timelock_factory):
    timelock, _, executor, helper, _ = timelock_factory

    salt = next(SALT_IID)

    # format call array
    call_array = format_calls_for_signer(
        batch_operations(helper.contract_address)
    )

    # execute should fail when not scheduled
    await assert_revert(signer.send_transaction(
        executor, timelock.contract_address, "execute", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
        ]),
        reverted_with="Timelock: operation is not ready"
    )


@pytest.mark.asyncio
async def test_execute_batch_when_too_early_PART_ONE(timelock_factory):
    timelock, proposer, executor, helper, _ = timelock_factory

    salt = next(SALT_IID)

    # format call array
    call_array = format_calls_for_signer(
        batch_operations(helper.contract_address)
    )

    # schedule operation
    await signer.send_transaction(
        proposer, timelock.contract_address, "schedule", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
            MIN_DELAY                                # delay
        ])

    # operation should fail when under delay
    await assert_revert(signer.send_transaction(
        executor, timelock.contract_address, "execute", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
        ]),
        reverted_with="Timelock: operation is not ready"
    )


@pytest.mark.asyncio
async def test_execute_batch_when_too_early_PART_TWO(timelock_factory):
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

    current_time = get_block_timestamp(state)
    set_block_timestamp(state, current_time + MIN_DELAY - 1)

    # operation should fail when under delay
    await assert_revert(signer.send_transaction(
        executor, timelock.contract_address, "execute", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
        ]),
        reverted_with="Timelock: operation is not ready"
    )


@pytest.mark.asyncio
async def test_execute_batch(timelock_factory):
    timelock, proposer, executor, helper, state = timelock_factory

    salt = next(SALT_IID)

    # format call array
    call_array = format_calls_for_signer(
        batch_operations(helper.contract_address)
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
    operation = batch_operations(helper.contract_address)
    execution_info = await timelock.hashOperation(*operation, 0, salt).call()
    hash_id = execution_info.result.hash

    # check id is pending
    execution_info = await timelock.isOperationPending(hash_id).call()
    assert execution_info.result == (TRUE,)

    # check id is not done
    execution_info = await timelock.isOperationDone(hash_id).call()
    assert execution_info.result == (FALSE,)

    current_time = get_block_timestamp(state)
    set_block_timestamp(state, current_time + MIN_DELAY + 3)

    # execute
    await signer.send_transaction(
        executor, timelock.contract_address, "execute", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
        ])

    # check id is no longer pending
    execution_info = await timelock.isOperationPending(hash_id).call()
    assert execution_info.result == (FALSE,)

    # check id is done
    execution_info = await timelock.isOperationDone(hash_id).call()
    assert execution_info.result == (TRUE,)

    # check helper contract
    execution_info = await helper.getCount().call()
    # mulitply calldata by total calls in batch 
    helper_total = call_array[0] * HELPER_CALLDATA
    assert execution_info.result == (INIT_COUNT + helper_total,)


@pytest.mark.asyncio
async def test_execute_batch_emits_events(timelock_factory):
    timelock, proposer, executor, helper, state = timelock_factory

    salt = next(SALT_IID)

    # format call array
    call_array = format_calls_for_signer(
        batch_operations(helper.contract_address)
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
    operation = batch_operations(helper.contract_address)
    execution_info = await timelock.hashOperation(*operation, 0, salt).call()
    hash_id = execution_info.result.hash

    current_time = get_block_timestamp(state)
    set_block_timestamp(state, current_time + MIN_DELAY + 3)

    # execute
    tx_exec_info = await signer.send_transaction(
        executor, timelock.contract_address, "execute", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
        ])

    # check events
    for index in range(0, call_array[0]):
        assert_event_emitted(
            tx_exec_info,
            from_address=timelock.contract_address,
            name='CallExecuted',
            data=[
                hash_id,                                 # id
                index,                                   # index
                helper.contract_address,                 # target
                get_selector_from_name("increaseCount"), # selector
                1,                                       # calldata length
                HELPER_CALLDATA,                         # calldata
            ]
        )


@pytest.mark.asyncio
@pytest.mark.parametrize('bad_params', [
    ["add"],
    ["sub"],
])
async def test_execute_batch_mismatched_calldata_params(timelock_factory, bad_params):
    timelock, proposer, executor, helper, state = timelock_factory

    salt = next(SALT_IID)

    # format call array
    call_array = format_calls_for_signer(
        batch_operations(helper.contract_address)
    )

    # schedule operation
    await signer.send_transaction(
        proposer, timelock.contract_address, "schedule", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
            MIN_DELAY                                # delay
        ])

    current_time = get_block_timestamp(state)
    set_block_timestamp(state, current_time + MIN_DELAY + 3)

    # add/remove last calldata element
    def bad_calldata_len(param):
        if param == "add":
            x = call_array[-1]
            call_array.append(x)
        else:
            call_array.pop()
        return call_array

    # wrong calldata length should throw
    await assert_revert(signer.send_transaction(
        executor, timelock.contract_address, "execute", [
            *bad_calldata_len(bad_params),           # call array
            0,                                       # predecessor
            salt                                     # salt
        ])
    )


@pytest.mark.asyncio
@pytest.mark.parametrize('bad_params', [
    ["add"],
    ["sub"]
])
async def test_execute_batch_mismatched_address_params(timelock_factory, bad_params):
    timelock, proposer, executor, helper, state = timelock_factory

    salt = next(SALT_IID)

    # format call array
    call_array = format_calls_for_signer(
        batch_operations(helper.contract_address)
    )

    # schedule operation
    await signer.send_transaction(
        proposer, timelock.contract_address, "schedule", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
            MIN_DELAY                                # delay
        ])

    current_time = get_block_timestamp(state)
    set_block_timestamp(state, current_time + MIN_DELAY + 3)

    def bad_address_len(param):
        x = call_array.copy()
        if param == "add":
            x[0] = call_array[0] + 1
        else:
            x[0] = call_array[0] - 1
        return x

    # wrong address len should throw
    await assert_revert(signer.send_transaction(
        executor, timelock.contract_address, "execute", [
            *bad_address_len(bad_params),            # call array
            0,                                       # predecessor
            salt                                     # salt
        ])
    )


@pytest.mark.asyncio
async def test_execute_batch_partial_execution(timelock_factory):
    timelock, proposer, executor, helper, state = timelock_factory

    salt = next(SALT_IID)

    # format call array
    call_array = format_calls_for_signer(
        bad_batch(helper.contract_address)
    )

    # schedule operation
    await signer.send_transaction(
        proposer, timelock.contract_address, "schedule", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
            MIN_DELAY                                # delay
        ])

    current_time = get_block_timestamp(state)
    set_block_timestamp(state, current_time + MIN_DELAY + 3)

    # execute
    await assert_revert(signer.send_transaction(
        executor, timelock.contract_address, "execute", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
        ]),
        reverted_with="Timelock: underlying transaction reverted"
    )

#
# cancel
#

@pytest.mark.asyncio
async def test_canceller_can_cancel(timelock_factory):
    timelock, proposer, _, helper, _ = timelock_factory

    salt = next(SALT_IID)

    # get hash id
    operation = gen_operation(helper.contract_address)
    execution_info = await timelock.hashOperation(*operation, 0, salt).call()
    hash_id = execution_info.result.hash

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

    # cancel (proposer also has canceller role)
    tx_exec_info = await signer.send_transaction(
        proposer, timelock.contract_address, "cancel", [hash_id]
    )

    # check id is not scheduled
    execution_info = await timelock.isOperation(hash_id).call()
    assert execution_info.result == (FALSE,)

    # check id is not pending
    execution_info = await timelock.isOperationPending(hash_id).call()
    assert execution_info.result == (FALSE,)

    # check id is not ready
    execution_info = await timelock.isOperationReady(hash_id).call()
    assert execution_info.result == (FALSE,)

    # check id is not done
    execution_info = await timelock.isOperationDone(hash_id).call()
    assert execution_info.result == (FALSE,)

    # check timestamp
    execution_info = await timelock.getTimestamp(hash_id).call()
    assert execution_info.result == (0,)

    # check event
    assert_event_emitted(
        tx_exec_info,
        from_address=timelock.contract_address,
        name='Cancelled',
        data=[hash_id]
    )


@pytest.mark.asyncio
async def test_cancel_invalid_operation(timelock_factory):
    timelock, proposer, _, _, _ = timelock_factory

    # cancel (proposer also has canceller role)
    await assert_revert(signer.send_transaction(
        proposer, timelock.contract_address, "cancel", [INVALID_ID]),
        reverted_with="Timelock: operation cannot be cancelled"
    )


@pytest.mark.asyncio
async def test_cancel_from_noncanceller(timelock_factory):
    timelock, proposer, noncanceller, helper, _ = timelock_factory

    salt = next(SALT_IID)

    # get hash id
    operation = gen_operation(helper.contract_address)
    execution_info = await timelock.hashOperation(*operation, 0, salt).call()
    hash_id = execution_info.result.hash

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

    # cancel (proposer also has canceller role)
    await assert_revert(signer.send_transaction(
        noncanceller, timelock.contract_address, "cancel", [hash_id]),
        reverted_with=f"AccessControl: caller is missing role {CANCELLER_ROLE}"
    )

#
# updateDelay
#

@pytest.mark.asyncio
async def test_updateDelay_from_unauthorized(timelock_factory):
    timelock, other, _, _, _ = timelock_factory

    # should fail since timelock contract must be the caler
    await assert_revert(signer.send_transaction(
        other, timelock.contract_address, "updateDelay", [NEW_MIN_DELAY]),
        reverted_with="Timelock: caller must be timelock"
    )


@pytest.mark.asyncio
async def test_updateDelay_scheduled_maintenance(timelock_factory):
    timelock, proposer, executor, _, state = timelock_factory

    salt = next(SALT_IID)

    init_format = format_calls_for_calls(
        [[timelock.contract_address, "updateDelay", [NEW_MIN_DELAY]]]
    )

    # format call array
    call_array = format_calls_for_signer(init_format)

    # schedule operation
    await signer.send_transaction(
        proposer, timelock.contract_address, "schedule", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
            MIN_DELAY                                # delay
        ])

    current_time = get_block_timestamp(state)
    set_block_timestamp(state, current_time + MIN_DELAY + 3)

    # execute
    tx_exec_info = await signer.send_transaction(
        executor, timelock.contract_address, "execute", [
            *call_array,                             # call array
            0,                                       # predecessor
            salt,                                    # salt
        ])

    # check event
    assert_event_emitted(
        tx_exec_info,
        from_address=timelock.contract_address,
        name='MinDelayChange',
        data=[
            MIN_DELAY,
            NEW_MIN_DELAY,
        ]
    )

   # check new delay is set
    execution_info = await timelock.getMinDelay().call()
    assert execution_info.result == (NEW_MIN_DELAY,)

#
# dependency
# 

@pytest.mark.asyncio
async def test_execute_before_dependency(timelock_factory):
    timelock, proposer, executor, helper, state = timelock_factory

    salt = next(SALT_IID)

    # format call array
    call_array = format_calls_for_signer(
        gen_operation(helper.contract_address)
    )

    # get hash id
    operation = gen_operation(helper.contract_address)
    execution_info = await timelock.hashOperation(*operation, 0, salt).call()
    hash_id_1 = execution_info.result.hash

    # schedule operations
    await signer.send_transactions(
        proposer,
        [
            (timelock.contract_address, 'schedule',
                [*call_array, 0, salt, MIN_DELAY]
            ),
            (timelock.contract_address, 'schedule',
                [*call_array, hash_id_1, salt, MIN_DELAY]
            ),
        ]
    )

    current_time = get_block_timestamp(state)
    set_block_timestamp(state, current_time + MIN_DELAY + 3)

    # execute
    await assert_revert(signer.send_transaction(
        executor, timelock.contract_address, "execute", [
            *call_array,                             # call array
            hash_id_1,                               # predecessor
            salt,                                    # salt
        ]),
        reverted_with="Timelock: missing dependency"
    )

#
# safe receive
#

@pytest.mark.asyncio
async def test_receive_erc721_safe_transfer(timelock_with_erc721):
    timelock, owner, erc721 = timelock_with_erc721

    await signer.send_transaction(
        owner, erc721.contract_address, 'safeTransferFrom', [
            owner.contract_address,
            timelock.contract_address,
            *TOKEN,
            len(DATA),
            *DATA
        ]
    )
