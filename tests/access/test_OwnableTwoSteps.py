from copyreg import constructor
import pytest
from signers import MockSigner
from nile.utils import ZERO_ADDRESS, assert_revert
from utils import assert_event_emitted, State, Account, get_contract_class, cached_contract


signer = MockSigner(123456789987654321)

@pytest.fixture(scope='module')
def contract_classes():
    return (
        Account.get_class,
        get_contract_class('OwnableTwoSteps')
    )


@pytest.fixture(scope='module')
async def ownable_two_steps_init(contract_classes):
    account_cls, ownable_two_steps_cls = contract_classes
    starknet = await State.init()
    owner = await Account.deploy(signer.public_key)
    ownable_two_steps = await starknet.deploy(
        contract_class=ownable_two_steps_cls,
        constructor_calldata=[owner.contract_address]
    )
    pending_owner = await Account.deploy(signer.public_key)
    third_account = await Account.deploy(signer.public_key)
    return starknet.state, ownable_two_steps, owner, pending_owner, third_account 


@pytest.fixture 
def contract_factory(contract_classes, ownable_two_steps_init):
    account_cls, ownable_two_steps_cls = contract_classes
    state, ownable_two_steps, owner, pending_owner, third_account = ownable_two_steps_init 
    _state = state.copy()
    owner = cached_contract(_state, account_cls, owner)
    ownable_two_steps = cached_contract(_state, ownable_two_steps_cls, ownable_two_steps)
    pending_owner = cached_contract(_state, account_cls, pending_owner)
    third_account = cached_contract(_state, account_cls, third_account)
    return ownable_two_steps, owner, pending_owner, third_account


# fixture to avoid repeating proposing a new owner
@pytest.fixture 
async def after_proposed(contract_factory):
    ownable_two_steps, owner, pending_owner, third_account = contract_factory
    await signer.send_transaction(
        owner,
        ownable_two_steps.contract_address,
        'transferOwnership',
        [pending_owner.contract_address]
    )

    return ownable_two_steps, owner, pending_owner, third_account


@pytest.mark.asyncio 
async def test_constructor(contract_factory):
    ownable_two_steps, owner, _, _ = contract_factory
    expected = await ownable_two_steps.owner().call()
    assert expected.result.owner == owner.contract_address


@pytest.mark.asyncio 
async def test_transfer_ownership(contract_factory):
    ownable_two_steps, owner, pending_owner, _ = contract_factory

    await signer.send_transaction(owner, ownable_two_steps.contract_address, 'transferOwnership', [pending_owner.contract_address])
    executed_info = await ownable_two_steps.pendingOwner().call()
    assert executed_info.result == (pending_owner.contract_address, )


@pytest.mark.asyncio 
async def test_transfer_ownership_from_zero_address(contract_factory):
    ownable_two_steps, _, pending_owner, _ = contract_factory

    await assert_revert(
        ownable_two_steps.transferOwnership(pending_owner.contract_address).execute(),
        reverted_with="OwnableTwoSteps: caller is the zero address"
    )


@pytest.mark.asyncio
async def test_transfer_ownership_to_zero_address(contract_factory):
    ownable_two_steps, owner, _, _ = contract_factory

    await assert_revert(
        signer.send_transaction(
            owner,
            ownable_two_steps.contract_address,
            'transferOwnership',
            [ZERO_ADDRESS]
        ),
        reverted_with="OwnableTwoSteps: pending owner cannot be the zero address"
    )


@pytest.mark.asyncio 
async def test_transfer_ownership_from_not_owner(contract_factory):
    ownable_two_steps, _, pending_owner, third_account = contract_factory 

    await assert_revert(
        signer.send_transaction(
            third_account,
            ownable_two_steps.contract_address,
            'transferOwnership',
            [pending_owner.contract_address]
        ),
        reverted_with="OwnableTwoSteps: caller is not the owner"
    )


@pytest.mark.asyncio 
async def test_transfer_ownership_when_already_proposed(after_proposed):
    ownable_two_steps, owner, pending_owner, _ = after_proposed

    await assert_revert(
        signer.send_transaction(
            owner, 
            ownable_two_steps.contract_address,
            'transferOwnership',
            [pending_owner.contract_address]
        ),
        reverted_with="OwnableTwoSteps: a proposal is already in motion"
    )


@pytest.mark.asyncio 
async def test_transfer_ownership_emits_event(contract_factory):
    ownable_two_steps, owner, pending_owner, _ = contract_factory

    tx_execution_info = await signer.send_transaction(
        owner,
        ownable_two_steps.contract_address,
        'transferOwnership',
        [pending_owner.contract_address]
    )

    assert_event_emitted(
        tx_exec_info=tx_execution_info,
        from_address=ownable_two_steps.contract_address,
        name='OwnershipProposed',
        data=[
            owner.contract_address,
            pending_owner.contract_address
        ]
    )


@pytest.mark.asyncio 
async def test_cancel_transfer_proposal_from_owner(after_proposed):
    ownable_two_steps, owner, pending_owner, _ = after_proposed

    await signer.send_transaction(
        owner,
        ownable_two_steps.contract_address,
        'cancelOwnershipProposal',
        []
    )

    executed_info = await ownable_two_steps.pendingOwner().call()
    assert executed_info.result == (ZERO_ADDRESS, )


@pytest.mark.asyncio
async def test_cancel_transfer_proposal_from_pending_owner(after_proposed):
    ownable_two_steps, _, pending_owner, _ = after_proposed

    await signer.send_transaction(
        pending_owner,
        ownable_two_steps.contract_address,
        'cancelOwnershipProposal',
        []
    )

    executed_info = await ownable_two_steps.pendingOwner().call()
    assert executed_info.result == (ZERO_ADDRESS, )


