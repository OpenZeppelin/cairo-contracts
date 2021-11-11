import pytest
from starkware.starknet.testing.starknet import Starknet


@pytest.mark.asyncio
async def test_initializer():
    starknet = await Starknet.empty()
    initializable = await starknet.deploy("contracts/Initializable.cairo")
    expected = await initializable.initialized().call()
    assert expected.result == (0,)

    await initializable.initialize().invoke()

    expected = await initializable.initialized().call()
    assert expected.result == (1,)
