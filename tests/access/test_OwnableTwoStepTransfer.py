import pytest
from starkware.starknet.testing.starknet import Starknet
from utils import (
    TestSigner,
    ZERO_ADDRESS,
    assert_revert,
    assert_event_emitted,
    get_contract_def,
    cached_contract
)


signer = TestSigner(123456789987654321)

@pytest.fixture(scope='module')
def contract_defs():
    return (
        get_contract_def('openzeppelin/account/Account.cairo'),
        get_contract_def('tests/mocks/OwnableTwoStepTransfer.cairo')
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
        constructor_calldata=[signer.public_key]
    )
    third_account = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )
    ownable_two_steps = await starknet.deploy(
        contract_def=ownable_def,
        constructor_calldata=[owner.contract_address]
    )
    return starknet.state, ownable_two_steps, owner, proposed_owner, third_account


@pytest.fixture
def ownable_factory(contract_defs, ownable_init):
    account_def, ownable_def = contract_defs
    state, ownable, owner, proposed_owner, third_account = ownable_init
    _state = state.copy()
    owner = cached_contract(_state, account_def, owner)
    proposed_owner = cached_contract(_state, account_def, proposed_owner)
    third_account = cached_contract(_state, account_def, third_account)
    ownable = cached_contract(_state, ownable_def, ownable)
    return ownable, owner, proposed_owner, third_account


# Used to aovid repeating proposing an owner everywhere else
@pytest.fixture
async def after_proposed(ownable_factory):
    ownable, owner, proposed_owner, third_account = ownable_factory
    await signer.send_transaction(owner, ownable.contract_address, 'proposeOwner', [proposed_owner.contract_address])

    return ownable, owner, proposed_owner, third_account


@pytest.mark.asyncio
async def test_constructor(ownable_factory):
    ownable, owner, _, _ = ownable_factory
    expected = await ownable.owner().call()
    assert expected.result.owner == owner.contract_address


@pytest.mark.asyncio
async def test_proposeOwnership(ownable_factory):
    ownable, owner, proposed_owner, _ = ownable_factory

    await signer.send_transaction(owner, ownable.contract_address, 'proposeOwner', [proposed_owner.contract_address])
    executed_info = await ownable.proposedOwner().call()
    assert executed_info.result == (proposed_owner.contract_address, )


@pytest.mark.asyncio
async def test_proposeOwnership_from_zero_address(ownable_factory):
    ownable, _, proposed_owner, _ = ownable_factory

    await assert_revert(
        ownable.proposeOwner(proposed_owner.contract_address).invoke(),
        reverted_with="Ownable: proposed owner nor caller cannot be the zero address"
    )


@pytest.mark.asyncio
async def test_proposeOwnership_from_another_account(ownable_factory):
    ownable, _, proposed_owner, third_account = ownable_factory

    await assert_revert(
        signer.send_transaction(
            third_account, 
            ownable.contract_address, 
            'proposeOwner', 
            [proposed_owner.contract_address]
        ),
        reverted_with="Ownable: caller is not the owner"
    )


@pytest.mark.asyncio
async def test_proposeOwnership_from_self(ownable_factory):
    ownable, owner, _, _ = ownable_factory

    await assert_revert(signer.send_transaction(
        owner, 
        ownable.contract_address, 
        'proposeOwner', 
        [owner.contract_address]
    ),
        reverted_with="Ownable: proposed owner cannot be the caller"
    )


@pytest.mark.asyncio
async def test_proposeOwnership_to_zero_address(ownable_factory):
    ownable, owner, _, _ = ownable_factory

    await assert_revert(signer.send_transaction(
        owner, 
        ownable.contract_address, 
        'proposeOwner', 
        [ZERO_ADDRESS]
    ),
        reverted_with="Ownable: proposed owner nor caller cannot be the zero address"
    )


@pytest.mark.asyncio
async def test_proposeOwnership_when_owner_already_proposed(after_proposed):
    ownable, owner, proposed_owner, _ = after_proposed

    await assert_revert(signer.send_transaction(
        owner,
        ownable.contract_address,
        'proposeOwner',
        [proposed_owner.contract_address]
    ),
        reverted_with="Ownable: a proposal is already in motion"
    )


@pytest.mark.asyncio
async def test_cancelOwnershipProposal_from_owner(after_proposed):
    ownable, owner, _, _ = after_proposed

    await signer.send_transaction(owner, ownable.contract_address, 'cancelOwnershipProposal', [])

    executed_info = await ownable.proposedOwner().call()
    assert executed_info.result == (ZERO_ADDRESS, )


