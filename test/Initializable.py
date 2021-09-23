import pytest
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.compiler.compile import compile_starknet_files
from utils import deploy


@pytest.mark.asyncio
async def test_initializer():
    starknet = await Starknet.empty()
    initializable = await deploy(starknet, "contracts/Initializable.cairo")
    assert await initializable.initialized().call() == (0,)
    await initializable.initialize().invoke()
    assert await initializable.initialized().call() == (1,)
