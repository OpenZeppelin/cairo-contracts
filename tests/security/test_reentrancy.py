import pytest
from starkware.starknet.testing.starknet import Starknet
from utils import TRUE, FALSE, assert_revert


@pytest.mark.asyncio
async def test_initializer():
    starknet = await Starknet.empty()
    reentrancy_guard = await starknet.deploy("openzeppelin/security/reentrancy_guard.cairo")
    expected = await reentrancy_guard.initialized().call()
    assert expected.result == (FALSE,)

    await reentrancy_guard.reentrancyGuard_start().invoke()

    expected = await reentrancy_guard.reentrancyGuard_start().call()
    assert expected.result == (TRUE,)
    # should not allow remote callback
    # should not allow local recursion
    # should not allow indirect local recursion
    await assert_revert(
        reentrancy_guard.reentrancyGuard_start().invoke(),
        reverted_with="ReentrancyGuard: reentrant call"
    )
