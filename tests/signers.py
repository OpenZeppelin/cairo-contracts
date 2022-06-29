from nile.signer import Signer, from_call_to_call_array, get_transaction_hash
from utils import to_uint
import eth_keys

class MockSigner():
    """
    Utility for sending signed transactions to an Account on Starknet.

    Parameters
    ----------

    private_key : int

    Examples
    ---------
    Constructing a MockSigner object

    >>> signer = MockSigner(1234)

    Sending a transaction

    >>> await signer.send_transaction(
            account, contract_address, 'contract_method', [arg_1]
        )

    Sending multiple transactions

    >>> await signer.send_transaction(
            account, [
                (contract_address, 'contract_method', [arg_1]),
                (contract_address, 'another_method', [arg_1, arg_2])
            ]
        )
                           
    """
    def __init__(self, private_key):
        self.signer = Signer(private_key)
        self.public_key = self.signer.public_key
        
    async def send_transaction(self, account, to, selector_name, calldata, nonce=None, max_fee=0):
        return await self.send_transactions(account, [(to, selector_name, calldata)], nonce, max_fee)

    async def send_transactions(self, account, calls, nonce=None, max_fee=0):
        if nonce is None:
            execution_info = await account.get_nonce().call()
            nonce, = execution_info.result

        build_calls = []
        for call in calls:
            build_call = list(call)
            build_call[0] = hex(build_call[0])
            build_calls.append(build_call)

        (call_array, calldata, sig_r, sig_s) = self.signer.sign_transaction(hex(account.contract_address), build_calls, nonce, max_fee)
        return await account.__execute__(call_array, calldata, nonce).invoke(signature=[sig_r, sig_s])

class MockEthSigner():
    """
    Utility for sending signed transactions to an Account on Starknet, like MockSigner, but using a secp256k1 signature.
    Parameters
    ----------
    private_key : int
                  
    """
    def __init__(self, private_key):
        self.signer = eth_keys.keys.PrivateKey(private_key)        
        self.eth_address = int(self.signer.public_key.to_checksum_address(),0)

    async def send_transaction(self, account, to, selector_name, calldata, nonce=None, max_fee=0):
        return await self.send_transactions(account, [(to, selector_name, calldata)], nonce, max_fee)

    async def send_transactions(self, account, calls, nonce=None, max_fee=0):
        if nonce is None:
            execution_info = await account.get_nonce().call()
            nonce, = execution_info.result

        build_calls = []
        for call in calls:
            build_call = list(call)
            build_call[0] = hex(build_call[0])
            build_calls.append(build_call)

        (call_array, calldata) = from_call_to_call_array(build_calls)
        message_hash = get_transaction_hash(
            account.contract_address, call_array, calldata, nonce, max_fee
        )
        
        signature = self.signer.sign_msg_hash((message_hash).to_bytes(32, byteorder="big"))        
        sig_r = to_uint(signature.r)
        sig_s = to_uint(signature.s)

        # the hash and signature are returned for other tests to use
        return await account.__execute__(call_array, calldata, nonce).invoke(
            signature=[signature.v, *sig_r, *sig_s]
        ), message_hash, [signature.v, *sig_r, *sig_s]