@pytest.mark.asyncio
async def test_cancelOwnershipProposal_from_proposed_owner(after_proposed):
    ownable, _, proposed_owner, _ = after_proposed

    await signer.send_transaction(proposed_owner, ownable.contract_address, 'cancelOwnershipProposal', [])

    executed_info = await ownable.proposedOwner().call()
    assert executed_info.result == (ZERO_ADDRESS, )


@pytest.mark.asyncio
async def test_cancelOwnershipProposal_from_zero_address(after_proposed):
    ownable, _, _, _ = after_proposed

    await assert_revert(
        ownable.cancelOwnershipProposal().invoke(),
        reverted_with="Ownable: caller is neither the current owner nor the proposed owner"
    )


@pytest.mark.asyncio
async def test_cancelOwnershipProposal_from_neither_owner_nor_proposed(after_proposed):
    ownable, _, _, third_account  = after_proposed
    
    await assert_revert(
        signer.send_transaction(
            third_account,
            ownable.contract_address,
            'cancelOwnershipProposal',
            []
        ),
        reverted_with="Ownable: caller is neither the current owner nor the proposed owner"
    )


@pytest.mark.asyncio
async def test_cancelOwnershipProposal_when_ownership_transfer_is_not_engaged(ownable_factory):
    ownable, owner, _, _ = ownable_factory

    await assert_revert(
        signer.send_transaction(
            owner,
            ownable.contract_address,
            'cancelOwnershipProposal',
            []
        ),
        reverted_with="Ownable: no proposed owner to cancel"
    )


@pytest.mark.asyncio
async def test_acceptOwnership(after_proposed):
    ownable, _, proposed_owner, _  = after_proposed

    await signer.send_transaction(proposed_owner, ownable.contract_address, 'acceptOwnership', [])
    executed_info = await ownable.proposedOwner().call()
    # proposed owner should have been reset
    assert executed_info.result == (ZERO_ADDRESS, )
    # new owner should be proposed owner
    executed_info = await ownable.owner().call()
    assert executed_info.result == (proposed_owner.contract_address, )


@pytest.mark.asyncio
async def test_acceptOwnership_from_zero_address(after_proposed):
    ownable, _, _, _  = after_proposed

    await assert_revert(
        ownable.acceptOwnership().invoke(),
        reverted_with="Ownable: caller is the zero address"
    )


@pytest.mark.asyncio
async def test_acceptOwnership_from_other(after_proposed):
    ownable, _, _, third_account = after_proposed

    await assert_revert(
        signer.send_transaction(
            third_account,
            ownable.contract_address,
            'acceptOwnership',
            []
        ),
        reverted_with="Ownable: caller is not the proposed owner"
    )
    

@pytest.mark.asyncio 
async def test_acceptOwnership_when_ownership_proposal_is_not_engaged(ownable_factory):
    ownable, _, proposed_owner, _  = ownable_factory

    await assert_revert(
        signer.send_transaction(
            proposed_owner,
            ownable.contract_address,
            'acceptOwnership',
            []
        ),
        reverted_with="Ownable: a proposal is not in motion"
    )


@pytest.mark.asyncio
async def test_acceptOwnership_emits_event(after_proposed):
    ownable, owner, proposed_owner, _ = after_proposed
    
    tx_exec_info = await signer.send_transaction(proposed_owner, ownable.contract_address, 'acceptOwnership', [])

    assert_event_emitted(
        tx_exec_info,
        from_address=ownable.contract_address,
        name='OwnershipTransferred',
        data=[
            owner.contract_address,
            proposed_owner.contract_address
        ]
    )


@pytest.mark.asyncio
async def test_cancelOwnershipProposal_emits_event(after_proposed):
    ownable, owner, proposed_owner, _ = after_proposed
    
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
async def test_proposeOwner_emits_event(ownable_factory):
    ownable, owner, proposed_owner, _ = ownable_factory
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
    ownable, owner, _, _ = ownable_factory
    await signer.send_transaction(owner, ownable.contract_address, 'renounceOwnership', [])
    executed_info = await ownable.owner().call()
    assert executed_info.result == (ZERO_ADDRESS,)


@pytest.mark.asyncio
async def test_renounceOwnership_emits_event(ownable_factory):
    ownable, owner, _, _ = ownable_factory
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
