import pytest
from starkware.starknet.testing.starknet import Starknet
from utils import (
    MockSigner,
    ZERO_ADDRESS,
    assert_event_emitted,
    get_contract_def,
    cached_contract
)


signer = MockSigner(123456789987654321)


@pytest.fixture(scope='module')
def contract_defs():
    return (
        get_contract_def('openzeppelin/account/Account.cairo'),
        get_contract_def('tests/mocks/Ownable.cairo')
    )


@pytest.fixture(scope='module')
async def ownable_init(contract_defs):
    account_def, ownable_def = contract_defs
    starknet = await Starknet.empty()
    owner = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )
    ownable = await starknet.deploy(
        contract_def=ownable_def,
        constructor_calldata=[owner.contract_address]
    )
    return starknet.state, ownable, owner


@pytest.fixture
def ownable_factory(contract_defs, ownable_init):
    account_def, ownable_def = contract_defs
    state, ownable, owner = ownable_init
    _state = state.copy()
    owner = cached_contract(_state, account_def, owner)
    ownable = cached_contract(_state, ownable_def, ownable)
    return ownable, owner


@pytest.mark.asyncio
async def test_constructor(ownable_factory):
    ownable, owner = ownable_factory
    expected = await ownable.owner().call()
    assert expected.result.owner == owner.contract_address


@pytest.mark.asyncio
async def test_transferOwnership(ownable_factory):
    ownable, owner = ownable_factory
    new_owner = 123
    await signer.send_transaction(owner, ownable.contract_address, 'transferOwnership', [new_owner])
    executed_info = await ownable.owner().call()
    assert executed_info.result == (new_owner,)


@pytest.mark.asyncio
async def test_transferOwnership_emits_event(ownable_factory):
    ownable, owner = ownable_factory
    new_owner = 123
    tx_exec_info = await signer.send_transaction(owner, ownable.contract_address, 'transferOwnership', [new_owner])

    assert_event_emitted(
        tx_exec_info,
        from_address=ownable.contract_address,
        name='OwnershipTransferred',
        data=[
            owner.contract_address,
            new_owner
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
