import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils import Signer, assert_revert, contract_path

signer = Signer(123456789987654321)

FALSE = 0
TRUE = 1

@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()

@pytest.fixture(scope='module')
async def enumerableset_mock():
    starknet = await Starknet.empty()
    enumerableset = await starknet.deploy(
        contract_path("tests/mock/enumerableset_mock.cairo")
    )

    return enumerableset


