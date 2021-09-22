import os
import pytest
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.compiler.compile import compile_starknet_files
from starkware.crypto.signature.signature import (pedersen_hash, private_to_stark_key, sign)
from starkware.starknet.public.abi import get_selector_from_name

privkey = 123456789987654321
pubkey = private_to_stark_key(privkey)
l1_address = int(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984)

@pytest.mark.asyncio
async def test_initializer():
  starknet = await Starknet.empty()
  account, account_address = await deploy(starknet, "contracts/Account.cairo")
  await account.initialize(pubkey, l1_address).invoke()

  assert await account.get_public_key().call() == (pubkey,)
  assert await account.get_L1_address().call() == (l1_address,)


@pytest.mark.asyncio
async def test_execute():
  starknet = await Starknet.empty()
  account, account_address = await deploy(starknet, "contracts/Account.cairo")
  initializable, initializable_address = await deploy(starknet, "contracts/Initializable.cairo")
  await account.initialize(pubkey, l1_address).invoke()

  to = initializable_address
  selector = get_selector_from_name('initialize')
  calldata = []
  nonce = 0
  message_hash = hash_message(to, selector, calldata, nonce)
  (sig_r, sig_s) = sign(msg_hash=message_hash, priv_key=privkey)
  execute_call = account.execute(to, selector, calldata, nonce, sig_r, sig_s)

  assert await initializable.initialized().call() == (0,)
  await execute_call.invoke()
  assert await initializable.initialized().call() == (1,)


async def deploy(starknet, path):
  contract_definition = compile_starknet_files([path], debug_info=True)
  contract_address = await starknet.deploy(contract_definition=contract_definition)

  contract = StarknetContract(
    starknet=starknet,
    abi=contract_definition.abi,
    contract_address=contract_address,
  )

  return (contract, contract_address)

def hash_message(to, selector, calldata, nonce):
  res = pedersen_hash(to, selector)
  res = hash_calldata(calldata)
  return pedersen_hash(res, nonce)

def hash_calldata(calldata):
  if len(calldata) == 0:
    return 0
  elif len(calldata) == 1:
    return calldata[0]
  else:
    return pedersen_hash(hash_calldata(calldata[1:]), calldata[0])
