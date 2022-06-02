import pytest
from starkware.starknet.testing.starknet import Starknet
from utils import (
    TestSigner,
    ZERO_ADDRESS,
    assert_event_emitted,
    get_contract_def,
    cached_contract
)


signer = TestSigner(123456789987654321)
second_signer = TestSigner(98765432123456789)

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
    proposed_owner = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[second_signer.public_key]
    )
    ownable = await starknet.deploy(
        contract_def=ownable_def,
        constructor_calldata=[owner.contract_address]
    )
    return starknet.state, ownable, owner, proposed_owner


@pytest.fixture
def ownable_factory(contract_defs, ownable_init):
    account_def, ownable_def = contract_defs
    state, ownable, owner, proposed_owner = ownable_init
    _state = state.copy()
    owner = cached_contract(_state, account_def, owner)
    proposed_owner = cached_contract(_state, account_def, proposed_owner)
    ownable = cached_contract(_state, ownable_def, ownable)
    return ownable, owner, proposed_owner


@pytest.mark.asyncio
async def test_constructor(ownable_factory):
    ownable, owner, _ = ownable_factory
    expected = await ownable.owner().call()
    assert expected.result.owner == owner.contract_address


@pytest.mark.asyncio
async def test_transferOwnership(ownable_factory):
    ownable, owner, _ = ownable_factory
    new_owner = 123

    await signer.send_transaction(owner, ownable.contract_address, 'transferOwnership', [new_owner])

    executed_info = await ownable.owner().call()
    assert executed_info.result == (new_owner,)

@pytest.mark.asyncio
async def test_proposeOwnerhsip(ownable_factory):
    ownable, owner, proposed_owner = ownable_factory

    await signer.send_transaction(owner, ownable.contract_address, 'proposeOwner', [proposed_owner.contract_address])
    executed_info = await ownable.proposedOwner().call()
    assert executed_info.result == (proposed_owner.contract_address, )

@pytest.mark.asyncio
async def test_CancelOwnershipProposalByOwner(ownable_factory):
    ownable, owner, proposed_owner = ownable_factory

    await signer.send_transaction(owner, ownable.contract_address, 'proposeOwner', [proposed_owner.contract_address])
    await signer.send_transaction(owner, ownable.contract_address, 'cancelOwnershipProposal', [])

    executed_info = await ownable.proposedOwner().call()
    assert executed_info.result == (ZERO_ADDRESS, )

@pytest.mark.asyncio
async def test_CancelOwnershipProposalByProposedOwner(ownable_factory):
    ownable, owner, proposed_owner = ownable_factory

    await signer.send_transaction(owner, ownable.contract_address, 'proposeOwner', [proposed_owner.contract_address])
    await second_signer.send_transaction(proposed_owner, ownable.contract_address, 'cancelOwnershipProposal', [])

    executed_info = await ownable.proposedOwner().call()
    assert executed_info.result == (ZERO_ADDRESS, )

@pytest.mark.asyncio
async def test_cancelOwnershipProposal_emits_event(ownable_factory):
    ownable, owner, proposed_owner = ownable_factory
    await signer.send_transaction(owner, ownable.contract_address, 'proposeOwner', [proposed_owner.contract_address])
    tx_exec_info = await signer.send_transaction(owner, ownable.contract_address, 'cancelOwnershipProposal', [])

    assert_event_emitted(
        tx_exec_info,
        from_address=ownable.contract_address,
        name='OwnershipProposalCancelled',
        data=[
            owner.contract_address,
            proposed_owner.contract_address
        ]
    )

@pytest.mark.asyncio
async def test_transferOwnership_emits_event(ownable_factory):
    ownable, owner, _ = ownable_factory
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
async def test_proposeOwner_emits_event(ownable_factory):
    ownable, owner, proposed_owner = ownable_factory
    tx_exec_info = await signer.send_transaction(owner, ownable.contract_address, 'proposeOwner', [proposed_owner.contract_address])

    assert_event_emitted(
        tx_exec_info,
        from_address=ownable.contract_address,
        name='OwnershipProposed',
        data=[
            owner.contract_address,
            proposed_owner.contract_address
        ]
    )

@pytest.mark.asyncio
async def test_renounceOwnership(ownable_factory):
    ownable, owner, _ = ownable_factory
    await signer.send_transaction(owner, ownable.contract_address, 'renounceOwnership', [])
    executed_info = await ownable.owner().call()
    assert executed_info.result == (ZERO_ADDRESS,)


@pytest.mark.asyncio
async def test_renounceOwnership_emits_event(ownable_factory):
    ownable, owner, _ = ownable_factory
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
