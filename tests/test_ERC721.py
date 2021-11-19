import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils.Signer import Signer

signer = Signer(123456789987654321)


MAX_AMOUNT = (2**128 - 1, 2**128 - 1)

user1 = 123
user2 = 234
user3 = 345
user4 = 456
user5 = 567

first_token_id = (5042, 0)
second_token_id = (7921, 1)
third_token_id = (0, 13)
fourth_token_id = (2**128 - 1, 2**128 - 1)


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
    _, erc721, _ = erc721_factory
    execution_info = await erc721.name().call()
    assert execution_info.result == (str_to_felt("Non Fungible Token"),)

    execution_info = await erc721.symbol().call()
    assert execution_info.result == (str_to_felt("NFT"),)


@pytest.mark.asyncio
async def test_mint(erc721_factory):
    _, erc721, account = erc721_factory
    await signer.send_transaction(account, erc721.contract_address, 'mint', [user1, *first_token_id])

    # check balance of user
    execution_info = await erc721.balance_of(user1).call()
    assert execution_info.result == (uint(1),)

    # check user owns token
    execution_info = await erc721.owner_of(first_token_id).call()
    assert execution_info.result == (user1,)
