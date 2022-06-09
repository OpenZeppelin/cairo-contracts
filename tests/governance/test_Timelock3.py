from concurrent.futures import Executor
import pytest
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.public.abi import get_selector_from_name
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from starkware.starknet.compiler.compile import compile_starknet_files

from utils import (
    TestSigner, assert_event_emitted, assert_revert, get_contract_def,
    cached_contract, get_block_timestamp, TRUE, FALSE, set_block_timestamp,
)

signer = TestSigner(123456789987654321)

DAY_DELAY = 86400

#TIMELOCK_ADMIN_ROLE = 0x5f58e3a2316349923ce3780f8d587db2d72378aed66a8261c916544fa6846ca5
#PROPOSER_ROLE = 0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1
#CANCELLER_ROLE = 0xfd643c72710c63c0180259aba6b2d05451e3591a24e58b62239378085726f783
#EXECUTOR_ROLE = 0xd8aa0f3194971a2a116679f7c2090f6939c8d4e01a2a8d7e41d55e5351469e63

TIMELOCK_ADMIN_ROLE = 0x11
PROPOSER_ROLE = 0x22
CANCELLER_ROLE = 0x33
EXECUTOR_ROLE = 0x44

PROPOSERS = [111, 112, 113, 114]
EXECUTORS = [221, 222, 223, 224]


@pytest.fixture(scope="module")
async def contract_defs():
    account_def = get_contract_def("openzeppelin/account/Account.cairo")
    timelock_def = get_contract_def("openzeppelin/governance/timelock/Timelock3.cairo")
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

    # add accounts to proposers and executors arrays
    PROPOSERS.append(proposer.contract_address)
    EXECUTORS.append(executor.contract_address)

    timelock = await starknet.deploy(
        contract_def=timelock_def,
        constructor_calldata=[
            DAY_DELAY,                  # delay
            proposer.contract_address,  # deployer
            len(PROPOSERS),             # proposers length
            *PROPOSERS,                 # proposers array
            len(EXECUTORS),             # executors length
            *EXECUTORS                  # executors array
        ],
    )
    initializable = await starknet.deploy(
        contract_def=init_def,
    )

    return starknet.state, proposer, executor, timelock, initializable


@pytest.fixture(scope="module")
async def timelock_factory(contract_defs, timelock_init):
    account_def, timelock_def, init_def = contract_defs
    state, proposer, executor, timelock, initializable = timelock_init
    _state = state.copy()
    proposer = cached_contract(_state, account_def, proposer)
    executor = cached_contract(_state, account_def, executor)
    timelock = cached_contract(_state, timelock_def, timelock)
    initializable = cached_contract(_state, init_def, initializable)

    return proposer, executor, timelock, initializable, state


@pytest.mark.asyncio
@pytest.mark.parametrize('role, addresses, not_role', [
    [PROPOSER_ROLE, PROPOSERS, EXECUTOR_ROLE],
    [CANCELLER_ROLE, PROPOSERS, EXECUTOR_ROLE],
    [EXECUTOR_ROLE, EXECUTORS, PROPOSER_ROLE],
])
async def test_constructor_roles_arrays(timelock_factory, role, addresses, not_role):
    _, _, timelock, *_ = timelock_factory

    for i in range(len(addresses)):
        execution_info = await timelock.hasRole(role, addresses[i]).call()
        assert execution_info.result == (TRUE,)

        execution_info = await timelock.hasRole(not_role, addresses[i]).call()
        assert execution_info.result == (FALSE,)


@pytest.mark.asyncio
async def test_constructor(timelock_factory):
    proposer, _, timelock, *_ = timelock_factory

    execution_info = await timelock.getMinDelay().call()
    assert execution_info.result == (DAY_DELAY,)

    execution_info = await timelock.hasRole(TIMELOCK_ADMIN_ROLE, timelock.contract_address).call()
    assert execution_info.result == (TRUE,)

    execution_info = await timelock.hasRole(TIMELOCK_ADMIN_ROLE, proposer.contract_address).call()
    assert execution_info.result == (TRUE,)
