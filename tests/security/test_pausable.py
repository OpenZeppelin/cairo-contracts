import pytest
from starkware.starknet.testing.starknet import Starknet
from signers import MockSigner
from utils import (
    TRUE, FALSE, assert_revert, assert_event_emitted, 
    get_contract_class, cached_contract
)


signer = MockSigner(12345678987654321)

@pytest.fixture
async def pausable_factory():
    # class
    pausable_cls = get_contract_class("tests/mocks/Pausable.cairo")
    account_cls = get_contract_class("openzeppelin/account/Account.cairo")

    starknet = await Starknet.empty()
    pausable = await starknet.deploy(
        contract_class=pausable_cls,
        constructor_calldata=[]
    )
    account = await starknet.deploy(
        contract_class=account_cls,
        constructor_calldata=[signer.public_key]
    )
    state = starknet.state.copy()

    pausable = cached_contract(state, pausable_cls, pausable)
    account = cached_contract(state, account_cls, account)
    return pausable, account


@pytest.mark.asyncio
async def test_pausable_when_unpaused(pausable_factory):
    contract, _ = pausable_factory

    execution_info = await contract.isPaused().call()
    assert execution_info.result.isPaused == FALSE

    execution_info = await contract.getCount().call()
    assert execution_info.result.res == 0
    
    # check that function executes when unpaused
    await contract.normalProcess().invoke()

    execution_info = await contract.getCount().call()
    assert execution_info.result.res == 1

    await assert_revert(
        contract.drasticMeasure().invoke(),
        reverted_with="Pausable: not paused"
    )

@pytest.mark.asyncio
async def test_pausable_when_paused(pausable_factory):
    contract, _ = pausable_factory

    execution_info = await contract.isPaused().call()
    assert execution_info.result.isPaused == FALSE

    # pause
    await contract.pause().invoke()

    execution_info = await contract.isPaused().call()
    assert execution_info.result.isPaused == TRUE

    await assert_revert(
        contract.normalProcess().invoke(),
        reverted_with="Pausable: paused"
    )

    execution_info = await contract.getDrasticMeasureTaken().call()
    assert execution_info.result.res == FALSE

    # drastic measure
    await contract.drasticMeasure().invoke()

    execution_info = await contract.getDrasticMeasureTaken().call()
    assert execution_info.result.res == TRUE

    # unpause
    await contract.unpause().invoke()

    execution_info = await contract.isPaused().call()
    assert execution_info.result.isPaused == FALSE

    # check normal process after unpausing
    await contract.normalProcess().invoke()

    execution_info = await contract.getCount().call()
    assert execution_info.result.res == 1

    await assert_revert(
        contract.drasticMeasure().invoke(),
        reverted_with="Pausable: not paused"
    )

@pytest.mark.asyncio
async def test_pausable_pause_when_paused(pausable_factory):
    contract, _ = pausable_factory

    # pause
    await contract.pause().invoke()

    # re-pause
    await assert_revert(
        contract.pause().invoke(),
        reverted_with="Pausable: paused"
    )

    # unpause
    await contract.unpause().invoke()

    # re-unpause
    await assert_revert(
        contract.unpause().invoke(),
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
