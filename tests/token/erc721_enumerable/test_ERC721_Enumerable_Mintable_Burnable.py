import pytest
from starkware.starknet.testing.starknet import Starknet
from signers import MockSigner
from utils import (
    str_to_felt, MAX_UINT256, get_contract_class, cached_contract,
    TRUE, assert_revert, to_uint, sub_uint, add_uint
)


signer = MockSigner(123456789987654321)

# random token IDs
TOKENS = [
    to_uint(5042), to_uint(793), to_uint(321), MAX_UINT256, to_uint(8)
]
# total tokens as uint
TOTAL_TOKENS = to_uint(len(TOKENS))
# random user address
RECIPIENT = 555
# random data (mimicking bytes in Solidity)
DATA = [0x42, 0x89, 0x55]
# selector id
ENUMERABLE_INTERFACE_ID = 0x780e9d63


@pytest.fixture(scope='module')
def contract_classes():
    account_cls = get_contract_class('openzeppelin/account/Account.cairo')
    erc721_cls = get_contract_class(
        'openzeppelin/token/erc721_enumerable/ERC721_Enumerable_Mintable_Burnable.cairo')

    return account_cls, erc721_cls


@pytest.fixture(scope='module')
async def erc721_init(contract_classes):
    account_cls, erc721_cls = contract_classes
    starknet = await Starknet.empty()
    account1 = await starknet.deploy(
        contract_class=account_cls,
        constructor_calldata=[signer.public_key]
    )
    account2 = await starknet.deploy(
        contract_class=account_cls,
        constructor_calldata=[signer.public_key]
    )
    erc721 = await starknet.deploy(
        contract_class=erc721_cls,
        constructor_calldata=[
            str_to_felt("Non Fungible Token"),  # name
            str_to_felt("NFT"),                 # ticker
            account1.contract_address           # owner
        ]
    )
    return (
        starknet.state,
        account1,
        account2,
        erc721
    )


@pytest.fixture
def erc721_factory(contract_classes, erc721_init):
    account_cls, erc721_cls = contract_classes
    state, account1, account2, erc721 = erc721_init
    _state = state.copy()
    account1 = cached_contract(_state, account_cls, account1)
    account2 = cached_contract(_state, account_cls, account2)
    erc721 = cached_contract(_state, erc721_cls, erc721)

    return erc721, account1, account2


@pytest.fixture
async def erc721_minted(erc721_factory):
    erc721, account, account2 = erc721_factory
    # mint tokens to account
    for token in TOKENS:
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                account.contract_address, *token]
        )

    return erc721, account, account2


#
# supportsInterface
#


@pytest.mark.asyncio
async def test_supportsInterface(erc721_factory):
    erc721, _, _ = erc721_factory

    execution_info = await erc721.supportsInterface(ENUMERABLE_INTERFACE_ID).invoke()
    assert execution_info.result == (TRUE,)

#
# totalSupply
#


@pytest.mark.asyncio
async def test_totalSupply(erc721_minted):
    erc721, _, _ = erc721_minted

    execution_info = await erc721.totalSupply().invoke()
    assert execution_info.result == (TOTAL_TOKENS,)


#
# tokenOfOwnerByIndex
#


@pytest.mark.asyncio
async def test_tokenOfOwnerByIndex(erc721_minted):
    erc721, account, _ = erc721_minted

    # check index
    for i in range(0, len(TOKENS)):
        execution_info = await erc721.tokenOfOwnerByIndex(
            account.contract_address, to_uint(i)).invoke()
        assert execution_info.result == (TOKENS[i],)


@pytest.mark.asyncio
async def test_tokenOfOwnerByIndex_greater_than_supply(erc721_minted):
    erc721, account, _ = erc721_minted

    tokens_plus_one = add_uint(TOTAL_TOKENS, to_uint(1))

    await assert_revert(
        erc721.tokenOfOwnerByIndex(
            account.contract_address, tokens_plus_one).invoke(),
        reverted_with="ERC721_Enumerable: owner index out of bounds"
    )


@pytest.mark.asyncio
async def test_tokenOfOwnerByIndex_owner_with_no_tokens(erc721_minted):
    erc721, _, _ = erc721_minted

    await assert_revert(
        erc721.tokenOfOwnerByIndex(RECIPIENT, to_uint(1)).invoke(),
        reverted_with="ERC721_Enumerable: owner index out of bounds"
    )


