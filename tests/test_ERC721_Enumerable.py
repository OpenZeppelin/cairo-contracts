import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils import Signer, uint, str_to_felt, MAX_UINT256, assert_revert


signer = Signer(123456789987654321)

# random user address
user = 123
# random token IDs
tokens = [(5042, 0), (7921, 1), (0, 13), MAX_UINT256, (234, 345)]


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

    # mint tokens to account
    for token in tokens:
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                account.contract_address, *token]
        )

    return starknet, erc721, account

#
# supportsInterface
#


@pytest.mark.asyncio
async def test_supportsInterface(erc721_factory):
    _, erc721, _ = erc721_factory

    enum_interface_id = str_to_felt('0x780e9d63')

    execution_info = await erc721.supportsInterface(enum_interface_id).call()
    assert execution_info.result == (1,)

#
# totalSupply
#


@pytest.mark.asyncio
async def test_totalSupply(erc721_factory):
    _, erc721, _ = erc721_factory

    execution_info = await erc721.totalSupply().call()
    assert execution_info.result == (uint(5),)


#
# tokenOfOwnerByIndex
#


@pytest.mark.asyncio
async def test_tokenOfOwnerByIndex(erc721_factory):
    _, erc721, account = erc721_factory

    # check index
    for i, t in zip(range(0, 5), range(0, 5)):
        execution_info = await erc721.tokenOfOwnerByIndex(account.contract_address, uint(i)).call()
        assert execution_info.result == (tokens[t],)


@pytest.mark.asyncio
async def test_tokenOfOwnerByIndex_greater_than_supply(erc721_factory):
    _, erc721, account = erc721_factory

    await assert_revert(
        erc721.tokenOfOwnerByIndex(account.contract_address, uint(5)).call()
    )


@pytest.mark.asyncio
async def test_tokenOfOwnerByIndex_owner_with_no_tokens(erc721_factory):
    _, erc721, _ = erc721_factory

    await assert_revert(
        erc721.tokenOfOwnerByIndex(user, uint(1)).call()
    )


@pytest.mark.asyncio
async def test_tokenOfOwnerByIndex_transfer_all_tokens(erc721_factory):
    _, erc721, account = erc721_factory

    # transfer all tokens
    for token in tokens:
        await signer.send_transaction(
            account, erc721.contract_address, 'transferFrom', [
                account.contract_address,
                user,
                *token
            ]
        )

    execution_info = await erc721.balanceOf(user).call()
    assert execution_info.result == (uint(5),)

    for i, t in zip(range(0, 5), range(0, 5)):
        execution_info = await erc721.tokenOfOwnerByIndex(user, uint(i)).call()
        assert execution_info.result == (tokens[t],)

    execution_info = await erc721.balanceOf(account.contract_address).call()
    assert execution_info.result == (uint(0),)

    # check that queries to old owner's token ownership reverts since index is less
    # than the target's balance
    await assert_revert(erc721.tokenOfOwnerByIndex(
        account.contract_address, uint(0)).call()
    )

#
# tokenByIndex
#


@pytest.mark.asyncio
async def test_tokenByIndex(erc721_factory):
    _, erc721, _ = erc721_factory

    for i, t in zip(range(0, 5), range(0, 5)):
        execution_info = await erc721.tokenByIndex(uint(i)).call()
        assert execution_info.result == (tokens[t],)


@pytest.mark.asyncio
async def test_tokenByIndex_greater_than_supply(erc721_factory):
    _, erc721, _ = erc721_factory

    await assert_revert(
        erc721.tokenByIndex(uint(5)).call()
    )


@pytest.mark.asyncio
async def test_tokenByIndex_burn_last_token(erc721_factory):
    _, erc721, account = erc721_factory

    # burn last token
    await signer.send_transaction(
        account, erc721.contract_address, 'burn', [
            *tokens[4]]
    )

    execution_info = await erc721.totalSupply().call()
    assert execution_info.result == (uint(4),)

    for i, t in zip(range(0, 4), range(0, 4)):
        execution_info = await erc721.tokenByIndex(uint(i)).call()
        assert execution_info.result == (tokens[t],)

    await assert_revert(
        erc721.tokenByIndex(uint(4)).call()
    )


@pytest.mark.asyncio
async def test_tokenByIndex_burn_first_token(erc721_factory):
    _, erc721, account = erc721_factory

    # burn first token
    await signer.send_transaction(
        account, erc721.contract_address, 'burn', [
            *tokens[0]]
    )

    # the first token should be burnt and the fourth token should be swapped
    # to the first token's index
    new_token_order = [tokens[3], tokens[1], tokens[2]]
    for i, t in zip(range(0, 3), range(0, 3)):
        execution_info = await erc721.tokenByIndex(uint(i)).call()
        assert execution_info.result == (new_token_order[t],)


@pytest.mark.asyncio
async def test_tokenByIndex_burn_and_mint(erc721_factory):
    _, erc721, account = erc721_factory

    new_token_order = [tokens[3], tokens[1], tokens[2]]
    for token in new_token_order:
        await signer.send_transaction(
            account, erc721.contract_address, 'burn', [
                *token]
        )

    execution_info = await erc721.totalSupply().call()
    assert execution_info.result == (uint(0),)

    await assert_revert(
        erc721.tokenByIndex(uint(0)).call()
    )

    # mint new tokens
    for token in tokens:
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                account.contract_address, *token]
        )

    for i, t in zip(range(0, 5), range(0, 5)):
        execution_info = await erc721.tokenByIndex(uint(i)).call()
        assert execution_info.result == (tokens[t],)
