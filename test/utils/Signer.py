from starkware.crypto.signature.signature import pedersen_hash, private_to_stark_key, sign
from starkware.starknet.public.abi import get_selector_from_name


class Signer():
    def __init__(self, private_key):
        self.private_key = private_key
        self.public_key = private_to_stark_key(private_key)

    def sign(self, message_hash):
        return sign(msg_hash=message_hash, priv_key=self.private_key)

    def build_transaction(self, account, to, selector_name, calldata, nonce):
        selector = get_selector_from_name(selector_name)
        message_hash = hash_message(
            to, selector, calldata, account.contract_address, nonce)
        (sig_r, sig_s) = self.sign(message_hash)
        return account.execute(to, selector, calldata, account.contract_address, nonce, sig_r, sig_s)


def hash_message(to, selector, calldata, account_address, nonce):
    res = pedersen_hash(to, selector)
    res_calldata = hash_calldata(calldata)
    res = pedersen_hash(res, res_calldata)
    res = pedersen_hash(res, account_address)
    return pedersen_hash(res, nonce)


def hash_calldata(calldata):
    if len(calldata) == 0:
        return 0
    elif len(calldata) == 1:
        return calldata[0]
    else:
        return pedersen_hash(hash_calldata(calldata[1:]), calldata[0])
