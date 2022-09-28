import pytest
from signers import MockSigner
from utils import (
    MAX_UINT256, get_contract_class, cached_contract, TRUE,
    assert_revert, assert_event_emitted, assert_events_emitted, to_uint,
    sub_uint, add_uint, ZERO_ADDRESS, State, Account
)
from ERC721BaseSuite import ERC721Base, NAME, SYMBOL, NONEXISTENT_TOKEN, DATA, RECIPIENT
from access.OwnableBaseSuite import OwnableBase


signer = MockSigner(123456789987654321)


# random token IDs
TOKENS = [
    to_uint(5042), to_uint(793), to_uint(321), MAX_UINT256, to_uint(8)
]
TOKEN = TOKENS[0]
# total tokens as uint
TOTAL_TOKENS = to_uint(len(TOKENS))
# selector id
ENUMERABLE_INTERFACE_ID = 0x780e9d63


@pytest.fixture(scope='module')
def contract_classes():
    account_cls = Account.get_class
    erc721_cls = get_contract_class('ERC721EnumerableMintableBurnable')
    erc721_holder_cls = get_contract_class('ERC721Holder')
    unsupported_cls = get_contract_class('Initializable')

    return account_cls, erc721_cls, erc721_holder_cls, unsupported_cls


@pytest.fixture(scope='module')
async def erc721_init(contract_classes):
    account_cls, erc721_cls, erc721_holder_cls, unsupported_cls = contract_classes
    starknet = await State.init()
    account1 = await Account.deploy(signer.public_key)
    account2 = await Account.deploy(signer.public_key)
    erc721 = await starknet.deploy(
        contract_class=erc721_cls,
        constructor_calldata=[
            NAME,                       # name
            SYMBOL,                     # symbol
            account1.contract_address   # owner
        ]
    )
    erc721_holder = await starknet.deploy(
        contract_class=erc721_holder_cls,
        constructor_calldata=[]
    )
    unsupported = await starknet.deploy(
        contract_class=unsupported_cls,
        constructor_calldata=[]
    )
    return (
        starknet.state,
        account1,
        account2,
        erc721,
        erc721_holder,
        unsupported,
    )


@pytest.fixture
def contract_factory(contract_classes, erc721_init):
    account_cls, erc721_cls, erc721_holder_cls, unsupported_cls = contract_classes
    state, account1, account2, erc721, erc721_holder, unsupported = erc721_init
    _state = state.copy()
    account1 = cached_contract(_state, account_cls, account1)
    account2 = cached_contract(_state, account_cls, account2)
    erc721 = cached_contract(_state, erc721_cls, erc721)
    erc721_holder = cached_contract(_state, erc721_holder_cls, erc721_holder)
    unsupported = cached_contract(_state, unsupported_cls, unsupported)

    return erc721, account1, account2, erc721_holder, unsupported


@pytest.fixture
async def erc721_minted(contract_factory):
    erc721, account, account2, erc721_holder, unsupported = contract_factory
    # mint tokens to account
    for token in TOKENS:
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                account.contract_address, *token]
        )

    return erc721, account, account2, erc721_holder, unsupported


