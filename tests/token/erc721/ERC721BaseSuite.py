import pytest
from signers import MockSigner
from utils import (
    str_to_felt, ZERO_ADDRESS, TRUE, FALSE, assert_revert, INVALID_UINT256,
    assert_event_emitted, assert_events_emitted, to_uint, sub_uint, add_uint,
)


signer = MockSigner(123456789987654321)

NAME = str_to_felt("Non-fungible Token")
SYMBOL = str_to_felt("NFT")
NONEXISTENT_TOKEN = to_uint(999)
# random token IDs
TOKENS = [to_uint(5042), to_uint(793)]
# test token
TOKEN = TOKENS[0]
# random user address
RECIPIENT = 555
# random data (mimicking bytes in Solidity)
DATA = [0x42, 0x89, 0x55]
# random URIs
SAMPLE_URI_1 = str_to_felt('mock://mytoken.v1')
SAMPLE_URI_2 = str_to_felt('mock://mytoken.v2')

# selector ids
IERC165_ID = 0x01ffc9a7
IERC721_ID = 0x80ac58cd
IERC721_METADATA_ID = 0x5b5e139f
INVALID_ID = 0xffffffff
UNSUPPORTED_ID = 0xabcd1234


class ERC721Base:
    #
    # constructor
    #

    @pytest.mark.asyncio
    async def test_constructor(self, contract_factory):
        erc721, _, _, _, _ = contract_factory
        execution_info = await erc721.name().execute()
        assert execution_info.result == (NAME,)

        execution_info = await erc721.symbol().execute()
        assert execution_info.result == (SYMBOL,)
    #
    # supportsInterface
    #

    @pytest.mark.asyncio
    @pytest.mark.parametrize('interface_id, result', [
        [IERC165_ID, TRUE],
        [IERC721_ID, TRUE],
        [IERC721_METADATA_ID, TRUE],
        [INVALID_ID, FALSE],
        [UNSUPPORTED_ID, FALSE],
    ])
    async def test_supportsInterface(self, contract_factory, interface_id, result):
        erc721, _, _, _, _ = contract_factory

        execution_info = await erc721.supportsInterface(interface_id).execute()
        assert execution_info.result == (result,)


    #
    # balanceOf
    #


    @pytest.mark.asyncio
    async def test_balanceOf(self, contract_factory):
        erc721, account, _, _, _ = contract_factory

        # mint tokens to account
        for token in TOKENS:
            await signer.send_transaction(
                account, erc721.contract_address, 'mint', [
                    account.contract_address, *token]
            )

        execution_info = await erc721.balanceOf(account.contract_address).execute()
        n_tokens = len(TOKENS)
        assert execution_info.result == (to_uint(n_tokens),)

        # user should have zero tokens
        execution_info = await erc721.balanceOf(RECIPIENT).execute()
        assert execution_info.result == (to_uint(0),)


    @pytest.mark.asyncio
    async def test_balanceOf_zero_address(self, contract_factory):
        erc721, account, _, _, _ = contract_factory

        # mint tokens to account
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                account.contract_address, *TOKEN]
        )

        # should revert when querying zero address
        await assert_revert(
            erc721.balanceOf(ZERO_ADDRESS).execute(),
            reverted_with="ERC721: balance query for the zero address"
        )


    #
    # ownerOf
    #


    @pytest.mark.asyncio
    async def test_ownerOf(self, contract_factory):
        erc721, account, _, _, _ = contract_factory

        # mint tokens to account
        for token in TOKENS:
            await signer.send_transaction(
                account, erc721.contract_address, 'mint', [
                    account.contract_address, *token]
            )

            # should return account's address
            execution_info = await erc721.ownerOf(token).execute()
            assert execution_info.result == (account.contract_address,)


    @pytest.mark.asyncio
    async def test_ownerOf_nonexistent_token(self, contract_factory):
        erc721, account, _, _, _ = contract_factory

        # mint token to account
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                account.contract_address, *TOKEN]
        )

        # should revert when querying nonexistent token
        await assert_revert(
            erc721.ownerOf(NONEXISTENT_TOKEN).execute(),
            reverted_with="ERC721: owner query for nonexistent token"
        )


    @pytest.mark.asyncio
    async def test_ownerOf_invalid_uint256(self, contract_factory):
        erc721, _, _, _, _ = contract_factory

        # should revert when querying nonexistent token
        await assert_revert(
            erc721.ownerOf(INVALID_UINT256).execute(),
            reverted_with="ERC721: token_id is not a valid Uint256"
        )


    #
    # approve
    #


    @pytest.mark.asyncio
    async def test_approve(self, erc721_minted):
        erc721, account, spender, *_ = erc721_minted

        await signer.send_transaction(
            account, erc721.contract_address, 'approve', [
                spender.contract_address, *TOKEN]
        )

        execution_info = await erc721.getApproved(TOKEN).execute()
        assert execution_info.result == (spender.contract_address,)


    @pytest.mark.asyncio
    async def test_approve_emits_event(self, erc721_minted):
        erc721, account, spender, *_ = erc721_minted

        # mint token to account
        tx_exec_info = await signer.send_transaction(
            account, erc721.contract_address, 'approve', [
                spender.contract_address,
                *TOKEN
            ]
        )

        assert_event_emitted(
            tx_exec_info,
            from_address=erc721.contract_address,
            name='Approval',
            data=[
                account.contract_address,
                spender.contract_address,
                *TOKEN
            ]
        )


    @pytest.mark.asyncio
    async def test_approve_on_setApprovalForAll(self, erc721_minted):
        erc721, account, spender, *_ = erc721_minted

        # set approval_for_all from account to spender
        await signer.send_transaction(
            account, erc721.contract_address, 'setApprovalForAll', [
                spender.contract_address, TRUE]
        )

        # approve spender to spend account's token to recipient
        await signer.send_transaction(
            spender, erc721.contract_address, 'approve', [
                RECIPIENT, *TOKEN]
        )

        execution_info = await erc721.getApproved(TOKEN).execute()
        assert execution_info.result == (RECIPIENT,)


    @pytest.mark.asyncio
    async def test_approve_from_zero_address(self, erc721_minted):
        erc721, _, spender, *_ = erc721_minted

        # Without using an account abstraction, the caller address
        # (get_caller_address) is zero
        await assert_revert(
            erc721.approve(
                spender.contract_address, TOKEN).execute(),
            reverted_with="ERC721: cannot approve from the zero address"
        )


    @pytest.mark.asyncio
    async def test_approve_owner_is_recipient(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        # should fail when owner is the same as address-to-be-approved
        await assert_revert(
            signer.send_transaction(
                account, erc721.contract_address, 'approve', [
                    account.contract_address,
                    *TOKEN
                ]),
            reverted_with="ERC721: approval to current owner"
        )


    @pytest.mark.asyncio
    async def test_approve_not_owner_or_operator(self, contract_factory):
        erc721, account, spender, _, _ = contract_factory

        # mint to recipient — NOT account
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                RECIPIENT, *TOKEN]
        )

        # 'approve' should fail since recipient owns token
        await assert_revert(signer.send_transaction(
            account, erc721.contract_address, 'approve', [
                spender.contract_address,
                *TOKEN
            ]),
            reverted_with="ERC721: approve caller is not owner nor approved for all"
        )


    @pytest.mark.asyncio
    async def test_approve_on_already_approved(self, erc721_minted):
        erc721, account, spender, *_ = erc721_minted

        # first approval
        await signer.send_transaction(
            account, erc721.contract_address, 'approve', [
                spender.contract_address, *TOKEN]
        )

        # repeat approval
        await signer.send_transaction(
            account, erc721.contract_address, 'approve', [
                spender.contract_address, *TOKEN]
        )

        # check that approval does not change
        execution_info = await erc721.getApproved(TOKEN).execute()
        assert execution_info.result == (spender.contract_address,)


    @pytest.mark.asyncio
    async def test_getApproved_nonexistent_token(self, erc721_minted):
        erc721, *_ = erc721_minted

        await assert_revert(
            erc721.getApproved(NONEXISTENT_TOKEN).execute(),
            reverted_with="ERC721: approved query for nonexistent token"
        )


    @pytest.mark.asyncio
    async def test_getApproved_invalid_uint256(self, erc721_minted):
        erc721, *_ = erc721_minted

        await assert_revert(
            erc721.getApproved(INVALID_UINT256).execute(),
            reverted_with="ERC721: token_id is not a valid Uint256"
        )


    #
    # setApprovalForAll
    #


    @pytest.mark.asyncio
    async def test_setApprovalForAll(self, erc721_minted):
        erc721, account, spender, *_ = erc721_minted

        await signer.send_transaction(
            account, erc721.contract_address, 'setApprovalForAll', [
                spender.contract_address, TRUE]
        )

        execution_info = await erc721.isApprovedForAll(
            account.contract_address, spender.contract_address).execute()
        assert execution_info.result == (TRUE,)


    @pytest.mark.asyncio
    async def test_setApprovalForAll_emits_event(self, erc721_minted):
        erc721, account, spender, *_ = erc721_minted

        tx_exec_info = await signer.send_transaction(
            account, erc721.contract_address, 'setApprovalForAll', [
                spender.contract_address, TRUE]
        )

        assert_event_emitted(
            tx_exec_info,
            from_address=erc721.contract_address,
            name='ApprovalForAll',
            data=[
                account.contract_address,
                spender.contract_address,
                TRUE
            ]
        )


    @pytest.mark.asyncio
    async def test_setApprovalForAll_when_operator_was_set_as_not_approved(self, erc721_minted):
        erc721, account, spender, *_ = erc721_minted

        await signer.send_transaction(
            account, erc721.contract_address, 'setApprovalForAll', [
                spender.contract_address, FALSE]
        )

        await signer.send_transaction(
            account, erc721.contract_address, 'setApprovalForAll', [
                spender.contract_address, TRUE]
        )

        execution_info = await erc721.isApprovedForAll(
            account.contract_address, spender.contract_address).execute()
        assert execution_info.result == (TRUE,)


    @pytest.mark.asyncio
    async def test_setApprovalForAll_with_invalid_bool_arg(self, erc721_minted):
        erc721, account, spender, *_ = erc721_minted

        not_bool = 2

        await assert_revert(
            signer.send_transaction(
                account, erc721.contract_address, 'setApprovalForAll', [
                    spender.contract_address,
                    not_bool
                ]),
            reverted_with="ERC721: approved is not a Cairo boolean")


    @pytest.mark.asyncio
    async def test_setApprovalForAll_owner_is_operator(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        await assert_revert(
            signer.send_transaction(
                account, erc721.contract_address, 'setApprovalForAll', [
                    account.contract_address,
                    TRUE
                ]),
            reverted_with="ERC721: approve to caller"
        )


    @pytest.mark.asyncio
    async def test_setApprovalForAll_from_zero_address(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        await assert_revert(
            erc721.setApprovalForAll(account.contract_address, TRUE).execute(),
            reverted_with="ERC721: either the caller or operator is the zero address"
        )


    @pytest.mark.asyncio
    async def test_setApprovalForAll_operator_is_zero_address(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        await assert_revert(
            signer.send_transaction(
                account, erc721.contract_address, 'setApprovalForAll', [
                    ZERO_ADDRESS,
                    TRUE
                ]),
            reverted_with="ERC721: either the caller or operator is the zero address"
        )


    #
    # transferFrom
    #


    @pytest.mark.asyncio
    async def test_transferFrom_owner(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        # get account's previous balance
        execution_info = await erc721.balanceOf(account.contract_address).execute()
        previous_balance = execution_info.result.balance

        # transfers token from account to recipient
        await signer.send_transaction(
            account, erc721.contract_address, 'transferFrom', [
                account.contract_address, RECIPIENT, *TOKEN]
        )

        # checks recipient balance
        execution_info = await erc721.balanceOf(RECIPIENT).execute()
        assert execution_info.result == (to_uint(1),)

        # checks account balance
        execution_info = await erc721.balanceOf(account.contract_address).execute()
        assert execution_info.result.balance == sub_uint(
            previous_balance, to_uint(1))

        # checks token has new owner
        execution_info = await erc721.ownerOf(TOKEN).execute()
        assert execution_info.result == (RECIPIENT,)

        # checks approval is cleared for token_id
        execution_info = await erc721.getApproved(TOKEN).execute()
        assert execution_info.result == (0,)


    @pytest.mark.asyncio
    async def test_transferFrom_emits_events(self, erc721_minted):
        erc721, account, spender, *_ = erc721_minted

        # setApprovalForAll
        await signer.send_transaction(
            account, erc721.contract_address, 'setApprovalForAll', [
                spender.contract_address, TRUE]
        )

        # spender transfers token from account to recipient
        tx_exec_info = await signer.send_transaction(
            spender, erc721.contract_address, 'transferFrom', [
                account.contract_address,
                RECIPIENT,
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
                    account.contract_address, RECIPIENT, *TOKEN]]
            ]
        )


    @pytest.mark.asyncio
    async def test_transferFrom_approved_user(self, erc721_minted):
        erc721, account, spender, *_ = erc721_minted

        # approve spender
        await signer.send_transaction(
            account, erc721.contract_address, 'approve', [
                spender.contract_address, *TOKEN]
        )

        # spender transfers token from account to recipient
        await signer.send_transaction(
            spender, erc721.contract_address, 'transferFrom', [
                account.contract_address, RECIPIENT, *TOKEN]
        )

        # checks user balance
        execution_info = await erc721.balanceOf(RECIPIENT).execute()
        assert execution_info.result == (to_uint(1),)


    @pytest.mark.asyncio
    async def test_transferFrom_operator(self, erc721_minted):
        erc721, account, spender, *_ = erc721_minted

        # setApprovalForAll
        await signer.send_transaction(
            account, erc721.contract_address, 'setApprovalForAll', [
                spender.contract_address, TRUE]
        )

        # spender transfers token from account to recipient
        await signer.send_transaction(
            spender, erc721.contract_address, 'transferFrom', [
                account.contract_address, RECIPIENT, *TOKEN]
        )

        # checks user balance
        execution_info = await erc721.balanceOf(RECIPIENT).execute()
        assert execution_info.result == (to_uint(1),)


    @pytest.mark.asyncio
    async def test_transferFrom_when_not_approved_or_owner(self, erc721_minted):
        erc721, account, spender, *_ = erc721_minted

        # setApprovalForAll to false
        await signer.send_transaction(
            account, erc721.contract_address, 'setApprovalForAll', [
                spender.contract_address, FALSE]
        )

        # should be rejected when not approved
        await assert_revert(signer.send_transaction(
            spender, erc721.contract_address, 'transferFrom', [
                account.contract_address,
                RECIPIENT,
                *TOKEN
            ]),
            reverted_with="ERC721: either is not approved or the caller is the zero address"
        )


    @pytest.mark.asyncio
    async def test_transferFrom_to_zero_address(self, erc721_minted):
        erc721, account, spender, *_ = erc721_minted

        # setApprovalForAll
        await signer.send_transaction(
            account, erc721.contract_address, 'setApprovalForAll', [
                spender.contract_address, TRUE]
        )

        try:
            # erc721
            await assert_revert(signer.send_transaction(
                spender, erc721.contract_address, 'transferFrom', [
                    account.contract_address,
                    ZERO_ADDRESS,
                    *TOKEN
                ]),
                reverted_with="ERC721: cannot transfer to the zero address"
            )
        except AssertionError:
            # erc721 enumerable
            await assert_revert(signer.send_transaction(
                spender, erc721.contract_address, 'transferFrom', [
                    account.contract_address,
                    ZERO_ADDRESS,
                    *TOKEN
                ]),
                reverted_with="ERC721: balance query for the zero address"
            )


    @pytest.mark.asyncio
    async def test_transferFrom_invalid_uint256(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        await assert_revert(
            signer.send_transaction(
                account, erc721.contract_address, 'transferFrom', [
                    account.contract_address,
                    RECIPIENT,
                    *INVALID_UINT256
                ]),
            reverted_with="ERC721: token_id is not a valid Uint256"
        )


    @pytest.mark.asyncio
    async def test_transferFrom_from_zero_address(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        # caller address is `0` when not using an account contract
        await assert_revert(
            erc721.transferFrom(
                account.contract_address,
                RECIPIENT,
                TOKEN
            ).execute(),
            reverted_with="ERC721: either is not approved or the caller is the zero address"
        )


    #
    # safeTransferFrom
    #


    @pytest.mark.asyncio
    async def test_safeTransferFrom(self, erc721_minted):
        erc721, account, _, erc721_holder, _ = erc721_minted

        await signer.send_transaction(
            account, erc721.contract_address, 'safeTransferFrom', [
                account.contract_address,
                erc721_holder.contract_address,
                *TOKEN,
                len(DATA),
                *DATA
            ]
        )

        # check balance
        execution_info = await erc721.balanceOf(erc721_holder.contract_address).execute()
        assert execution_info.result == (to_uint(1),)

        # check owner
        execution_info = await erc721.ownerOf(TOKEN).execute()
        assert execution_info.result == (erc721_holder.contract_address,)


    @pytest.mark.asyncio
    async def test_safeTransferFrom_emits_events(self, erc721_minted):
        erc721, account, _, erc721_holder, _ = erc721_minted

        tx_exec_info = await signer.send_transaction(
            account, erc721.contract_address, 'safeTransferFrom', [
                account.contract_address,
                erc721_holder.contract_address,
                *TOKEN,
                len(DATA),
                *DATA
            ]
        )


        # events
        assert_events_emitted(
            tx_exec_info,
            [
                [0, erc721.contract_address, 'Approval', [
                    account.contract_address, ZERO_ADDRESS, *TOKEN]],
                [1, erc721.contract_address, 'Transfer', [
                    account.contract_address, erc721_holder.contract_address, *TOKEN]]
            ]
        )


    @pytest.mark.asyncio
    async def test_safeTransferFrom_from_approved(self, erc721_minted):
        erc721, account, spender, erc721_holder, _ = erc721_minted

        execution_info = await erc721.balanceOf(erc721_holder.contract_address).execute()
        previous_balance = execution_info.result.balance

        # approve spender
        await signer.send_transaction(
            account, erc721.contract_address, 'approve', [
                spender.contract_address, *TOKEN]
        )

        # spender transfers token from account to erc721_holder
        await signer.send_transaction(
            spender, erc721.contract_address, 'safeTransferFrom', [
                account.contract_address,
                erc721_holder.contract_address,
                *TOKEN,
                len(DATA),
                *DATA
            ]
        )

        # erc721_holder balance check
        execution_info = await erc721.balanceOf(erc721_holder.contract_address).execute()
        assert execution_info.result.balance == add_uint(
            previous_balance, to_uint(1)
        )


    @pytest.mark.asyncio
    async def test_safeTransferFrom_from_operator(self, erc721_minted):
        erc721, account, spender, erc721_holder, _ = erc721_minted

        execution_info = await erc721.balanceOf(erc721_holder.contract_address).execute()
        previous_balance = execution_info.result.balance

        # setApprovalForAll
        await signer.send_transaction(
            account, erc721.contract_address, 'setApprovalForAll', [
                spender.contract_address, TRUE]
        )

        # spender transfers token from account to erc721_holder
        await signer.send_transaction(
            spender, erc721.contract_address, 'safeTransferFrom', [
                account.contract_address,
                erc721_holder.contract_address,
                *TOKEN,
                len(DATA),
                *DATA
            ]
        )

        # erc721_holder balance check
        execution_info = await erc721.balanceOf(erc721_holder.contract_address).execute()
        assert execution_info.result.balance == add_uint(
            previous_balance, to_uint(1)
        )


    @pytest.mark.asyncio
    async def test_safeTransferFrom_when_not_approved_or_owner(self, erc721_minted):
        erc721, account, spender, erc721_holder, _ = erc721_minted

        # should fail when not approved or owner
        await assert_revert(signer.send_transaction(
            spender, erc721.contract_address, 'safeTransferFrom', [
                account.contract_address,
                erc721_holder.contract_address,
                *TOKEN,
                len(DATA),
                *DATA
            ]),
            reverted_with="ERC721: either is not approved or the caller is the zero address"
        )


    @pytest.mark.asyncio
    async def test_safeTransferFrom_to_zero_address(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        # to zero address should be rejected
        try:
            await assert_revert(signer.send_transaction(
                account, erc721.contract_address, 'safeTransferFrom', [
                    account.contract_address,
                    ZERO_ADDRESS,
                    *TOKEN,
                    len(DATA),
                    *DATA
                ]),
                reverted_with="ERC721: cannot transfer to the zero address"
            )
        except AssertionError:
            await assert_revert(signer.send_transaction(
                account, erc721.contract_address, 'safeTransferFrom', [
                    account.contract_address,
                    ZERO_ADDRESS,
                    *TOKEN,
                    len(DATA),
                    *DATA
                ]),
                reverted_with="ERC721: balance query for the zero address"
            )


    @pytest.mark.asyncio
    async def test_safeTransferFrom_from_zero_address(self, erc721_minted):
        erc721, account, _, erc721_holder, _ = erc721_minted

        # caller address is `0` when not using an account contract
        await assert_revert(
            erc721.safeTransferFrom(
                account.contract_address,
                erc721_holder.contract_address,
                TOKEN,
                DATA
            ).execute(),
            reverted_with="ERC721: either is not approved or the caller is the zero address"
        )


    @pytest.mark.asyncio
    async def test_safeTransferFrom_to_unsupported_contract(self, erc721_minted):
        erc721, account, _, _, unsupported = erc721_minted

        await assert_revert(
            signer.send_transaction(
                account, erc721.contract_address, 'safeTransferFrom', [
                    account.contract_address,
                    unsupported.contract_address,
                    *TOKEN,
                    len(DATA),
                    *DATA,
                ])
        )


    @pytest.mark.asyncio
    async def test_safeTransferFrom_to_account(self, erc721_minted):
        erc721, account, account2, *_ = erc721_minted

        await signer.send_transaction(
            account, erc721.contract_address, 'safeTransferFrom', [
                account.contract_address,
                account2.contract_address,
                *TOKEN,
                len(DATA),
                *DATA
            ]
        )

        # check balance
        execution_info = await erc721.balanceOf(account2.contract_address).execute()
        assert execution_info.result == (to_uint(1),)

        # check owner
        execution_info = await erc721.ownerOf(TOKEN).execute()
        assert execution_info.result == (account2.contract_address,)


    @pytest.mark.asyncio
    async def test_safeTransferFrom_invalid_uint256(self, erc721_minted):
        erc721, account, _, erc721_holder, _ = erc721_minted

        await assert_revert(
            signer.send_transaction(
                account, erc721.contract_address, 'safeTransferFrom', [
                    account.contract_address,
                    erc721_holder.contract_address,
                    *INVALID_UINT256,
                    len(DATA),
                    *DATA
                ]),
            reverted_with="ERC721: token_id is not a valid Uint256"
        )


    #
    # tokenURI
    #


    @pytest.mark.asyncio
    async def test_tokenURI(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        token_1 = TOKENS[0]
        token_2 = TOKENS[1]

        # should be zero when tokenURI is not set
        execution_info = await erc721.tokenURI(token_1).execute()
        assert execution_info.result == (0,)

        # setTokenURI for token_1
        await signer.send_transaction(
            account, erc721.contract_address, 'setTokenURI', [
                *token_1,
                SAMPLE_URI_1
            ]
        )

        execution_info = await erc721.tokenURI(token_1).execute()
        assert execution_info.result == (SAMPLE_URI_1,)

        # setTokenURI for token_2
        await signer.send_transaction(
            account, erc721.contract_address, 'setTokenURI', [
                *token_2,
                SAMPLE_URI_2
            ]
        )

        execution_info = await erc721.tokenURI(token_2).execute()
        assert execution_info.result == (SAMPLE_URI_2,)


    @pytest.mark.asyncio
    async def test_tokenURI_should_revert_for_nonexistent_token(self, erc721_minted):
        erc721, *_ = erc721_minted

        # should revert for nonexistent token
        await assert_revert(
            erc721.tokenURI(NONEXISTENT_TOKEN).execute(),
            reverted_with="ERC721_Metadata: URI query for nonexistent token"
        )


    @pytest.mark.asyncio
    async def test_setTokenURI_from_not_owner(self, erc721_minted):
        erc721, _, not_owner, *_ = erc721_minted

        await assert_revert(signer.send_transaction(
            not_owner, erc721.contract_address, 'setTokenURI', [
                *TOKEN,
                SAMPLE_URI_1
            ]),
            reverted_with="Ownable: caller is not the owner"
        )


    @pytest.mark.asyncio
    async def test_setTokenURI_for_nonexistent_token(self, erc721_minted):
        erc721, _, not_owner, *_ = erc721_minted

        await assert_revert(signer.send_transaction(
            not_owner, erc721.contract_address, 'setTokenURI', [
                *NONEXISTENT_TOKEN,
                SAMPLE_URI_1
            ]),
            reverted_with="Ownable: caller is not the owner"
        )
