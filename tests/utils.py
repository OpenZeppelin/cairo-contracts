"""Utilities for testing Cairo contracts."""

from pathlib import Path
import math
from starkware.starknet.public.abi import get_selector_from_name
from starkware.starknet.compiler.compile import compile_starknet_files
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.testing.starknet import StarknetContract
from starkware.starknet.business_logic.execution.objects import Event
from starkware.starknet.business_logic.state.state import BlockInfo
from starkware.cairo.common.hash_state import compute_hash_on_elements


MAX_UINT256 = (2**128 - 1, 2**128 - 1)
INVALID_UINT256 = (MAX_UINT256[0] + 1, MAX_UINT256[1])
ZERO_ADDRESS = 0
TRUE = 1
FALSE = 0

TRANSACTION_VERSION = 0


_root = Path(__file__).parent.parent


def contract_path(name):
    if name.startswith("tests/"):
        return str(_root / name)
    else:
        return str(_root / "src" / name)


def str_to_felt(text):
    b_text = bytes(text, "ascii")
    return int.from_bytes(b_text, "big")


def felt_to_str(felt):
    b_felt = felt.to_bytes(31, "big")
    return b_felt.decode()


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


async def assert_revert_entry_point(fun, invalid_selector):
    selector_hex = hex(get_selector_from_name(invalid_selector))
    entry_point_msg = f"Entry point {selector_hex} not found in contract"
    
    await assert_revert(fun, entry_point_msg)


def assert_event_emitted(tx_exec_info, from_address, name, data):
    assert Event(
        from_address=from_address,
        keys=[get_selector_from_name(name)],
        data=data,
    ) in tx_exec_info.raw_events


def get_contract_class(path):
    """Return the contract class from the contract path"""
    path = contract_path(path)
    contract_class = compile_starknet_files(
        files=[path],
        debug_info=True
    )
    return contract_class


def cached_contract(state, _class, deployed):
    """Return the cached contract"""
    contract = StarknetContract(
        state=state,
        abi=_class.abi,
        contract_address=deployed.contract_address,
        deploy_execution_info=deployed.deploy_execution_info
    )
    return contract

def get_block_timestamp(starknet_state):
    """Return the block timestamp."""
    return starknet_state.state.block_info.block_timestamp


def set_block_timestamp(starknet_state, timestamp):
    """Set the block timestamp."""
    starknet_state.state.block_info = BlockInfo(
        starknet_state.state.block_info.block_number,   # block number
        timestamp,                                      # new timestamp
        2000,                                           # gas price
        123                                             # sequencer address
    )


def from_call_to_call_array(calls):
    """Return calls and calldata arrays."""
    call_array = []
    calldata = []
    for call in calls:
        assert len(call) == 3, "Invalid call parameters"
        entry = (
            call[0],                                # to
            get_selector_from_name(call[1]),        # selector
            len(calldata),                          # calldata length
            len(call[2])                            # calldata
        )
        call_array.append(entry)
        calldata.extend(call[2])
    return (call_array, calldata)


def flatten_calls(calls):
    """Format calls for signer invoke."""
    calls_len = len(calls[0])
    flatten_calls = [e for call in calls[0] for e in call]
    flatten_calldata = [e for e in calls[-1]]
    
    return [
        calls_len,                      # calls length
        *flatten_calls,                 # flattened calls
        len(flatten_calldata),          # calldata length
        *flatten_calldata               # flattened calldata
    ]


def timelock_hash_chain(calls, predecessor, salt):
    """Return the hash id for timelock hash operations."""
    calldata_len = 0
    hashed_calls = []
    for call in calls:
        calldata_len = calldata_len + len(call[2])
        hashed_calls.append(
            compute_hash_on_elements([
                call[0],                            # to
                get_selector_from_name(call[1]),    # selector
                compute_hash_on_elements(call[2])   # calldata
            ])
        )
    return compute_hash_on_elements([*hashed_calls, calldata_len, predecessor, salt])
