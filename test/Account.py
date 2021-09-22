import os
import pytest, asyncio
from starkware.starknet.testing.starknet import Starknet
from controllers import signer, deploy, Account

my_signer = signer.Signer(123456789987654321)
L1_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984

@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()

@pytest.fixture(scope='module')
async def account_factory():
  starknet = await Starknet.empty()
  account = Account.Account(starknet, my_signer, L1_ADDRESS)
  await account.initialize()
  return starknet, account


@pytest.mark.asyncio
async def test_initializer(account_factory):
  (_, account) = account_factory
  assert await account.call('get_public_key') == (my_signer.public_key,)
  assert await account.call('get_L1_address') == (L1_ADDRESS,)


@pytest.mark.asyncio
async def test_execute(account_factory):
  (starknet, account) = account_factory
  initializable, initializable_address = await deploy.deploy(starknet, "contracts/Initializable.cairo")

  assert await initializable.initialized().call() == (0,)
  await account.send_transaction(initializable_address, 'initialize', [])
  assert await initializable.initialized().call() == (1,)
