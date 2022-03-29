import pytest
from starkware.starknet.testing.starknet import Starknet
from utils import (
    Signer, ZERO_ADDRESS,
    assert_event_emitted,
    contract_path
)


signer = Signer(123456789987654321)


@pytest.fixture(scope='module')
async def ownable_factory():
    starknet = await Starknet.empty()
    owner = await starknet.deploy(
        contract_path("openzeppelin/account/Account.cairo"),
        constructor_calldata=[signer.public_key]
    )

    ownable = await starknet.deploy(
        contract_path("tests/mocks/Ownable.cairo"),
        constructor_calldata=[owner.contract_address]
    )
    return starknet, ownable, owner


@pytest.mark.asyncio
async def test_constructor(ownable_factory):
    _, ownable, owner = ownable_factory
    expected = await ownable.owner().call()
    assert expected.result.owner == owner.contract_address


@pytest.mark.asyncio
async def test_transferOwnership(ownable_factory):
    _, ownable, owner = ownable_factory
    newOwner = 123
    await signer.send_transaction(owner, ownable.contract_address, 'transferOwnership', [newOwner])
    executed_info = await ownable.owner().call()
    assert executed_info.result == (newOwner,)


@pytest.mark.asyncio
async def test_transferOwnership_emits_event(ownable_factory):
    _, ownable, owner = ownable_factory
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
    _, ownable, owner = ownable_factory
    await signer.send_transaction(owner, ownable.contract_address, 'renounceOwnership', [])
    executed_info = await ownable.owner().call()
    assert executed_info.result == (ZERO_ADDRESS,)


@pytest.mark.asyncio
async def test_renounceOwnership_emits_event(ownable_factory):
    _, ownable, owner = ownable_factory
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