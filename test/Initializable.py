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
  initializable = await deploy("contracts/Initializable.cairo")
  assert await initializable.initialized().call() == (0,)
  await initializable.initialize().invoke()
  assert await initializable.initialized().call() == (1,)
