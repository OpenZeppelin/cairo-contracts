import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils.Signer import Signer

signer = Signer(123456789987654321)
other = Signer(987654321123456789)
L1_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984
ANOTHER_ADDRESS = 0xd9e1ce17f2641f24ae83637ab66a2cca9c378b9f


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

    transaction = await signer.build_transaction(
        account, initializable.contract_address, 'initialize', [])

    assert await initializable.initialized().call() == (0,)
    await transaction.invoke()
    assert await initializable.initialized().call() == (1,)


# @pytest.mark.asyncio
# async def test_nonce(account_factory):
#     starknet, account = account_factory
#     initializable = await starknet.deploy("contracts/Initializable.cairo")

#     await signer.build_transaction(
#         account, initializable.contract_address, 'initialize', []).invoke()

#     try:
#         await signer.build_transaction(
#             account, initializable.contract_address, 'initialize', []).invoke()
#     except:
#         assert 4 == 0


@pytest.mark.asyncio
async def test_L1_address_setter(account_factory):
    _, account = account_factory
    assert await account.get_L1_address().call() == (L1_ADDRESS,)

    tx = await signer.build_transaction(
        account, account.contract_address, 'set_L1_address', [ANOTHER_ADDRESS])
    await tx.invoke()

    assert await account.get_L1_address().call() == (ANOTHER_ADDRESS,)


@pytest.mark.asyncio
async def test_public_key_setter(account_factory):
    _, account = account_factory
    assert await account.get_public_key().call() == (signer.public_key,)

    tx = await signer.build_transaction(
        account, account.contract_address, 'set_public_key', [other.public_key])
    await tx.invoke()

    assert await account.get_public_key().call() == (other.public_key,)

    # tear down test. todo: cleanup on fixture directly
    tx = await other.build_transaction(
        account, account.contract_address, 'set_public_key', [signer.public_key])

    await tx.invoke()
