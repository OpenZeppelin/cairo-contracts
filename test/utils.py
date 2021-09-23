from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.compiler.compile import compile_starknet_files
from starkware.crypto.signature.signature import pedersen_hash, private_to_stark_key, sign
from starkware.starknet.public.abi import get_selector_from_name

class Signer():
  def __init__(self, private_key):
    self._private_key = private_key
    self.public_key = private_to_stark_key(private_key)

  def sign(self, message_hash):
    return sign(msg_hash=message_hash, priv_key=self._private_key)


async def deploy(starknet, path):
  contract_definition = compile_starknet_files([path], debug_info=True)
  contract_address = await starknet.deploy(contract_definition=contract_definition)

  return StarknetContract(
    starknet=starknet,
    abi=contract_definition.abi,
    contract_address=contract_address,
  )


def build_transaction(signer, account, to, _selector, calldata, nonce):
  selector = get_selector_from_name(_selector)
  message_hash = hash_message(to, selector, calldata, nonce)
  (sig_r, sig_s) = signer.sign(message_hash)
  return account.execute(to, selector, calldata, nonce, sig_r, sig_s)

def hash_message(to, selector, calldata, nonce):
  res = pedersen_hash(to, selector)
  res_calldata = hash_calldata(calldata)
  res = pedersen_hash(res, res_calldata)
  return pedersen_hash(res, nonce)

def hash_calldata(calldata):
  if len(calldata) == 0:
    return 0
  elif len(calldata) == 1:
    return calldata[0]
  else:
    return pedersen_hash(hash_calldata(calldata[1:]), calldata[0])
