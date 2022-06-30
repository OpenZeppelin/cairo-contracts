import pytest
from starkware.starknet.testing.starknet import Starknet
from utils import (
    assert_revert,
    get_contract_class,
    cached_contract,
    TRUE,
    FALSE
)


# interface ids
ERC165_ID = 0x01ffc9a7
INVALID_ID = 0xffffffff
OTHER_ID = 0x12345678


@pytest.fixture(scope='module')
async def erc165_factory():
    # class
    erc165_cls = get_contract_class("tests/mocks/ERC165.cairo")

    # deployment
    starknet = await Starknet.empty()
    erc165 = await starknet.deploy(contract_class=erc165_cls)

    # cache
    state = starknet.state.copy()
    erc165 = cached_contract(state, erc165_cls, erc165)
    return erc165


@pytest.mark.asyncio
async def test_165_interface(erc165_factory):
    erc165 = erc165_factory

    execution_info = await erc165.supportsInterface(ERC165_ID).call()
    assert execution_info.result == (TRUE,)


@pytest.mark.asyncio
async def test_invalid_id(erc165_factory):
    erc165 = erc165_factory

    execution_info = await erc165.supportsInterface(INVALID_ID).call()
    assert execution_info.result == (FALSE,)


@pytest.mark.asyncio
async def test_register_interface(erc165_factory):
    erc165 = erc165_factory

    execution_info = await erc165.supportsInterface(OTHER_ID).call()
    assert execution_info.result == (FALSE,)

    # register interface
    await erc165.registerInterface(OTHER_ID).invoke()

    execution_info = await erc165.supportsInterface(OTHER_ID).call()
    assert execution_info.result == (TRUE,)


@pytest.mark.asyncio
async def test_register_invalid_interface(erc165_factory):
    erc165 = erc165_factory

    await assert_revert(
        erc165.registerInterface(INVALID_ID).invoke(),
        reverted_with="ERC165: invalid interface id"
    )
