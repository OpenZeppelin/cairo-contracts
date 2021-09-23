import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils.Signer import Signer
from utils.deploy import deploy

signer = Signer(123456789987654321)
L1_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
async def ownable_factory():
    starknet = await Starknet.empty()
    owner = await deploy(starknet, "contracts/Account.cairo")
    ownable = await deploy(starknet, "contracts/Ownable.cairo")
    await owner.initialize(signer.public_key, L1_ADDRESS).invoke()
    await ownable.initialize_ownable(owner.contract_address).invoke()
    return starknet, ownable, owner


@pytest.mark.asyncio
async def test_initializer(ownable_factory):
    starknet, ownable, owner = ownable_factory
    assert await ownable.get_owner().call() == (owner.contract_address,)


@pytest.mark.asyncio
async def test_transfer_ownership(ownable_factory):
    _, ownable, owner = ownable_factory
    new_owner = 123
    transfer_ownership = signer.build_transaction(
        owner, ownable.contract_address, 'transfer_ownership', [new_owner], 0)
    await transfer_ownership.invoke()
    assert await ownable.get_owner().call() == (new_owner,)
