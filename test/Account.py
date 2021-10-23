import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils.Signer import Signer

signer = Signer(123456789987654321)
other = Signer(987654321123456789)


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
async def account_factory():
    starknet = await Starknet.empty()
    account = await starknet.deploy("contracts/Account.cairo")
    await account.initialize(signer.public_key, account.contract_address).invoke()
    return starknet, account


@pytest.mark.asyncio
async def test_initializer(account_factory):
    _, account = account_factory
    assert await account.get_public_key().call() == (signer.public_key,)
    assert await account.get_address().call() == (account.contract_address,)


@pytest.mark.asyncio
async def test_execute(account_factory):
    starknet, account = account_factory
    initializable = await starknet.deploy("contracts/Initializable.cairo")

    assert await initializable.initialized().call() == (0,)
    await signer.send_transaction(account, initializable.contract_address, 'initialize', [])
    assert await initializable.initialized().call() == (1,)


@pytest.mark.asyncio
async def test_nonce(account_factory):
    starknet, account = account_factory
    initializable = await starknet.deploy("contracts/Initializable.cairo")
    current_nonce, = await account.get_nonce().call()

    # lower nonce
    try:
        await signer.send_transaction(account, initializable.contract_address, 'initialize', [], current_nonce - 1)
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

    # higher nonce
    try:
        await signer.send_transaction(account, initializable.contract_address, 'initialize', [], current_nonce + 1)
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

    # right nonce
    await signer.send_transaction(account, initializable.contract_address, 'initialize', [], current_nonce)
    assert await initializable.initialized().call() == (1,)


@pytest.mark.asyncio
async def test_public_key_setter(account_factory):
    _, account = account_factory
    assert await account.get_public_key().call() == (signer.public_key,)
    await signer.send_transaction(account, account.contract_address, 'set_public_key', [other.public_key])
    assert await account.get_public_key().call() == (other.public_key,)
