import os
import pytest, asyncio
from starkware.starknet.testing.starknet import Starknet
from utils import Signer, deploy, build_transaction

signer = Signer(123456789987654321)
L1_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984

@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()

@pytest.fixture(scope='module')
async def ownable_factory():
  starknet = await Starknet.empty()

  owner_deployment = await deploy(starknet, "contracts/Account.cairo")
  (owner, owner_address) = owner_deployment
  await owner.initialize(signer.public_key, L1_ADDRESS).invoke()

  ownable_deployment = await deploy(starknet, "contracts/Ownable.cairo")
  (ownable, _) = ownable_deployment
  await ownable.initialize_ownable(owner_address).invoke()

  return starknet, ownable_deployment, owner_deployment


@pytest.mark.asyncio
async def test_initializer(ownable_factory):
  (starknet, ownable_deployment, owner_deployment) = ownable_factory
  (ownable, _) = ownable_deployment
  (_, owner_address) = owner_deployment
  assert await ownable.get_owner().call() == (owner_address,)


@pytest.mark.asyncio
async def test_transfer_ownership(ownable_factory):
  (starknet, ownable_deployment, owner_deployment) = ownable_factory
  (ownable, ownable_address) = ownable_deployment
  (owner, _) = owner_deployment
  new_owner = 123
  transfer_ownership = build_transaction(signer, owner, ownable_address, 'transfer_ownership', [new_owner], 0)
  await transfer_ownership.invoke()
  assert await ownable.get_owner().call() == (new_owner,)
