import os
import pytest, asyncio
from starkware.starknet.testing.starknet import Starknet
from controllers.Account import Account
from controllers.Signer import Signer
from controllers.deploy import deploy

signer = Signer(123456789987654321)
L1_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984

@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()

@pytest.fixture(scope='module')
async def ownable_factory():
  starknet = await Starknet.empty()
  owner = Account(starknet, signer, L1_ADDRESS)
  await owner.initialize()
  ownable = await deploy(starknet, "contracts/Ownable.cairo")
  await ownable.initialize_ownable(owner.address).invoke()
  return starknet, ownable, owner

@pytest.mark.asyncio
async def test_initializer(ownable_factory):
  starknet, ownable, owner = ownable_factory
  assert await ownable.get_owner().call() == (owner.address,)

@pytest.mark.asyncio
async def test_transfer_ownership(ownable_factory):
  starknet, ownable, owner = ownable_factory
  new_owner = 123
  transfer_ownership = owner.build_transaction(ownable.contract_address, 'transfer_ownership', [new_owner], 0)
  await transfer_ownership.invoke()
  assert await ownable.get_owner().call() == (new_owner,)
