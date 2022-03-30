import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils import Signer, assert_revert, contract_path

signer = Signer(123456789987654321)

TRUE = 1
FALSE = 0


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
async def enumerablemap_mock():
    starknet = await Starknet.empty()

    account = await starknet.deploy(
        contract_path("openzeppelin/account/Account.cairo"),
        constructor_calldata=[signer.public_key]
    )

    enumerablemap = await starknet.deploy(
        contract_path("tests/mocks/enumerablemap_mock.cairo")
    )

    return account, enumerablemap


@pytest.mark.asyncio
async def test_set(enumerablemap_mock):
    account, enumerablemap = enumerablemap_mock
    await signer.send_transaction(account, enumerablemap.contract_address, 'set', [0, 6, 8])
    executed_info = await enumerablemap.contains(0, 6).call()
    assert executed_info.result == (TRUE,)


@pytest.mark.asyncio
async def test_remove(enumerablemap_mock):
    account, enumerablemap = enumerablemap_mock
    await signer.send_transaction(account, enumerablemap.contract_address, 'remove', [0, 6])
    executed_info = await enumerablemap.contains(0, 6).call()
    assert executed_info.result == (FALSE,)


@pytest.mark.asyncio
async def test_update(enumerablemap_mock):
    account, enumerablemap = enumerablemap_mock
    await signer.send_transaction(account, enumerablemap.contract_address, 'set', [0, 6, 8])
    executed_info = await enumerablemap.get(0, 6).call()
    assert executed_info.result == (TRUE, 8,)
    await signer.send_transaction(account, enumerablemap.contract_address, 'set', [0, 6, 19])
    executed_info = await enumerablemap.get(0, 6).call()
    assert executed_info.result == (TRUE, 19,)
    executed_info = await enumerablemap.length(0).call()
    assert executed_info.result == (1,)


@pytest.mark.asyncio
async def test_two_sets(enumerablemap_mock):
    account, enumerablemap = enumerablemap_mock
    await signer.send_transaction(account, enumerablemap.contract_address, 'set', [0, 6, 8])
    await signer.send_transaction(account, enumerablemap.contract_address, 'set', [0, 8, 19])
    executed_info = await enumerablemap.get(0, 6).call()
    assert executed_info.result == (TRUE, 8,)
    executed_info = await enumerablemap.get(0, 8).call()
    assert executed_info.result == (TRUE, 19,)
    executed_info = await enumerablemap.length(0).call()
    assert executed_info.result == (2,)


@pytest.mark.asyncio
async def test_get(enumerablemap_mock):
    account, enumerablemap = enumerablemap_mock
    
    try:
        executed_info = await enumerablemap.get(0, 1).call()
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

    await signer.send_transaction(account, enumerablemap.contract_address, 'set', [0, 1, 3])
    executed_info = await enumerablemap.get(0, 1).call()
    assert executed_info.result == (TRUE,3,)


@pytest.mark.asyncio
async def test_try_get(enumerablemap_mock):
    account, enumerablemap = enumerablemap_mock
    executed_info = await enumerablemap.try_get(0, 11).call()
    assert executed_info.result == (FALSE,0,)
    await signer.send_transaction(account, enumerablemap.contract_address, 'set', [0, 11, 19])
    executed_info = await enumerablemap.try_get(0, 11).call()
    assert executed_info.result == (TRUE,19,)
