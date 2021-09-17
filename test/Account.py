import os
import pytest
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.compiler.compile import compile_starknet_files

async def deploy(path):
  contract_definition = compile_starknet_files([path], debug_info=True)
  starknet = await Starknet.empty()
  contract_address = await starknet.deploy(contract_definition=contract_definition)

  return StarknetContract(
    starknet=starknet,
    abi=contract_definition.abi,
    contract_address=contract_address,
  )

@pytest.mark.asyncio
async def test_initializer():
  account = await deploy("contracts/Account.cairo")
  pubkey = int(1628448741648245036800002906075225705100596136133912895015035902954123957052)
  l1_address = int(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984)
  await account.initialize(pubkey, l1_address).invoke()

  assert await account.get_public_key().call() == (pubkey,)
  assert await account.get_L1_address().call() == (l1_address,)
