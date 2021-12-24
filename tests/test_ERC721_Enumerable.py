import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils import Signer, uint, str_to_felt, MAX_UINT256, assert_revert
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode


signer = Signer(123456789987654321)

user1 = 123
user2 = 234

first_token_id = (5042, 0)
second_token_id = (7921, 1)
third_token_id = (0, 13)
fourth_token_id = MAX_UINT256
fifth_token_id = (234, 345)


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
        "contracts/token/ERC721_Enumerable.cairo",
        constructor_calldata=[
            str_to_felt("Non Fungible Token"),  # name
            str_to_felt("NFT"),                 # ticker
            account.contract_address            # owner
        ]
    )

    return starknet, erc721, account

#
# totalSupply
#


@pytest.mark.asyncio
async def test_totalSupply(erc721_factory):
    _, erc721, account = erc721_factory

    # mint tokens to account
    tokens = [first_token_id, second_token_id]
    for token in tokens:
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                account.contract_address, *token]
        )

    # totalSupply should be (2, 0)
    execution_info = await erc721.totalSupply().call()
    assert execution_info.result == (uint(2),)


#
# tokenOfOwnerByIndex
#


@pytest.mark.asyncio
async def test_tokenOfOwnerByIndex(erc721_factory):
    _, erc721, account = erc721_factory

    # check index
    tokens = [first_token_id, second_token_id]
    for i, t in zip(range(1, 3), range(0, 2)):
        execution_info = await erc721.tokenOfOwnerByIndex(account.contract_address, uint(i)).call()
        assert execution_info.result == (tokens[t],)


@pytest.mark.asyncio
async def test_tokenOfOwnerByIndex_greater_than_supply(erc721_factory):
    _, erc721, account = erc721_factory

    # should fail since index number is greater than supply
    assert_revert(lambda: erc721.tokenOfOwnerByIndex(
        account.contract_address, uint(3)).call())


@pytest.mark.asyncio
async def test_tokenOfOwnerByIndex_owner_with_no_tokens(erc721_factory):
    _, erc721, _ = erc721_factory

    # should fail since index number is greater than supply
    assert_revert(lambda: erc721.tokenOfOwnerByIndex(
        user1, uint(1)).call())


@pytest.mark.asyncio
async def test_tokenOfOwnerByIndex_transfer_all_tokens(erc721_factory):
    _, erc721, account = erc721_factory

    # transfer all tokens
    tokens = [first_token_id, second_token_id]
    for token in tokens:
        await signer.send_transaction(
            account, erc721.contract_address, 'transferFrom', [
                account.contract_address,
                user1,
                *token
            ]
        )

    # returns correct balance for target
    execution_info = await erc721.balanceOf(user1).call()
    assert execution_info.result == (uint(2),)

    # checks index is updated with user1
    for i, t in zip(range(1, 3), range(0, 2)):
        execution_info = await erc721.tokenOfOwnerByIndex(user1, uint(i)).call()
        assert execution_info.result == (tokens[t],)

    # checks original owner's balance is zero
    execution_info = await erc721.balanceOf(account.contract_address).call()
    assert execution_info.result == (uint(0),)

    # zero balance should revert
    assert_revert(lambda: erc721.tokenOfOwnerByIndex(uint(0).call()))


#
# tokenByIndex
#


@pytest.mark.asyncio
async def test_tokenByIndex(erc721_factory):
    _, erc721, _ = erc721_factory

    # checks index
    tokens = [first_token_id, second_token_id]
    for i, t in zip(range(1, 3), range(0, 2)):
        execution_info = await erc721.tokenByIndex(uint(i)).call()
        assert execution_info.result == (tokens[t],)


@pytest.mark.asyncio
async def test_tokenByIndex_greater_than_supply(erc721_factory):
    _, erc721, _ = erc721_factory

    # token index does not exist therefore should revert
    assert_revert(lambda: erc721.tokenByIndex(uint(3).call()))


@pytest.mark.asyncio
async def test_tokenByIndex_burn_and_mint(erc721_factory):
    _, erc721, account = erc721_factory

    # burn all tokens
    tokens = [first_token_id, second_token_id]
    for token in tokens:
        await signer.send_transaction(
            account, erc721.contract_address, 'burn', [
                user1, *token]
        )

    # mint new tokens to new owner
    new_tokens = [third_token_id, fourth_token_id, fifth_token_id]
    for token in new_tokens:
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                user2, *token]
        )

    # check totalSupply
    execution_info = await erc721.totalSupply().call()
    assert execution_info.result == (uint(3),)

    # check indexing
    for i, t in zip(range(1, 4), range(0, 3)):
        execution_info = await erc721.tokenByIndex(uint(i)).call()
        assert execution_info.result == (new_tokens[t],)

#
# supportsInterface
#


@pytest.mark.asyncio
async def test_supportsInterface(erc721_factory):
    _, erc721, _ = erc721_factory

    IERC721_Enumerable = str_to_felt('0x780e9d63')
    execution_info = await erc721.supportsInterface(IERC721_Enumerable).call()
    assert execution_info.result == (1,)
