from nile.signer import Signer

class SignerWithAccount():
    """
    Utility for sending signed transactions to an Account on Starknet.

    Parameters
    ----------

    private_key : int

    Examples
    ---------
    Constructing a SignerWithAccount object

    >>> signer = SignerWithAccount(1234)

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

        (call_array, calldata, sig_r, sig_s) = self.signer.sign_transaction(account.contract_address, calls, nonce, max_fee)
        return await account.__execute__(call_array, calldata, nonce).invoke(signature=[sig_r, sig_s])
