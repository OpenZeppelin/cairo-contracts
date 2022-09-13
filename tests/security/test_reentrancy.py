import pytest
from utils import (
    assert_revert, get_contract_class, State
)

INITIAL_COUNTER = 0


@pytest.fixture(scope='module')
async def reentrancy_mock():
    starknet = await State.init()
    contract = await starknet.deploy(
        contract_class=get_contract_class("ReentrancyMock"),
        constructor_calldata=[INITIAL_COUNTER]
    )

    return contract, starknet


@pytest.mark.asyncio
async def test_reentrancy_guard_deploy(reentrancy_mock):
    contract, _ = reentrancy_mock
    response = await contract.current_count().call()

    assert response.result == (INITIAL_COUNTER,)


@pytest.mark.asyncio
async def test_reentrancy_guard_remote_callback(reentrancy_mock):
    contract, starknet = reentrancy_mock
    attacker = await starknet.deploy("tests/mocks/ReentrancyAttackerMock.cairo")
    # should not allow remote callback
    await assert_revert(
        contract.count_and_call(attacker.contract_address).execute(),
        reverted_with="ReentrancyGuard: reentrant call"
    )


@pytest.mark.asyncio
async def test_reentrancy_guard_local_recursion(reentrancy_mock):
    contract, _ = reentrancy_mock
    # should not allow local recursion
    await assert_revert(
        contract.count_local_recursive(10).execute(),
        reverted_with="ReentrancyGuard: reentrant call"
    )
    # should not allow indirect local recursion
    await assert_revert(
        contract.count_this_recursive(10).execute(),
        reverted_with="ReentrancyGuard: reentrant call"
    )


@pytest.mark.asyncio
async def test_reentrancy_guard(reentrancy_mock):
    contract, _ = reentrancy_mock
    # should allow non reentrant call
    await contract.callback().execute()
    response = await contract.current_count().call()

    assert response.result == (1,)
