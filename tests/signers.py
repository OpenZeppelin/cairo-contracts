from typing import Tuple
from starkware.starknet.core.os.transaction_hash.transaction_hash import TransactionHashPrefix
from starkware.starknet.core.os.contract_address.contract_address import (
    calculate_contract_address_from_hash,
)
from starkware.starknet.definitions.general_config import StarknetChainId
from starkware.starknet.services.api.gateway.transaction import InvokeFunction, DeployAccount
from starkware.starknet.business_logic.transaction.objects import InternalTransaction, InternalDeclare, TransactionExecutionInfo
from nile.signer import Signer, from_call_to_call_array, get_transaction_hash, TRANSACTION_VERSION
from nile.utils import to_uint
from utils import get_class_hash, get_contract_class
import eth_keys


class BaseSigner():
    async def send_transaction(self, account, to, selector_name, calldata, nonce=None, max_fee=0):
        return await self.send_transactions(account, [(to, selector_name, calldata)], nonce, max_fee)

    async def send_transactions(
        self,
        account,
        calls,
        nonce=None,
        max_fee=0
    ) -> TransactionExecutionInfo:
        raw_invocation = get_raw_invoke(account, calls)
        state = raw_invocation.state

        if nonce is None:
            nonce = await state.state.get_nonce_at(account.contract_address)

        transaction_hash = get_transaction_hash(
            prefix=TransactionHashPrefix.INVOKE,
            account=account.contract_address,
            calldata=raw_invocation.calldata,
            version=TRANSACTION_VERSION,
            chain_id=StarknetChainId.TESTNET.value,
            nonce=nonce,
            max_fee=max_fee,
        )

        signature = self.sign(transaction_hash)

        external_tx = InvokeFunction(
            contract_address=account.contract_address,
            calldata=raw_invocation.calldata,
            entry_point_selector=None,
            signature=signature,
            max_fee=max_fee,
            version=TRANSACTION_VERSION,
            nonce=nonce,
        )

        tx = InternalTransaction.from_external(
            external_tx=external_tx, general_config=state.general_config
        )
        execution_info = await state.execute_tx(tx=tx)
        return execution_info

    async def declare_class(
        self,
        account,
        contract_name,
        nonce=None,
        max_fee=0,
    ) -> Tuple[int, TransactionExecutionInfo]:
        state = account.state

        if nonce is None:
            nonce = await state.state.get_nonce_at(contract_address=account.contract_address)

        contract_class = get_contract_class(contract_name)
        class_hash = get_class_hash(contract_name)

        transaction_hash = get_transaction_hash(
            prefix=TransactionHashPrefix.DECLARE,
            account=account.contract_address,
            calldata=[class_hash],
            nonce=nonce,
            version=TRANSACTION_VERSION,
            max_fee=max_fee,
            chain_id=StarknetChainId.TESTNET.value
        )

        signature = self.sign(transaction_hash)

        tx = InternalDeclare.create(
            sender_address=account.contract_address,
            contract_class=contract_class,
            chain_id=StarknetChainId.TESTNET.value,
            max_fee=max_fee,
            version=TRANSACTION_VERSION,
            nonce=nonce,
            signature=signature,
        )

        execution_info = await state.execute_tx(tx=tx)

        await state.state.set_contract_class(
            class_hash=tx.class_hash,
            contract_class=contract_class
        )
        return class_hash, execution_info

    async def deploy_account(
        self,
        state,
        calldata,
        salt=0,
        nonce=0,
        max_fee=0,
    ) -> TransactionExecutionInfo:
        account_address = calculate_contract_address_from_hash(
            salt=salt,
            class_hash=self.class_hash,
            constructor_calldata=calldata,
            deployer_address=0
        )

        transaction_hash = get_transaction_hash(
            prefix=TransactionHashPrefix.DEPLOY_ACCOUNT,
            account=account_address,
            calldata=[self.class_hash, salt, *calldata],
            nonce=nonce,
            version=TRANSACTION_VERSION,
            max_fee=max_fee,
            chain_id=StarknetChainId.TESTNET.value
        )

        signature = self.sign(transaction_hash)

        external_tx = DeployAccount(
            class_hash=self.class_hash,
            contract_address_salt=salt,
            constructor_calldata=calldata,
            signature=signature,
            max_fee=max_fee,
            version=TRANSACTION_VERSION,
            nonce=nonce,
        )

        tx = InternalTransaction.from_external(
            external_tx=external_tx, general_config=state.general_config
        )

        execution_info = await state.execute_tx(tx=tx)
        return execution_info

class MockSigner(BaseSigner):
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

    >>> await signer.send_transactions(
            account, [
                (contract_address, 'contract_method', [arg_1]),
                (contract_address, 'another_method', [arg_1, arg_2])
            ]
        )

    """
    def __init__(self, private_key):
        self.signer = Signer(private_key)
        self.public_key = self.signer.public_key
        self.class_hash = get_class_hash("Account")

    def sign(self, transaction_hash):
        sig_r, sig_s = self.signer.sign(transaction_hash)
        return [sig_r, sig_s]


class MockEthSigner(BaseSigner):
    """
    Utility for sending signed transactions to an Account on Starknet, like MockSigner, but using a secp256k1 signature.
    Parameters
    ----------
    private_key : int

    """
    def __init__(self, private_key):
        self.signer = eth_keys.keys.PrivateKey(private_key)
        self.eth_address = int(self.signer.public_key.to_checksum_address(), 0)
        self.class_hash = get_class_hash("EthAccount")

    def sign(self, transaction_hash):
        signature = self.signer.sign_msg_hash(
            (transaction_hash).to_bytes(32, byteorder="big"))
        sig_r = to_uint(signature.r)
        sig_s = to_uint(signature.s)
        return [signature.v, *sig_r, *sig_s]


def get_raw_invoke(sender, calls):
    """Return raw invoke, remove when test framework supports `invoke`."""
    call_array, calldata = from_call_to_call_array(calls)
    raw_invocation = sender.__execute__(call_array, calldata)
    return raw_invocation
