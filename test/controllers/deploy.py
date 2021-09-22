from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.compiler.compile import compile_starknet_files

async def deploy(starknet, path):
  contract_definition = compile_starknet_files([path], debug_info=True)
  contract_address = await starknet.deploy(contract_definition=contract_definition)

  contract = StarknetContract(
    starknet=starknet,
    abi=contract_definition.abi,
    contract_address=contract_address,
  )

  return (contract, contract_address)