@pytest.mark.asyncio 
async def test_cancel_transfer_proposal_from_zero_address(after_proposed):
    ownable_two_steps, _, _, _ = after_proposed

    await assert_revert(
        ownable_two_steps.cancelOwnershipProposal().execute(),
        reverted_with="OwnableTwoSteps: caller is neither the current owner nor the pending owner"
    )


@pytest.mark.asyncio 
async def test_cancel_transfer_proposal_from_another_account(after_proposed):
    ownable_two_steps, _, _, third_account = after_proposed

    await assert_revert(
        signer.send_transaction(
            third_account,
            ownable_two_steps.contract_address,
            'cancelOwnershipProposal',
            []
        ),
        reverted_with="OwnableTwoSteps: caller is neither the current owner nor the pending owner"
    )


@pytest.mark.asyncio 
async def test_cancel_transfer_proposal_when_not_in_motion(contract_factory):
    ownable_two_steps, owner, _, _ = contract_factory

    await assert_revert(
        signer.send_transaction(
            owner,
            ownable_two_steps.contract_address,
            'cancelOwnershipProposal',
            []
        ),
        reverted_with="OwnableTwoSteps: a proposal is not in motion"
    )


@pytest.mark.asyncio
async def test_cancel_proposal_emits_event(after_proposed):
    ownable_two_steps, owner, pending_owner, _ = after_proposed

    tx_execution_info = await signer.send_transaction(
        owner,
        ownable_two_steps.contract_address,
        'cancelOwnershipProposal',
        []
    )

    assert_event_emitted(
        tx_exec_info=tx_execution_info,
        from_address=ownable_two_steps.contract_address,
        name='OwnershipProposalCancelled',
        data=[
            owner.contract_address,
            pending_owner.contract_address
        ]
    )


@pytest.mark.asyncio
async def test_accept_ownership(after_proposed):
    ownable_two_steps, _, pending_owner, _ = after_proposed

    await signer.send_transaction(
        pending_owner,
        ownable_two_steps.contract_address,
        'acceptOwnership',
        []
    )
    executed_info = await ownable_two_steps.pendingOwner().call()
    assert executed_info.result == (ZERO_ADDRESS, )
    executed_info = await ownable_two_steps.owner().call()
    assert executed_info.result == (pending_owner.contract_address, )


@pytest.mark.asyncio
async def test_accept_ownership_from_zero_address(after_proposed):
    ownable_two_steps, _, _, _ = after_proposed

    await assert_revert(
        ownable_two_steps.acceptOwnership().execute(),
        reverted_with="OwnableTwoSteps: caller is the zero address"
    )


@pytest.mark.asyncio
async def test_accept_ownership_from_owner(after_proposed):
    ownable_two_steps, owner, _, _ = after_proposed

    await assert_revert(
        signer.send_transaction(
            owner,
            ownable_two_steps.contract_address,
            'acceptOwnership',
            []
        ),
        reverted_with="OwnableTwoSteps: caller is not the pending owner"
    )


@pytest.mark.asyncio
async def test_accept_ownership_when_not_in_motion(contract_factory):
    ownable_two_steps, owner, _, _ = contract_factory

    await assert_revert(
        signer.send_transaction(
            owner,
            ownable_two_steps.contract_address,
            'acceptOwnership',
            []
        ),
        reverted_with="OwnableTwoSteps: a proposal is not in motion"
    )


@pytest.mark.asyncio
async def test_accept_ownership_emits_event(after_proposed):
    ownable_two_steps, owner, pending_owner, _ = after_proposed

    tx_execution_info = await signer.send_transaction(
        pending_owner,
        ownable_two_steps.contract_address,
        'acceptOwnership',
        []
    )

    assert_event_emitted(
        tx_exec_info=tx_execution_info,
        from_address=ownable_two_steps.contract_address,
        name='OwnershipTransferred',
        data=[
            owner.contract_address, 
            pending_owner.contract_address
        ]
    )


@pytest.mark.asyncio
async def test_renounce_ownership(contract_factory):
    ownable_two_steps, owner, _, _ = contract_factory

    await signer.send_transaction(
        owner,
        ownable_two_steps.contract_address,
        'renounceOwnership',
        []
    )

    executed_info = await ownable_two_steps.owner().call()
    assert executed_info.result == (ZERO_ADDRESS, )

    executed_info = await ownable_two_steps.pendingOwner().call()
    assert executed_info.result == (ZERO_ADDRESS, )


@pytest.mark.asyncio
async def test_renounce_ownership_from_not_owner(contract_factory):
    ownable_two_steps, _, pending_owner, _ = contract_factory

    await assert_revert(
        signer.send_transaction(
            pending_owner,
            ownable_two_steps.contract_address,
            'renounceOwnership',
            []
        ),
        reverted_with="OwnableTwoSteps: caller is not the owner"
    )


@pytest.mark.asyncio
async def test_renounce_ownership_from_zero_address(contract_factory):
    ownable_two_steps, _, _, _ = contract_factory

    await assert_revert(
        ownable_two_steps.renounceOwnership().execute(),
        reverted_with="OwnableTwoSteps: caller is the zero address"
    )


@pytest.mark.asyncio
async def test_renounce_ownership_emits_event(contract_factory):
    ownable_two_steps, owner, _, _ = contract_factory

    tx_execution_info = await signer.send_transaction(
        owner,
        ownable_two_steps.contract_address,
        'renounceOwnership',
        []
    )

    assert_event_emitted(
        tx_exec_info=tx_execution_info,
        from_address=ownable_two_steps.contract_address,
        name='OwnershipTransferred',
        data=[
            owner.contract_address,
            ZERO_ADDRESS
        ]
    )

