import pytest
from starkware.starknet.testing.starknet import Starknet


@pytest.mark.asyncio
async def test_initializer():
    starknet = await Starknet.empty()
    initializable = await starknet.deploy("contracts/Initializable.cairo")
    assert await initializable.initialized().call() == (0,)
    await initializable.initialize().invoke()
    assert await initializable.initialized().call() == (1,)
