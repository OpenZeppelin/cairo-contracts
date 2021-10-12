import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils.Signer import Signer

signer = Signer(123456789987654321)
L1_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
async def account_factory():
    starknet = await Starknet.empty()
    account = await starknet.deploy("contracts/Account.cairo")
    await account.initialize(signer.public_key, account.contract_address, L1_ADDRESS).invoke()
    return starknet, account


@pytest.mark.asyncio
async def test_initializer(account_factory):
    _, account = account_factory
    assert await account.get_public_key().call() == (signer.public_key,)
    assert await account.get_address().call() == (account.contract_address,)
    assert await account.get_L1_address().call() == (L1_ADDRESS,)


@pytest.mark.asyncio
async def test_execute(account_factory):
    starknet, account = account_factory
    initializable = await starknet.deploy("contracts/Initializable.cairo")

    transaction = signer.build_transaction(
        account, initializable.contract_address, 'initialize', [], 0)

    assert await initializable.initialized().call() == (0,)
    await transaction.invoke()
    assert await initializable.initialized().call() == (1,)
