import pytest
from utils import TRUE, FALSE, assert_revert, get_contract_class, State


@pytest.mark.asyncio
async def test_initializer():
    starknet = await State.init()
    initializable = await starknet.deploy(
        contract_class=get_contract_class("Initializable")
    )
    expected = await initializable.initialized().call()
    assert expected.result == (FALSE,)

    await initializable.initialize().execute()

    expected = await initializable.initialized().call()
    assert expected.result == (TRUE,)

    # second initialize invocation should revert
    await assert_revert(
        initializable.initialize().execute(),
        reverted_with="Initializable: contract already initialized"
    )
