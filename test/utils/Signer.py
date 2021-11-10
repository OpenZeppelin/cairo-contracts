"""
Signer
----------
A utility for sending signed transactions to an Account on Starknet.

"""


from starkware.crypto.signature.signature import pedersen_hash, private_to_stark_key, sign
from starkware.starknet.public.abi import get_selector_from_name


class Signer():
    """
    Utility for sending signed transactions to an Account on Starknet.

    Parameters
    ----------

    private_key : int

    Examples
    ---------
    Constructing a Singer object

    >>> my_txn_signer = Signer(1234)

    Sending a transaction

    >>> await signer.send_transaction(account, 
                                      account.contract_address, 
                                      'set_public_key', 
                                      [other.public_key]
                                     )


    """
    def __init__(self, private_key):
        self.private_key = private_key
        self.public_key = private_to_stark_key(private_key)

    def sign(self, message_hash):
        return sign(msg_hash=message_hash, priv_key=self.private_key)

    async def send_transaction(self, account, to, selector_name, calldata, nonce=None):
        if nonce is None:
            nonce, = await account.get_nonce().call()

        selector = get_selector_from_name(selector_name)
        message_hash = hash_message(
            account.contract_address, to, selector, calldata, nonce)
        sig_r, sig_s = self.sign(message_hash)

        return await account.execute(to, selector, calldata, [sig_r, sig_s]).invoke()


def hash_message(sender, to, selector, calldata, nonce):
    res = pedersen_hash(sender, to)
    res = pedersen_hash(res, selector)
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
