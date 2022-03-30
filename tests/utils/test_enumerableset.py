import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils import Signer, contract_path

signer = Signer(123456789987654321)

FALSE = 0
TRUE = 1

@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()

@pytest.fixture(scope='module')
async def enumerableset_mock():
    starknet = await Starknet.empty()

    account = await starknet.deploy(
        contract_path("openzeppelin/account/Account.cairo"),
        constructor_calldata=[signer.public_key]
    )

    enumerableset = await starknet.deploy(
        contract_path("tests/mocks/enumerableset_mock.cairo")
    )

    return account, enumerableset


@pytest.mark.asyncio
async def test_add(enumerableset_mock):
    account, enumerableset = enumerableset_mock
    await signer.send_transaction(account, enumerableset.contract_address, 'add', [0, 1])
    executed_info = await enumerableset.contains(0, 1).call()
    assert executed_info.result == (TRUE,)


@pytest.mark.asyncio
async def test_remove(enumerableset_mock):
    account, enumerableset = enumerableset_mock
    await signer.send_transaction(account, enumerableset.contract_address, 'remove', [0, 1])
    executed_info = await enumerableset.contains(0, 1).call()
    assert executed_info.result == (FALSE,)


@pytest.mark.asyncio
async def test_dupe_add(enumerableset_mock):
    account, enumerableset = enumerableset_mock
    await signer.send_transaction(account, enumerableset.contract_address, 'add', [0, 1])
    await signer.send_transaction(account, enumerableset.contract_address, 'add', [0, 1])
    executed_info = await enumerableset.contains(0, 1).call()
    assert executed_info.result == (TRUE,)
    executed_info = await enumerableset.length(0).call()
    assert executed_info.result == (1,)

@pytest.mark.asyncio
async def test_multi_add(enumerableset_mock):
    account, enumerableset = enumerableset_mock
    await signer.send_transaction(account, enumerableset.contract_address, 'add', [0, 1])
    await signer.send_transaction(account, enumerableset.contract_address, 'add', [0, 3])
    await signer.send_transaction(account, enumerableset.contract_address, 'add', [0, 2])    
    executed_info = await enumerableset.contains(0, 3).call()
    assert executed_info.result == (TRUE,)
    executed_info = await enumerableset.contains(0, 2).call()
    assert executed_info.result == (TRUE,)
    executed_info = await enumerableset.contains(0, 1).call()
    assert executed_info.result == (TRUE,)
    executed_info = await enumerableset.length(0).call()
    assert executed_info.result == (3,)

@pytest.mark.asyncio
async def test_add_three_remove_one(enumerableset_mock):
    account, enumerableset = enumerableset_mock
    await signer.send_transaction(account, enumerableset.contract_address, 'add', [0, 1])
    await signer.send_transaction(account, enumerableset.contract_address, 'add', [0, 3])
    await signer.send_transaction(account, enumerableset.contract_address, 'add', [0, 2])
    await signer.send_transaction(account, enumerableset.contract_address, 'remove', [0, 3])    
    executed_info = await enumerableset.contains(0, 3).call()
    assert executed_info.result == (FALSE,)
    executed_info = await enumerableset.contains(0, 2).call()
    assert executed_info.result == (TRUE,)
    executed_info = await enumerableset.contains(0, 1).call()
    assert executed_info.result == (TRUE,)
    executed_info = await enumerableset.length(0).call()
    assert executed_info.result == (2,)
