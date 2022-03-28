import pytest
from starkware.starknet.testing.starknet import Starknet
from utils import assert_revert, contract_path


# interface ids
ERC165_ID = 0x01ffc9a7
INVALID_ID = 0xffffffff
OTHER_ID = 0x12345678


@pytest.fixture(scope='module')
async def erc165_factory():
    starknet = await Starknet.empty()
    contract = await starknet.deploy(
        contract_path("tests/mocks/ERC165.cairo")
    )
    return contract


@pytest.mark.asyncio
async def test_165_interface(erc165_factory):
    contract = erc165_factory

    execution_info = await contract.supportsInterface(ERC165_ID).call()
    assert execution_info.result == (1,)


@pytest.mark.asyncio
async def test_invalid_id(erc165_factory):
    contract = erc165_factory

    execution_info = await contract.supportsInterface(INVALID_ID).call()
    assert execution_info.result == (0,)


@pytest.mark.asyncio
async def test_register_interface(erc165_factory):
    contract = erc165_factory

    execution_info = await contract.supportsInterface(OTHER_ID).call()
    assert execution_info.result == (0,)

    # register interface
    await contract.registerInterface(OTHER_ID).invoke()

    execution_info = await contract.supportsInterface(OTHER_ID).call()
    assert execution_info.result == (1,)


@pytest.mark.asyncio
async def test_register_invalid_interface(erc165_factory):
    contract = erc165_factory

    await assert_revert(
        contract.registerInterface(INVALID_ID).invoke(),
        reverted_with="ERC165: invalid interface id"
    )
