from starkware.crypto.signature.signature import pedersen_hash
from starkware.starknet.public.abi import get_selector_from_name
from controllers.deploy import deploy

class Account():
  def __init__(self, starknet, signer, L1_ADDRESS):
    self._nonce = 0
    self._signer = signer
    self._starknet = starknet
    self._L1_ADDRESS = L1_ADDRESS
    self._initialized = False

  async def initialize(self):
    self._contract = await deploy(self._starknet, 'contracts/Account.cairo')
    self.address = self._contract.contract_address
    await self._contract.initialize(self._signer.public_key, self._L1_ADDRESS).invoke()
    self._initialized = True

  def build_transaction(self, to, selector_name, calldata, nonce):
    if not self._initialized:
      raise "Initialize account"

    selector = get_selector_from_name(selector_name)
    message_hash = hash_message(to, selector, calldata, nonce)
    (sig_r, sig_s) = self._signer.sign(message_hash)
    return self._contract.execute(to, selector, calldata, nonce, sig_r, sig_s)

  async def send_transaction(self, to, selector_name, calldata):
    tx = self.build_transaction(to, selector_name, calldata, self._nonce)
    self._nonce += 1
    await tx.invoke()

  def call(self, method):
    return getattr(self._contract, method)().call()


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
