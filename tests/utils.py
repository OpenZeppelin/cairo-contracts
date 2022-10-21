"""Utilities for testing Cairo contracts."""

import os
from pathlib import Path
from starkware.starknet.public.abi import get_selector_from_name
from starkware.starknet.business_logic.execution.objects import OrderedEvent
from starkware.starknet.compiler.compile import compile_starknet_files
from starkware.starknet.testing.starknet import StarknetContract
from starkware.starknet.testing.starknet import Starknet

MAX_UINT256 = (2**128 - 1, 2**128 - 1)
INVALID_UINT256 = (MAX_UINT256[0] + 1, MAX_UINT256[1])
ZERO_ADDRESS = 0
TRUE = 1
FALSE = 0
IACCOUNT_ID = 0xa66bd575

_root = Path(__file__).parent.parent


def contract_path(name):
    if name.startswith("tests/"):
        return str(_root / name)
    else:
        return str(_root / "src" / name)


def assert_event_emitted(tx_exec_info, from_address, name, data, order=0):
    """Assert one single event is fired with correct data."""
    assert_events_emitted(tx_exec_info, [(order, from_address, name, data)])


def assert_events_emitted(tx_exec_info, events):
    """Assert events are fired with correct data."""
    for event in events:
        order, from_address, name, data = event
        event_obj = OrderedEvent(
            order=order,
            keys=[get_selector_from_name(name)],
            data=data,
        )

        base = tx_exec_info.call_info.internal_calls[0]
        if event_obj in base.events and from_address == base.contract_address:
            return

        try:
            base2 = base.internal_calls[0]
            if event_obj in base2.events and from_address == base2.contract_address:
                return
        except IndexError:
            pass

        raise BaseException("Event not fired or not fired correctly")


def _get_path_from_name(name):
    """Return the contract path by contract name."""
    dirs = ["src", "tests/mocks"]
    for dir in dirs:
        for (dirpath, _, filenames) in os.walk(dir):
            for file in filenames:
                if file == f"{name}.cairo":
                    return os.path.join(dirpath, file)

    raise FileNotFoundError(f"Cannot find '{name}'.")


def get_contract_class(contract, is_path=False):
    """Return the contract class from the contract name or path"""
    if is_path:
        path = contract_path(contract)
    else:
        path = _get_path_from_name(contract)

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
        deploy_call_info=deployed.deploy_call_info
    )
    return contract


class State:
    """
    Utility helper for Account class to initialize and return StarkNet state.

    Example
    ---------
    Initalize StarkNet state

    >>> starknet = await State.init()

    """
    async def init():
        global starknet
        starknet = await Starknet.empty()
        return starknet


class Account:
    """
    Utility for deploying Account contract.

    Parameters
    ----------

    public_key : int

    Examples
    ----------

    >>> starknet = await State.init()
    >>> account = await Account.deploy(public_key)

    """
    get_class = get_contract_class("Account")

    async def deploy(public_key):
        account = await starknet.deploy(
            contract_class=Account.get_class,
            constructor_calldata=[public_key]
        )
        return account
