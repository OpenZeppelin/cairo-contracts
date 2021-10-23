import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils.Signer import Signer

signer = Signer(123456789987654321)


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
async def ownable_factory():
    starknet = await Starknet.empty()
    owner = await starknet.deploy("contracts/Account.cairo")
    ownable = await starknet.deploy("contracts/Ownable.cairo")
    await owner.initialize(signer.public_key, owner.contract_address).invoke()
    await ownable.initialize_ownable(owner.contract_address).invoke()
    return starknet, ownable, owner


@pytest.mark.asyncio
async def test_initializer(ownable_factory):
    _, ownable, owner = ownable_factory
    assert await ownable.get_owner().call() == (owner.contract_address,)


@pytest.mark.asyncio
async def test_transfer_ownership(ownable_factory):
    _, ownable, owner = ownable_factory
    new_owner = 123
    await signer.send_transaction(owner, ownable.contract_address, 'transfer_ownership', [new_owner])
    assert await ownable.get_owner().call() == (new_owner,)