@pytest.mark.asyncio
async def test_tokenOfOwnerByIndex_transfer_all_tokens(erc721_minted):
    erc721, account, other = erc721_minted

    # transfer all tokens
    for token in TOKENS:
        await signer.send_transaction(
            account, erc721.contract_address, 'transferFrom', [
                account.contract_address,
                other.contract_address,
                *token
            ]
        )

    execution_info = await erc721.balanceOf(other.contract_address).invoke()
    assert execution_info.result == (TOTAL_TOKENS,)

    for i in range(0, len(TOKENS)):
        execution_info = await erc721.tokenOfOwnerByIndex(other.contract_address, to_uint(i)).invoke()
        assert execution_info.result == (TOKENS[i],)

    execution_info = await erc721.balanceOf(account.contract_address).invoke()
    assert execution_info.result == (to_uint(0),)

    # check that queries to old owner's token ownership reverts since index is less
    # than the target's balance
    await assert_revert(erc721.tokenOfOwnerByIndex(
        account.contract_address, to_uint(0)).invoke(),
        reverted_with="ERC721_Enumerable: owner index out of bounds"
    )


@pytest.mark.asyncio
async def test_tokenOfOwnerByIndex_safe_transfer_all_tokens(erc721_minted):
    erc721, account, other = erc721_minted

    # safe transfer all tokens
    for token in TOKENS:
        await signer.send_transaction(
            account, erc721.contract_address, 'safeTransferFrom', [
                account.contract_address,
                other.contract_address,
                *token,
                len(DATA),
                *DATA
            ]
        )

    execution_info = await erc721.balanceOf(other.contract_address).invoke()
    assert execution_info.result == (TOTAL_TOKENS,)

    for i in range(0, len(TOKENS)):
        execution_info = await erc721.tokenOfOwnerByIndex(other.contract_address, to_uint(i)).invoke()
        assert execution_info.result == (TOKENS[i],)

    execution_info = await erc721.balanceOf(account.contract_address).invoke()
    assert execution_info.result == (to_uint(0),)

    # check that queries to old owner's token ownership reverts since index is less
    # than the target's balance
    await assert_revert(erc721.tokenOfOwnerByIndex(
        account.contract_address, to_uint(0)).invoke(),
        reverted_with="ERC721_Enumerable: owner index out of bounds"
    )


#
# tokenByIndex
#


@pytest.mark.asyncio
async def test_tokenByIndex(erc721_minted):
    erc721, _, _ = erc721_minted

    for i in range(0, len(TOKENS)):
        execution_info = await erc721.tokenByIndex(to_uint(i)).invoke()
        assert execution_info.result == (TOKENS[i],)


@pytest.mark.asyncio
async def test_tokenByIndex_greater_than_supply(erc721_minted):
    erc721, _, _ = erc721_minted

    await assert_revert(
        erc721.tokenByIndex(to_uint(5)).invoke(),
        reverted_with="ERC721_Enumerable: global index out of bounds"
    )


@pytest.mark.asyncio
async def test_tokenByIndex_burn_last_token(erc721_minted):
    erc721, account, _ = erc721_minted

    tokens_minus_one = sub_uint(TOTAL_TOKENS, to_uint(1))

    # burn last token
    await signer.send_transaction(
        account, erc721.contract_address, 'burn', [
            *TOKENS[4]]
    )

    execution_info = await erc721.totalSupply().invoke()
    assert execution_info.result == (tokens_minus_one,)

    for i in range(0, 4):
        execution_info = await erc721.tokenByIndex(to_uint(i)).invoke()
        assert execution_info.result == (TOKENS[i],)

    await assert_revert(
        erc721.tokenByIndex(tokens_minus_one).invoke(),
        reverted_with="ERC721_Enumerable: global index out of bounds"
    )


@pytest.mark.asyncio
async def test_tokenByIndex_burn_first_token(erc721_minted):
    erc721, account, _ = erc721_minted

    # burn first token
    await signer.send_transaction(
        account, erc721.contract_address, 'burn', [
            *TOKENS[0]]
    )

    # TOKEN[0] should be burnt and TOKEN[4] should be swapped
    # to TOKEN[0]'s index
    new_token_order = [TOKENS[4], TOKENS[1], TOKENS[2], TOKENS[3]]
    for i in range(0, 3):
        execution_info = await erc721.tokenByIndex(to_uint(i)).invoke()
        assert execution_info.result == (new_token_order[i],)


@pytest.mark.asyncio
async def test_tokenByIndex_burn_and_mint(erc721_minted):
    erc721, account, _ = erc721_minted

    for token in TOKENS:
        await signer.send_transaction(
            account, erc721.contract_address, 'burn', [
                *token]
        )

    execution_info = await erc721.totalSupply().invoke()
    assert execution_info.result == (to_uint(0),)

    await assert_revert(
        erc721.tokenByIndex(to_uint(0)).invoke(),
        reverted_with="ERC721_Enumerable: global index out of bounds"
    )

    # mint new tokens
    for token in TOKENS:
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                account.contract_address, *token]
        )

    for i in range(0, len(TOKENS)):
        execution_info = await erc721.tokenByIndex(to_uint(i)).invoke()
        assert execution_info.result == (TOKENS[i],)
