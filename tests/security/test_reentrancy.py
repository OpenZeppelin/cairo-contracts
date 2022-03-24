import pytest
from starkware.starknet.testing.starknet import Starknet
from utils import TRUE, FALSE, assert_revert

INITIAL_COUNTER = 0

@pytest.mark.asyncio
async def test_reentrancy_guard():
    starknet = await Starknet.empty()
    contract = await starknet.deploy("tests/mocks/reentrancy_mock.cairo", constructor_calldata=[INITIAL_COUNTER])
    attacker = await starknet.deploy("tests/mocks/reentrancy_attacker_mock.cairo")
    response = await contract.current_count().call()

    assert response.result == (INITIAL_COUNTER,)
    # should not allow remote callback
    await assert_revert(
        contract.countAndCall(attacker.contract_address).invoke(),
        reverted_with="ReentrancyGuard: reentrant call"
    )
    # should not allow local recursion
    await assert_revert(
        contract.countLocalRecursive(10).invoke(),
        reverted_with="ReentrancyGuard: reentrant call"
    )
    # should not allow indirect local recursion
    await assert_revert(
        contract.countThisRecursive(10).invoke(),
        reverted_with="ReentrancyGuard: reentrant call"
    )