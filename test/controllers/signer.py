from starkware.crypto.signature.signature import private_to_stark_key, sign

class Signer():
  def __init__(self, private_key):
    self._private_key = private_key
    self.public_key = private_to_stark_key(private_key)

  def sign(self, message_hash):
    return sign(msg_hash=message_hash, priv_key=self._private_key)
