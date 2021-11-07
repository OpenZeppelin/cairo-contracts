import pytest
from starkware.starknet.testing.starknet import Starknet
from utils.Deploy import deploy_contract


@pytest.mark.asyncio
async def test_initializer():
    starknet = await Starknet.empty()
    initializable = await deploy_contract(starknet, "contracts/Initializable.cairo")
    expected = await initializable.initialized().call()
    assert expected.result == (0,)

    await initializable.initialize().invoke()

    expected = await initializable.initialized().call()
    assert expected.result == (1,)
