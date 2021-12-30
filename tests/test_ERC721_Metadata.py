import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils import Signer, str_to_felt, assert_revert


signer = Signer(123456789987654321)

first_token_id = (5042, 0)
second_token_id = (7921, 1)
nonexistent_token = (111, 222)

BASE_URI = str_to_felt('https://api.com/v1/')


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

    erc721 = await starknet.deploy(
        "contracts/token/ERC721_Metadata.cairo",
        constructor_calldata=[
            str_to_felt("Non Fungible Token"),  # name
            str_to_felt("NFT"),                 # ticker
            account.contract_address,           # owner
            BASE_URI                            # baseURI
        ]
    )

    return starknet, erc721, account


#
# tokenURI
#

@pytest.mark.asyncio
@pytest.mark.parametrize('token_id', [
    first_token_id,
    second_token_id,
])
async def test_tokenURI(erc721_factory, token_id):
    _, erc721, account = erc721_factory

    # mint tokens to account
    await signer.send_transaction(
        account, erc721.contract_address, 'mint', [
            account.contract_address,
            *token_id
        ]
    )

    # should return an array with baseURI and token_id
    execution_info = await erc721.tokenURI(token_id).call()
    assert execution_info.result == ([BASE_URI, *token_id],)


@pytest.mark.asyncio
async def test_tokenURI_should_revert_for_nonexistent_token(erc721_factory):
    _, erc721, _ = erc721_factory

    # should revert for nonexistent token
    await assert_revert(erc721.tokenURI(nonexistent_token).call())


@pytest.mark.asyncio
async def test_tokenURI_baseURI_not_set(erc721_factory):
    starknet, _, account = erc721_factory

    # new ERC721_Metadata instance without setting the baseURI
    erc721_without_baseURI = await starknet.deploy(
        "contracts/token/ERC721_Metadata.cairo",
        constructor_calldata=[
            str_to_felt("Non Fungible Token"),  # name
            str_to_felt("NFT"),                 # ticker
            account.contract_address,           # owner
            0                                   # baseURI
        ]
    )

    # mint token to account
    await signer.send_transaction(
        account, erc721_without_baseURI.contract_address, 'mint', [
            account.contract_address,
            *first_token_id
        ]
    )

    # should return an array with '0' since baseURI is not set
    execution_info = await erc721_without_baseURI.tokenURI(first_token_id).call()
    assert execution_info.result == ([0],)


@pytest.mark.asyncio
async def test_supportsInterface(erc721_factory):
    _, erc721, _ = erc721_factory

    IERC721_Metadata = str_to_felt('0x5b5e139f')
    execution_info = await erc721.supportsInterface(IERC721_Metadata).call()
    assert execution_info.result == (1,)
