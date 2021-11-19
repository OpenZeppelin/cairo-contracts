import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils.Signer import Signer

signer = Signer(123456789987654321)

MAX_AMOUNT = (2**128 - 1, 2**128 - 1)


def str_to_felt(text):
    b_text = bytes(text, 'UTF-8')
    return int.from_bytes(b_text, "big")


def uint(a):
    return(a, 0)


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
async def erc721_factory():
    starknet = await Starknet.empty()
    account = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )
    await account.initialize(account.contract_address).invoke()

    erc721 = await starknet.deploy(
        "contracts/token/ERC721.cairo",
        constructor_calldata=[
            str_to_felt("Non Fungible Token"),
            str_to_felt("NFT"),
            account.contract_address
        ]
    )
    return starknet, erc721, account


@pytest.mark.asyncio
async def test_constructor(erc721_factory):
    _, erc721, account = erc721_factory
    execution_info = await erc721.name().call()
    assert execution_info.result == (str_to_felt("Non Fungible Token"),)

    execution_info = await erc721.symbol().call()
    assert execution_info.result == (str_to_felt("NFT"),)

    execution_info = await erc721.balance_of(account.contract_address).call()
    assert execution_info.result.res == uint(1)
