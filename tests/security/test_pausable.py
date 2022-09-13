import pytest
from signers import MockSigner
from utils import (
    TRUE, FALSE, assert_revert, assert_event_emitted,
    get_contract_class, cached_contract, State, Account
)


signer = MockSigner(12345678987654321)

@pytest.fixture
async def pausable_factory():
    # class
    pausable_cls = get_contract_class("Pausable")
    account_cls = Account.get_class

    # deploy
    starknet = await State.init()
    account = await Account.deploy(signer.public_key)
    pausable = await starknet.deploy(
        contract_class=pausable_cls,
        constructor_calldata=[]
    )
    state = starknet.state.copy()

    # cache
    pausable = cached_contract(state, pausable_cls, pausable)
    account = cached_contract(state, account_cls, account)

    return pausable, account


@pytest.mark.asyncio
async def test_pausable_when_unpaused(pausable_factory):
    contract, _ = pausable_factory

    execution_info = await contract.isPaused().call()
    assert execution_info.result.paused == FALSE

    execution_info = await contract.getCount().call()
    assert execution_info.result.count == 0

    # check that function executes when unpaused
    await contract.normalProcess().execute()

    execution_info = await contract.getCount().call()
    assert execution_info.result.count == 1

    await assert_revert(
        contract.drasticMeasure().execute(),
        reverted_with="Pausable: not paused"
    )

@pytest.mark.asyncio
async def test_pausable_when_paused(pausable_factory):
    contract, _ = pausable_factory

    execution_info = await contract.isPaused().call()
    assert execution_info.result.paused == FALSE

    # pause
    await contract.pause().execute()

    execution_info = await contract.isPaused().call()
    assert execution_info.result.paused == TRUE

    await assert_revert(
        contract.normalProcess().execute(),
        reverted_with="Pausable: paused"
    )

    execution_info = await contract.getDrasticMeasureTaken().call()
    assert execution_info.result.success == FALSE

    # drastic measure
    await contract.drasticMeasure().execute()

    execution_info = await contract.getDrasticMeasureTaken().call()
    assert execution_info.result.success == TRUE

    # unpause
    await contract.unpause().execute()

    execution_info = await contract.isPaused().call()
    assert execution_info.result.paused == FALSE

    # check normal process after unpausing
    await contract.normalProcess().execute()

    execution_info = await contract.getCount().call()
    assert execution_info.result.count == 1

    await assert_revert(
        contract.drasticMeasure().execute(),
        reverted_with="Pausable: not paused"
    )

@pytest.mark.asyncio
async def test_pausable_pause_when_paused(pausable_factory):
    contract, _ = pausable_factory

    # pause
    await contract.pause().execute()

    # re-pause
    await assert_revert(
        contract.pause().execute(),
        reverted_with="Pausable: paused"
    )

    # unpause
    await contract.unpause().execute()

    # re-unpause
    await assert_revert(
        contract.unpause().execute(),
        reverted_with="Pausable: not paused"
    )

@pytest.mark.asyncio
async def test_pausable_emits_events(pausable_factory):
    contract, account = pausable_factory

    # pause
    tx_exec_info = await signer.send_transaction(
        account, contract.contract_address, 'pause', []
        )

    assert_event_emitted(
        tx_exec_info,
        from_address=contract.contract_address,
        name='Paused',
        data=[account.contract_address]
    )

    # unpause
    tx_exec_info = await signer.send_transaction(
        account, contract.contract_address, 'unpause', []
        )

    assert_event_emitted(
        tx_exec_info,
        from_address=contract.contract_address,
        name='Unpaused',
        data=[account.contract_address]
    )
