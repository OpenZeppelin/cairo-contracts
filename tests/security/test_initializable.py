import pytest
from starkware.starknet.testing.starknet import Starknet
from utils import TRUE, FALSE, assert_revert, contract_path


@pytest.mark.asyncio
async def test_initializer():
    starknet = await Starknet.empty()
    initializable = await starknet.deploy(
        contract_path("tests/mocks/Initializable.cairo")
    )
    expected = await initializable.initialized().call()
    assert expected.result == (FALSE,)

    await initializable.initialize().invoke()

    expected = await initializable.initialized().call()
    assert expected.result == (TRUE,)

    # second initialize invocation should revert
    await assert_revert(
        initializable.initialize().invoke(),
        reverted_with="Initializable: contract already initialized"
    )