class TestERC721EnumerableMintableBurnable(ERC721Base, OwnableBase):
    #
    # supportsInterface
    #

    @pytest.mark.asyncio
    async def test_supportsInterface(self, contract_factory):
        erc721, *_ = contract_factory

        execution_info = await erc721.supportsInterface(ENUMERABLE_INTERFACE_ID).execute()
        assert execution_info.result == (TRUE,)

    #
    # totalSupply
    #

    @pytest.mark.asyncio
    async def test_totalSupply(self, erc721_minted):
        erc721, *_ = erc721_minted

        execution_info = await erc721.totalSupply().execute()
        assert execution_info.result == (TOTAL_TOKENS,)


    #
    # tokenOfOwnerByIndex
    #


    @pytest.mark.asyncio
    async def test_tokenOfOwnerByIndex(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        # check index
        for i in range(0, len(TOKENS)):
            execution_info = await erc721.tokenOfOwnerByIndex(
                account.contract_address, to_uint(i)).execute()
            assert execution_info.result == (TOKENS[i],)


    @pytest.mark.asyncio
    async def test_tokenOfOwnerByIndex_greater_than_supply(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        tokens_plus_one = add_uint(TOTAL_TOKENS, to_uint(1))

        await assert_revert(
            erc721.tokenOfOwnerByIndex(
                account.contract_address, tokens_plus_one).execute(),
            reverted_with="ERC721Enumerable: owner index out of bounds"
        )


    @pytest.mark.asyncio
    async def test_tokenOfOwnerByIndex_owner_with_no_tokens(self, erc721_minted):
        erc721, *_ = erc721_minted

        await assert_revert(
            erc721.tokenOfOwnerByIndex(RECIPIENT, to_uint(1)).execute(),
            reverted_with="ERC721Enumerable: owner index out of bounds"
        )


    @pytest.mark.asyncio
    async def test_tokenOfOwnerByIndex_transfer_all_tokens(self, erc721_minted):
        erc721, account, other, *_ = erc721_minted

        # transfer all tokens
        for token in TOKENS:
            await signer.send_transaction(
                account, erc721.contract_address, 'transferFrom', [
                    account.contract_address,
                    other.contract_address,
                    *token
                ]
            )

        execution_info = await erc721.balanceOf(other.contract_address).execute()
        assert execution_info.result == (TOTAL_TOKENS,)

        for i in range(0, len(TOKENS)):
            execution_info = await erc721.tokenOfOwnerByIndex(other.contract_address, to_uint(i)).execute()
            assert execution_info.result == (TOKENS[i],)

        execution_info = await erc721.balanceOf(account.contract_address).execute()
        assert execution_info.result == (to_uint(0),)

        # check that queries to old owner's token ownership reverts since index is less
        # than the target's balance
        await assert_revert(erc721.tokenOfOwnerByIndex(
            account.contract_address, to_uint(0)).execute(),
            reverted_with="ERC721Enumerable: owner index out of bounds"
        )


    @pytest.mark.asyncio
    async def test_tokenOfOwnerByIndex_safe_transfer_all_tokens(self, erc721_minted):
        erc721, account, other, *_ = erc721_minted

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

        execution_info = await erc721.balanceOf(other.contract_address).execute()
        assert execution_info.result == (TOTAL_TOKENS,)

        for i in range(0, len(TOKENS)):
            execution_info = await erc721.tokenOfOwnerByIndex(other.contract_address, to_uint(i)).execute()
            assert execution_info.result == (TOKENS[i],)

        execution_info = await erc721.balanceOf(account.contract_address).execute()
        assert execution_info.result == (to_uint(0),)

        # check that queries to old owner's token ownership reverts since index is less
        # than the target's balance
        await assert_revert(erc721.tokenOfOwnerByIndex(
            account.contract_address, to_uint(0)).execute(),
            reverted_with="ERC721Enumerable: owner index out of bounds"
        )


    #
    # tokenByIndex
    #


    @pytest.mark.asyncio
    async def test_tokenByIndex(self, erc721_minted):
        erc721, *_ = erc721_minted

        for i in range(0, len(TOKENS)):
            execution_info = await erc721.tokenByIndex(to_uint(i)).execute()
            assert execution_info.result == (TOKENS[i],)


    @pytest.mark.asyncio
    async def test_tokenByIndex_greater_than_supply(self, erc721_minted):
        erc721, *_ = erc721_minted

        await assert_revert(
            erc721.tokenByIndex(to_uint(5)).execute(),
            reverted_with="ERC721Enumerable: global index out of bounds"
        )


    @pytest.mark.asyncio
    async def test_tokenByIndex_burn_last_token(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        tokens_minus_one = sub_uint(TOTAL_TOKENS, to_uint(1))

        # burn last token
        await signer.send_transaction(
            account, erc721.contract_address, 'burn', [
                *TOKENS[4]]
        )

        execution_info = await erc721.totalSupply().execute()
        assert execution_info.result == (tokens_minus_one,)

        for i in range(0, 4):
            execution_info = await erc721.tokenByIndex(to_uint(i)).execute()
            assert execution_info.result == (TOKENS[i],)

        await assert_revert(
            erc721.tokenByIndex(tokens_minus_one).execute(),
            reverted_with="ERC721Enumerable: global index out of bounds"
        )


    @pytest.mark.asyncio
    async def test_tokenByIndex_burn_first_token(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        # burn first token
        await signer.send_transaction(
            account, erc721.contract_address, 'burn', [
                *TOKENS[0]]
        )

        # TOKEN[0] should be burnt and TOKEN[4] should be swapped
        # to TOKEN[0]'s index
        new_token_order = [TOKENS[4], TOKENS[1], TOKENS[2], TOKENS[3]]
        for i in range(0, 3):
            execution_info = await erc721.tokenByIndex(to_uint(i)).execute()
            assert execution_info.result == (new_token_order[i],)


    @pytest.mark.asyncio
    async def test_tokenByIndex_burn_and_mint(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        for token in TOKENS:
            await signer.send_transaction(
                account, erc721.contract_address, 'burn', [
                    *token]
            )

        execution_info = await erc721.totalSupply().execute()
        assert execution_info.result == (to_uint(0),)

        await assert_revert(
            erc721.tokenByIndex(to_uint(0)).execute(),
            reverted_with="ERC721Enumerable: global index out of bounds"
        )

        # mint new tokens
        for token in TOKENS:
            await signer.send_transaction(
                account, erc721.contract_address, 'mint', [
                    account.contract_address, *token]
            )

        for i in range(0, len(TOKENS)):
            execution_info = await erc721.tokenByIndex(to_uint(i)).execute()
            assert execution_info.result == (TOKENS[i],)

    #
    # mint
    #

    @pytest.mark.asyncio
    async def test_mint_emits_event(self, contract_factory):
        erc721, account, _, _, _ = contract_factory

        # mint token to account
        tx_exec_info = await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                account.contract_address, *TOKEN]
        )

        assert_event_emitted(
            tx_exec_info,
            from_address=erc721.contract_address,
            name='Transfer',
            data=[
                ZERO_ADDRESS,
                account.contract_address,
                *TOKEN
            ]
        )


    @pytest.mark.asyncio
    async def test_mint(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        # checks balance
        execution_info = await erc721.balanceOf(account.contract_address).execute()
        assert execution_info.result == (to_uint(5),)

        # checks that account owns correct tokens
        for token in TOKENS:
            execution_info = await erc721.ownerOf(token).execute()
            assert execution_info.result == (account.contract_address,)


    @pytest.mark.asyncio
    async def test_mint_duplicate_token_id(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        # minting duplicate token_id should fail
        await assert_revert(signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                account.contract_address,
                *TOKEN
            ]),
            reverted_with="ERC721: token already minted"
        )


    @pytest.mark.asyncio
    async def test_mint_to_zero_address(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        # minting to zero address should fail
        await assert_revert(signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                ZERO_ADDRESS,
                *NONEXISTENT_TOKEN
            ]),
            reverted_with="ERC721: balance query for the zero address"
        )


    @pytest.mark.asyncio
    async def test_mint_approve_should_be_zero_address(self, erc721_minted):
        erc721, *_ = erc721_minted

        # approved address should be zero for newly minted tokens
        for token in TOKENS:
            execution_info = await erc721.getApproved(token).execute()
            assert execution_info.result == (0,)


    @pytest.mark.asyncio
    async def test_mint_by_not_owner(self, contract_factory):
        erc721, _, not_owner, _, _ = contract_factory

        # minting from not_owner should fail
        await assert_revert(signer.send_transaction(
            not_owner, erc721.contract_address, 'mint', [
                not_owner.contract_address,
                *TOKENS[0]
            ]),
            reverted_with="Ownable: caller is not the owner"
        )


    #
    # burn
    #


    @pytest.mark.asyncio
    async def test_burn(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        execution_info = await erc721.balanceOf(account.contract_address).execute()
        previous_balance = execution_info.result.balance

        # burn token
        await signer.send_transaction(
            account, erc721.contract_address, 'burn', [*TOKEN]
        )

        # account balance should subtract one
        execution_info = await erc721.balanceOf(account.contract_address).execute()
        assert execution_info.result.balance == sub_uint(
            previous_balance, to_uint(1)
        )

        # approve should be cleared to zero, therefore,
        # 'getApproved()' call should fail
        await assert_revert(
            erc721.getApproved(TOKEN).execute(),
            reverted_with="ERC721: approved query for nonexistent token"
        )

        # 'token_to_burn' owner should be zero; therefore,
        # 'ownerOf()' call should fail
        await assert_revert(
            erc721.ownerOf(TOKEN).execute(),
            reverted_with="ERC721: owner query for nonexistent token"
        )


    @pytest.mark.asyncio
    async def test_burn_emits_event(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        # mint token to account
        tx_exec_info = await signer.send_transaction(
            account, erc721.contract_address, 'burn', [
                *TOKEN
            ]
        )

        # events
        assert_events_emitted(
            tx_exec_info,
            [
                [0, erc721.contract_address, 'Approval', [
                    account.contract_address, ZERO_ADDRESS, *TOKEN]],
                [1, erc721.contract_address, 'Transfer', [
                    account.contract_address, ZERO_ADDRESS, *TOKEN]]
            ]
        )


    @pytest.mark.asyncio
    async def test_burn_nonexistent_token(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        await assert_revert(signer.send_transaction(
            account, erc721.contract_address, 'burn', [
                *NONEXISTENT_TOKEN
            ]),
            reverted_with="ERC721: owner query for nonexistent token"
        )


    @pytest.mark.asyncio
    async def test_burn_unowned_token(self, erc721_minted):
        erc721, account, other, *_ = erc721_minted

        # other should not be able to burn account's token
        await assert_revert(
            signer.send_transaction(
                other, erc721.contract_address, 'burn', [*TOKEN]
            ),
            reverted_with="ERC721: caller is not the token owner"
        )

        # account can burn their own token
        await signer.send_transaction(
            account, erc721.contract_address, 'burn', [*TOKEN]
        )


    @pytest.mark.asyncio
    async def test_burn_from_zero_address(self, erc721_minted):
        erc721, *_ = erc721_minted

        await assert_revert(
            erc721.burn(TOKEN).execute(),
            reverted_with="ERC721: caller is not the token owner"
        )
