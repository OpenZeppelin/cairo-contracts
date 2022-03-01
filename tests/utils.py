"""Utilities for testing Cairo contracts."""

import math
from starkware.cairo.common.hash_state import compute_hash_on_elements
from starkware.crypto.signature.signature import private_to_stark_key, sign
from starkware.starknet.public.abi import get_selector_from_name
from starkware.starknet.compiler.compile import compile_starknet_files
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.testing.starknet import StarknetContract
from starkware.starknet.business_logic.transaction_execution_objects import Event


MAX_UINT256 = (2**128 - 1, 2**128 - 1)
ZERO_ADDRESS = 0
TRUE = 1
FALSE = 0

TRANSACTION_VERSION = 0


def str_to_felt(text):
    b_text = bytes(text, "ascii")
    return int.from_bytes(b_text, "big")


def felt_to_str(felt):
    b_felt = felt.to_bytes(31, "big")
    return b_felt.decode()


def assert_event_emitted(tx_exec_info, from_address, name, data):
    assert Event(
        from_address=from_address,
        keys=[get_selector_from_name(name)],
        data=data,
    ) in tx_exec_info.raw_events


def uint(a):
    return(a, 0)


def to_uint(a):
    """Takes in value, returns uint256-ish tuple."""
    return (a & ((1 << 128) - 1), a >> 128)


def from_uint(uint):
    """Takes in uint256-ish tuple, returns value."""
    return uint[0] + (uint[1] << 128)


def add_uint(a, b):
    """Returns the sum of two uint256-ish tuples."""
    a = from_uint(a)
    b = from_uint(b)
    c = a + b
    return to_uint(c)


def sub_uint(a, b):
    """Returns the difference of two uint256-ish tuples."""
    a = from_uint(a)
    b = from_uint(b)
    c = a - b
    return to_uint(c)


def mul_uint(a, b):
    """Returns the product of two uint256-ish tuples."""
    a = from_uint(a)
    b = from_uint(b)
    c = a * b
    return to_uint(c)


def div_rem_uint(a, b):
    """Returns the quotient and remainder of two uint256-ish tuples."""
    a = from_uint(a)
    b = from_uint(b)
    c = math.trunc(a / b)
    m = a % b
    return (to_uint(c), to_uint(m))


async def assert_revert(fun, reverted_with=None):
    try:
        await fun
        assert False
    except StarkException as err:
        _, error = err.args
        if reverted_with is not None:
            assert reverted_with in error['message']


def assert_event_emitted(tx_exec_info, from_address, name, data):
    assert Event(
        from_address=from_address,
        keys=[get_selector_from_name(name)],
        data=data,
    ) in tx_exec_info.raw_events


def get_contract_def(path):
    """Returns the contract definition from the contract path"""
    contract_def = compile_starknet_files(
        files=[path],
        debug_info=True
    )
    return contract_def


def cached_contract(state, definition, deployed):
    """Returns the cached contract"""
    contract = StarknetContract(
        state=state,
        abi=definition.abi,
        contract_address=deployed.contract_address,
        deploy_execution_info=deployed.deploy_execution_info
    )
    return contract


class Signer():
    """
    Utility for sending signed transactions to an Account on Starknet.

    Parameters
    ----------

    private_key : int

    Examples
    ---------
    Constructing a Signer object

    >>> signer = Signer(1234)

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

    async def send_transaction(self, account, to, selector_name, calldata, nonce=None, max_fee=0):
        return await self.send_transactions(account, [(to, selector_name, calldata)], nonce, max_fee)

    async def send_transactions(self, account, calls, nonce=None, max_fee=0):
        if nonce is None:
            execution_info = await account.get_nonce().call()
            nonce, = execution_info.result

        calls_with_selector = [
            (call[0], get_selector_from_name(call[1]), call[2]) for call in calls]
        (call_array, calldata) = from_call_to_call_array(calls)

        message_hash = hash_multicall(
            account.contract_address, calls_with_selector, nonce, max_fee)
        sig_r, sig_s = self.sign(message_hash)

        return await account.__execute__(call_array, calldata, nonce).invoke(signature=[sig_r, sig_s])


def from_call_to_call_array(calls):
    call_array = []
    calldata = []
    for i, call in enumerate(calls):
        assert len(call) == 3, "Invalid call parameters"
        entry = (call[0], get_selector_from_name(
            call[1]), len(calldata), len(call[2]))
        call_array.append(entry)
        calldata.extend(call[2])
    return (call_array, calldata)


def hash_multicall(sender, calls, nonce, max_fee):
    hash_array = []
    for call in calls:
        call_elements = [call[0], call[1], compute_hash_on_elements(call[2])]
        hash_array.append(compute_hash_on_elements(call_elements))

    message = [
        str_to_felt('StarkNet Transaction'),
        sender,
        compute_hash_on_elements(hash_array),
        nonce,
        max_fee,
        TRANSACTION_VERSION
    ]
    return compute_hash_on_elements(message)
