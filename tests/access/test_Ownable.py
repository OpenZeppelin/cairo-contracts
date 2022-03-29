import pytest
from pathlib import Path
from starkware.starknet.testing.starknet import Starknet
from utils import (
    Signer, ZERO_ADDRESS,
    assert_event_emitted,
    get_contract_def, cached_contract
)


signer = Signer(123456789987654321)


@pytest.fixture(scope='module')
def contract_defs():
    return {
        Path(key).stem: get_contract_def(key)
        for key in [
            'openzeppelin/account/Account.cairo',
            'tests/mocks/Ownable.cairo',
        ]
    }


@pytest.fixture(scope='module')
async def ownable_init(contract_defs):
    starknet = await Starknet.empty()
    owner = await starknet.deploy(
        contract_def=contract_defs['Account'],
        constructor_calldata=[signer.public_key]
    )
    ownable = await starknet.deploy(
        contract_def=contract_defs['Ownable'],
        constructor_calldata=[owner.contract_address]
    )
    return starknet.state, ownable, owner


@pytest.fixture
def ownable_factory(contract_defs, ownable_init):
    state, ownable, owner = ownable_init
    _state  = state.copy()
    ownable = cached_contract(_state, contract_defs['Ownable'], ownable)
    owner   = cached_contract(_state, contract_defs['Account'], owner)
    return ownable, owner


@pytest.mark.asyncio
async def test_constructor(ownable_factory):
    ownable, owner = ownable_factory
    expected = await ownable.owner().call()
    assert expected.result.owner == owner.contract_address


@pytest.mark.asyncio
async def test_transferOwnership(ownable_factory):
    ownable, owner = ownable_factory
    newOwner = 123
    await signer.send_transaction(owner, ownable.contract_address, 'transferOwnership', [newOwner])
    executed_info = await ownable.owner().call()
    assert executed_info.result == (newOwner,)


@pytest.mark.asyncio
async def test_transferOwnership_emits_event(ownable_factory):
    ownable, owner = ownable_factory
    newOwner = 123
    tx_exec_info = await signer.send_transaction(owner, ownable.contract_address, 'transferOwnership', [newOwner])

    assert_event_emitted(
        tx_exec_info,
        from_address=ownable.contract_address,
        name='OwnershipTransferred',
        data=[
            owner.contract_address,
            newOwner
        ]
    )


@pytest.mark.asyncio
async def test_renounceOwnership(ownable_factory):
    ownable, owner = ownable_factory
    await signer.send_transaction(owner, ownable.contract_address, 'renounceOwnership', [])
    executed_info = await ownable.owner().call()
    assert executed_info.result == (ZERO_ADDRESS,)


@pytest.mark.asyncio
async def test_renounceOwnership_emits_event(ownable_factory):
    ownable, owner = ownable_factory
    tx_exec_info = await signer.send_transaction(owner, ownable.contract_address, 'renounceOwnership', [])

    assert_event_emitted(
        tx_exec_info,
        from_address=ownable.contract_address,
        name='OwnershipTransferred',
        data=[
            owner.contract_address,
            ZERO_ADDRESS
        ]
    )