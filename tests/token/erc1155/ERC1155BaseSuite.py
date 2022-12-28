import pytest
from signers import MockSigner
from utils import assert_event_emitted

from nile.utils import (
    MAX_UINT256, ZERO_ADDRESS, INVALID_UINT256, TRUE, FALSE,
    to_uint, add_uint, sub_uint, assert_revert, str_to_felt
)

signer = MockSigner(123456789987654321)

#
# Helpers
#


def to_uint_array(arr):
    return list(map(to_uint, arr))


def prepare_calldata(arr):
    """Flatten an array of tuples or an array of ints."""
    # [5, 5, 5]        => [3, 5, 5, 5]
    # [(1, 2), (3, 4)] => [2, 1, 2, 3, 4]
    res = [len(arr)]
    if res[0] == 0:
        return res
    if type(arr[0]) == int:
        return res + arr
    if type(arr[0]) == tuple:
        for elem in arr:
            res += [*elem]
        return res
    raise Exception

#
# Constants
#

NOT_BOOLEAN = 3
ACCOUNT = 123
TOKEN_ID = to_uint(111)
MINT_VALUE = to_uint(1000)
TRANSFER_VALUE = to_uint(500)

ACCOUNTS = [123, 234, 345]
TOKEN_IDS = [TOKEN_ID, to_uint(222), to_uint(333)]
MINT_VALUES = [MINT_VALUE, to_uint(2000), to_uint(3000)]
TRANSFER_VALUES = [TRANSFER_VALUE, to_uint(1000), to_uint(1500)]
TRANSFER_DIFFERENCES = [sub_uint(m, t)
                        for m, t in zip(MINT_VALUES, TRANSFER_VALUES)]
MAX_UINT_VALUES = [to_uint(1), MAX_UINT256, to_uint(1)]
INVALID_VALUES = [to_uint(1), (MAX_UINT256[0]+1, MAX_UINT256[1]), to_uint(1)]
INVALID_IDS = [to_uint(111),INVALID_UINT256,to_uint(333)]

DEFAULT_URI = str_to_felt('mock://mytoken.v1')
NEW_URI = str_to_felt('mock://mytoken.v2')

DATA = 0
REJECT_DATA = [1, 0]

IERC165_ID = int('0x01ffc9a7', 16)
IERC1155_ID = int('0xd9b67a26', 16)
IERC1155_MetadataURI = int('0x0e89341c', 16)
ERC165_UNSUPPORTED = int('0xffffffff', 16)
UNSUPPORTED_ID = int('0xaabbccdd', 16)

SUPPORTED_INTERFACES = [IERC165_ID, IERC1155_ID, IERC1155_MetadataURI]
UNSUPPORTED_INTERFACES = [ERC165_UNSUPPORTED, UNSUPPORTED_ID]


class ERC1155Base:
    #
    # Constructor
    #


    @pytest.mark.asyncio
    async def test_constructor(self, contract_factory):
        erc1155, _, _, _ = contract_factory

        execution_info = await erc1155.uri(TOKEN_ID).execute()
        assert execution_info.result.uri == DEFAULT_URI

    #
    # ERC165
    #


    @pytest.mark.asyncio
    @pytest.mark.parametrize("supported_id", SUPPORTED_INTERFACES)
    async def test_supports_interface(self, contract_factory, supported_id):
        erc1155, _, _, _ = contract_factory

        execution_info = await erc1155.supportsInterface(supported_id).execute()
        assert execution_info.result.success == TRUE


    @pytest.mark.asyncio
    @pytest.mark.parametrize("unsupported_id", UNSUPPORTED_INTERFACES)
    async def test_supports_interface_unsupported(self, contract_factory, unsupported_id):
        erc1155, _, _, _ = contract_factory

        execution_info = await erc1155.supportsInterface(unsupported_id).execute()
        assert execution_info.result.success == FALSE

    #
    # Set/Get approval
    #


    @pytest.mark.asyncio
    async def test_set_approval_for_all(self, contract_factory):
        erc1155, account, _, _ = contract_factory

        approver = account.contract_address

        # Set approval
        await signer.send_transaction(
            account, erc1155.contract_address, 'setApprovalForAll',
            [ACCOUNT, TRUE]
        )

        execution_info = await erc1155.isApprovedForAll(
            approver, ACCOUNT).execute()

        assert execution_info.result.approved == TRUE

        # Unset approval
        await signer.send_transaction(
            account, erc1155.contract_address, 'setApprovalForAll',
            [ACCOUNT, FALSE]
        )

        execution_info = await erc1155.isApprovedForAll(
            approver, ACCOUNT).execute()

        assert execution_info.result.approved == FALSE


    @pytest.mark.asyncio
    @pytest.mark.parametrize("approval", [TRUE, FALSE])
    async def test_set_approval_for_all_emits_event(self, contract_factory, approval):
        erc1155, account, _, _ = contract_factory

        execution_info = await signer.send_transaction(
            account, erc1155.contract_address, 'setApprovalForAll',
            [ACCOUNT, approval]
        )
        assert_event_emitted(
            execution_info,
            from_address=erc1155.contract_address,
            name='ApprovalForAll',
            data=[
                account.contract_address,
                ACCOUNT,
                approval
            ]
        )


    @pytest.mark.asyncio
    async def test_set_approval_for_all_non_boolean(self, contract_factory):
        erc1155, account, _, _ = contract_factory

        await assert_revert(signer.send_transaction(
            account, erc1155.contract_address, 'setApprovalForAll',
            [ACCOUNT, NOT_BOOLEAN]), 
            "ERC1155: approval is not boolean")


    @pytest.mark.asyncio
    async def test_set_approval_for_all_self(self, contract_factory):
        erc1155, account, _, _ = contract_factory

        approvee = account.contract_address

        # Set approval
        await assert_revert(signer.send_transaction(
            account, erc1155.contract_address, 'setApprovalForAll',
            [approvee, TRUE]),
            "ERC1155: setting approval status for self")


    @pytest.mark.asyncio
    async def test_set_approval_for_all_zero_address(self, contract_factory):
        erc1155, account, _, _ = contract_factory

        # Set approval
        await assert_revert(signer.send_transaction(
            account, erc1155.contract_address, 'setApprovalForAll',
            [ZERO_ADDRESS, TRUE]),
            "ERC1155: setting approval status for zero address")

    #
    # Balance getters
    #


    @pytest.mark.asyncio
    async def test_balance_of(self, minted_factory):
        erc1155, _, account, _ = minted_factory

        user = account.contract_address

        execution_info = await erc1155.balanceOf(user, TOKEN_ID).execute()
        assert execution_info.result.balance == MINT_VALUE


    @pytest.mark.asyncio
    async def test_balance_of_zero_address(self, contract_factory):
        erc1155, _, _, _ = contract_factory

        await assert_revert(
            erc1155.balanceOf(ZERO_ADDRESS, TOKEN_ID).execute(),
            "ERC1155: address zero is not a valid owner")


    @pytest.mark.asyncio
    async def test_balance_of_invalid_id(self, contract_factory):
        erc1155, _, _, _ = contract_factory

        await assert_revert(
            erc1155.balanceOf(ACCOUNT, INVALID_UINT256).execute(),
            "ERC1155: token_id is not a valid Uint256")


    @pytest.mark.asyncio
    async def test_balance_of_batch(self, minted_factory):
        erc1155, _, account, _ = minted_factory

        accounts = [account.contract_address]*3

        execution_info = await erc1155.balanceOfBatch(accounts, TOKEN_IDS).execute()
        assert execution_info.result.balances == MINT_VALUES


    @pytest.mark.asyncio
    async def test_balance_of_batch_zero_address(self, contract_factory):
        erc1155, _, _, _ = contract_factory
        accounts = [ACCOUNT, ZERO_ADDRESS, ACCOUNT]

        await assert_revert(
            erc1155.balanceOfBatch(accounts, TOKEN_IDS).execute(),
            "ERC1155: address zero is not a valid owner")


    @pytest.mark.asyncio
    async def test_balance_of_batch_invalid_id(self, contract_factory):
        erc1155, _, _, _ = contract_factory

        accounts = [ACCOUNT]*3

        await assert_revert(
            erc1155.balanceOfBatch(accounts, INVALID_IDS).execute(),
            "ERC1155: token_id is not a valid Uint256")


    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "accounts,ids",
        [(ACCOUNTS[:2], TOKEN_IDS), (ACCOUNTS, TOKEN_IDS[:2])])
    async def test_balance_of_batch_uneven_arrays(self, contract_factory, accounts, ids):
        erc1155, _, _, _ = contract_factory

        await assert_revert(
            erc1155.balanceOfBatch(accounts, ids).execute(),
            "ERC1155: accounts and ids length mismatch")

    #
    # Transfer
    #


    @pytest.mark.asyncio
    async def test_safe_transfer_from(self, minted_factory):
        erc1155, account1, account2, _ = minted_factory

        sender = account2.contract_address
        recipient = account1.contract_address

        await signer.send_transaction(
            account2, erc1155.contract_address, 'safeTransferFrom',
            [sender, recipient, *TOKEN_ID, *TRANSFER_VALUE, DATA])

        execution_info = await erc1155.balanceOf(sender, TOKEN_ID).execute()
        assert execution_info.result.balance == sub_uint(
            MINT_VALUE, TRANSFER_VALUE)

        execution_info = await erc1155.balanceOf(recipient, TOKEN_ID).execute()
        assert execution_info.result.balance == TRANSFER_VALUE


    @pytest.mark.asyncio
    async def test_safe_transfer_from_emits_event(self, minted_factory):
        erc1155, account1, account2, _ = minted_factory

        sender = account2.contract_address
        recipient = account1.contract_address

        execution_info = await signer.send_transaction(
            account2, erc1155.contract_address, 'safeTransferFrom',
            [sender, recipient, *TOKEN_ID, *TRANSFER_VALUE, DATA])

        assert_event_emitted(
            execution_info,
            from_address=erc1155.contract_address,
            name='TransferSingle',
            data=[
                sender,     # operator
                sender,     # from
                recipient,  # to
                *TOKEN_ID,
                *TRANSFER_VALUE
            ]
        )


    @pytest.mark.asyncio
    async def test_safe_transfer_from_approved(self, minted_factory):
        erc1155, account1, account2, _ = minted_factory

        operator = account1.contract_address
        sender = account2.contract_address
        recipient = account1.contract_address

        # account2 approves account1
        await signer.send_transaction(
            account2, erc1155.contract_address, 'setApprovalForAll',
            [operator, TRUE])

        # account sends transaction
        await signer.send_transaction(
            account1, erc1155.contract_address, 'safeTransferFrom',
            [sender, recipient, *TOKEN_ID, *TRANSFER_VALUE, DATA])

        execution_info = await erc1155.balanceOf(sender, TOKEN_ID).execute()
        assert execution_info.result.balance == sub_uint(
            MINT_VALUE, TRANSFER_VALUE)

        execution_info = await erc1155.balanceOf(recipient, TOKEN_ID).execute()
        assert execution_info.result.balance == TRANSFER_VALUE


    @pytest.mark.asyncio
    async def test_safe_transfer_from_approved_emits_event(self, minted_factory):
        erc1155, account1, account2, _ = minted_factory

        operator = account1.contract_address
        sender = account2.contract_address
        recipient = account1.contract_address

        await signer.send_transaction(
            account2, erc1155.contract_address, 'setApprovalForAll',
            [operator, TRUE])

        # account1/operator sends transaction
        execution_info = await signer.send_transaction(
            account1, erc1155.contract_address, 'safeTransferFrom',
            [sender, recipient, *TOKEN_ID, *TRANSFER_VALUE, DATA])

        assert_event_emitted(
            execution_info,
            from_address=erc1155.contract_address,
            name='TransferSingle',
            data=[
                operator,   # operator
                sender,     # from
                recipient,  # to
                *TOKEN_ID,
                *TRANSFER_VALUE
            ]
        )


    @pytest.mark.asyncio
    async def test_safe_transfer_from_invalid_value(self, contract_factory):
        erc1155, owner, account, _ = contract_factory

        sender = account.contract_address
        recipient = owner.contract_address

        # mint max uint to avoid possible insufficient balance error
        await signer.send_transaction(
            owner, erc1155.contract_address, 'mint',
            [sender, *TOKEN_ID, *MAX_UINT256, DATA])

        await assert_revert(
            signer.send_transaction(
                account, erc1155.contract_address, 'safeTransferFrom',
                [sender, recipient, *TOKEN_ID, *INVALID_UINT256, DATA]),
            "ERC1155: value is not a valid Uint256"
        )


    @pytest.mark.asyncio
    async def test_safe_transfer_from_invalid_id(self, contract_factory):
        erc1155, owner, account, _ = contract_factory

        sender = account.contract_address
        recipient = owner.contract_address

        # transfer 0 value of invalid id to avoid
        # insufficient balance error
        await assert_revert(
            signer.send_transaction(
                account, erc1155.contract_address, 'safeTransferFrom',
                [sender, recipient, *INVALID_UINT256, *to_uint(0), DATA]),
            "ERC1155: token_id is not a valid Uint256"
        )


    @pytest.mark.asyncio
    async def test_safe_transfer_from_insufficient_balance(self, minted_factory):
        erc1155, account, account2, _ = minted_factory

        sender = account2.contract_address
        recipient = account.contract_address

        transfer_value = add_uint(MINT_VALUES[0], to_uint(1))

        await assert_revert(
            signer.send_transaction(
                account2, erc1155.contract_address, 'safeTransferFrom',
                [sender, recipient, *TOKEN_ID, *transfer_value, DATA]),
            "ERC1155: insufficient balance for transfer"
        )


    @pytest.mark.asyncio
    async def test_safe_transfer_from_unapproved(self, minted_factory):
        erc1155, account1, account2, _ = minted_factory

        sender = account2.contract_address
        recipient = account1.contract_address

        await assert_revert(signer.send_transaction(
            account1, erc1155.contract_address, 'safeTransferFrom',
            [sender, recipient, *TOKEN_ID, *TRANSFER_VALUE, DATA]),
            "ERC1155: caller is not owner nor approved")


    @pytest.mark.asyncio
    async def test_safe_transfer_from_to_zero_address(self, minted_factory):
        erc1155, _, account, _ = minted_factory

        sender = account.contract_address

        await assert_revert(signer.send_transaction(
            account, erc1155.contract_address, 'safeTransferFrom',
            [sender, ZERO_ADDRESS, *TOKEN_ID, *TRANSFER_VALUE, DATA]),
            "ERC1155: transfer to the zero address")


    @pytest.mark.asyncio
    async def test_safe_transfer_from_overflow(self, minted_factory):
        erc1155, owner, account, _ = minted_factory

        sender = account.contract_address
        recipient = owner.contract_address

        # Bring recipient's balance to max possible
        await signer.send_transaction(
            owner, erc1155.contract_address, 'mint',
            [recipient, *TOKEN_ID, *MAX_UINT256, DATA])

        # Issuing recipient any more should revert due to overflow
        await assert_revert(signer.send_transaction(
            account, erc1155.contract_address, 'safeTransferFrom',
            [sender, recipient, *TOKEN_ID, *to_uint(1), DATA]),
            "ERC1155: balance overflow")


    @pytest.mark.asyncio
    async def test_safe_transfer_from_to_receiver(self, minted_factory):
        erc1155, _, account2, receiver = minted_factory

        sender = account2.contract_address
        recipient = receiver.contract_address

        await signer.send_transaction(
            account2, erc1155.contract_address, 'safeTransferFrom',
            [sender, recipient, *TOKEN_ID, *TRANSFER_VALUE, DATA])

        execution_info = await erc1155.balanceOf(recipient, TOKEN_ID).execute()
        assert execution_info.result.balance == TRANSFER_VALUE


    @pytest.mark.asyncio
    async def test_safe_transfer_from_to_receiver_rejection(self, minted_factory):
        erc1155, _, account2, receiver = minted_factory

        sender = account2.contract_address
        recipient = receiver.contract_address

        await assert_revert(signer.send_transaction(
            account2, erc1155.contract_address, 'safeTransferFrom',
            [sender, recipient, *TOKEN_ID, *TRANSFER_VALUE, *REJECT_DATA]),
            "ERC1155: ERC1155Receiver rejected tokens")


    @pytest.mark.asyncio
    async def test_safe_transfer_from_to_non_receiver(self, minted_factory):
        erc1155, _, account, _ = minted_factory

        sender = account.contract_address
        recipient = erc1155.contract_address

        await assert_revert(signer.send_transaction(
            account, erc1155.contract_address, 'safeTransferFrom',
            [sender, recipient, *TOKEN_ID, *TRANSFER_VALUE, DATA]),
            "ERC1155: transfer to non-ERC1155Receiver implementer")


    #
    # Batch Transfers
    #


    @pytest.mark.asyncio
    async def test_safe_batch_transfer_from(self, minted_factory):
        erc1155, account1, account2, _ = minted_factory

        sender = account2.contract_address
        recipient = account1.contract_address

        await signer.send_transaction(
            account2, erc1155.contract_address, 'safeBatchTransferFrom',
            [
                sender, recipient, *prepare_calldata(TOKEN_IDS),
                *prepare_calldata(TRANSFER_VALUES), DATA
            ])

        execution_info = await erc1155.balanceOfBatch(
            [sender]*3+[recipient]*3, TOKEN_IDS*2).execute()
        assert execution_info.result.balances[:3] == TRANSFER_DIFFERENCES
        assert execution_info.result.balances[3:] == TRANSFER_VALUES


    @pytest.mark.asyncio
    async def test_safe_batch_transfer_from_emits_event(self, minted_factory):
        erc1155, account1, account2, _ = minted_factory

        sender = account2.contract_address
        recipient = account1.contract_address

        execution_info = await signer.send_transaction(
            account2, erc1155.contract_address, 'safeBatchTransferFrom',
            [
                sender, recipient, *prepare_calldata(TOKEN_IDS),
                *prepare_calldata(TRANSFER_VALUES), DATA
            ])

        assert_event_emitted(
            execution_info,
            from_address=erc1155.contract_address,
            name='TransferBatch',
            data=[
                sender,     # operator
                sender,     # from
                recipient,  # to
                *prepare_calldata(TOKEN_IDS),
                *prepare_calldata(TRANSFER_VALUES),
            ]
        )


    @pytest.mark.asyncio
    async def test_safe_batch_transfer_from_approved(self, minted_factory):
        erc1155, account1, account2, _ = minted_factory

        sender = account2.contract_address
        operator = account1.contract_address
        recipient = account1.contract_address

        await signer.send_transaction(
            account2, erc1155.contract_address, 'setApprovalForAll',
            [operator, TRUE])

        await signer.send_transaction(
            account1, erc1155.contract_address, 'safeBatchTransferFrom',
            [
                sender, recipient, *prepare_calldata(TOKEN_IDS),
                *prepare_calldata(TRANSFER_VALUES), DATA
            ])

        execution_info = await erc1155.balanceOfBatch(
            [sender]*3+[recipient]*3, TOKEN_IDS*2).execute()
        assert execution_info.result.balances[:3] == TRANSFER_DIFFERENCES
        assert execution_info.result.balances[3:] == TRANSFER_VALUES


    @pytest.mark.asyncio
    async def test_safe_batch_transfer_from_approved_emits_event(self, 
            minted_factory):
        erc1155, account1, account2, receiver = minted_factory

        sender = account2.contract_address
        operator = account1.contract_address
        recipient = receiver.contract_address

        await signer.send_transaction(
            account2, erc1155.contract_address, 'setApprovalForAll',
            [operator, TRUE])

        execution_info = await signer.send_transaction(
            account1, erc1155.contract_address, 'safeBatchTransferFrom',
            [
                sender, recipient, *prepare_calldata(TOKEN_IDS),
                *prepare_calldata(TRANSFER_VALUES), DATA
            ])

        assert_event_emitted(
            execution_info,
            from_address=erc1155.contract_address,
            name='TransferBatch',
            data=[
                operator,   # operator
                sender,     # from
                recipient,  # to
                *prepare_calldata(TOKEN_IDS),
                *prepare_calldata(TRANSFER_VALUES),
            ]
        )


    @pytest.mark.asyncio
    async def test_safe_batch_transfer_from_invalid_value(self, contract_factory):
        erc1155, owner, account, _ = contract_factory

        sender = account.contract_address
        recipient = owner.contract_address

        await signer.send_transaction(
            owner, erc1155.contract_address, 'mintBatch',
            [sender, *prepare_calldata(TOKEN_IDS), *prepare_calldata(MAX_UINT_VALUES), DATA])

        await assert_revert(signer.send_transaction(
            account, erc1155.contract_address, 'safeBatchTransferFrom',
            [
                sender, recipient, *prepare_calldata(TOKEN_IDS),
                *prepare_calldata(INVALID_VALUES), DATA
            ]),
            "ERC1155: value is not a valid Uint256")


    @pytest.mark.asyncio
    async def test_safe_batch_transfer_from_invalid_id(self, minted_factory):
        erc1155, owner, account, _ = minted_factory

        sender = account.contract_address
        recipient = owner.contract_address
        transfer_values = [to_uint(0)]*3

        await assert_revert(
            signer.send_transaction(
                account, erc1155.contract_address, 'safeBatchTransferFrom',
                [
                    sender, recipient, *prepare_calldata(INVALID_IDS),
                    *prepare_calldata(transfer_values), DATA
                ]),
            "ERC1155: token_id is not a valid Uint256")


    @pytest.mark.asyncio
    async def test_safe_batch_transfer_from_insufficient_balance(self, 
            minted_factory):
        erc1155, account1, account2, _ = minted_factory

        sender = account2.contract_address
        recipient = account1.contract_address

        values = values = MINT_VALUES.copy()
        values[1] = add_uint(values[1], to_uint(1))

        await assert_revert(signer.send_transaction(
            account2, erc1155.contract_address, 'safeBatchTransferFrom',
            [sender, recipient, *prepare_calldata(TOKEN_IDS), *prepare_calldata(values), DATA]),
            "ERC1155: insufficient balance for transfer")


    @pytest.mark.asyncio
    async def test_safe_batch_transfer_from_unapproved(self, minted_factory):
        erc1155, account1, account2, _ = minted_factory

        sender = account2.contract_address
        recipient = account1.contract_address

        await assert_revert(signer.send_transaction(
            account1, erc1155.contract_address, 'safeBatchTransferFrom',
            [
                sender, recipient, *prepare_calldata(TOKEN_IDS),
                *prepare_calldata(TRANSFER_VALUES), DATA
            ]),
            "ERC1155: caller is not owner nor approved")


    @pytest.mark.asyncio
    async def test_safe_batch_transfer_from_to_zero_address(self, 
            minted_factory):
        erc1155, _, account, _ = minted_factory

        sender = account.contract_address

        await assert_revert(signer.send_transaction(
            account, erc1155.contract_address, 'safeBatchTransferFrom',
            [
                sender, ZERO_ADDRESS, *prepare_calldata(TOKEN_IDS),
                *prepare_calldata(TRANSFER_VALUES), DATA
            ]),
            "ERC1155: transfer to the zero address")


    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "values,token_ids",
        [
            (TRANSFER_VALUES[:2], TOKEN_IDS),
            (TRANSFER_VALUES, TOKEN_IDS[:2])
        ]
    )
    async def test_safe_batch_transfer_from_uneven_arrays(self, 
            minted_factory, values, token_ids):
        erc1155, account1, account2, _ = minted_factory

        sender = account2.contract_address
        recipient = account1.contract_address

        await assert_revert(signer.send_transaction(
            account2, erc1155.contract_address, 'safeBatchTransferFrom',
            [sender, recipient, *prepare_calldata(token_ids), *prepare_calldata(values), DATA]),
            "ERC1155: ids and values length mismatch")


    @pytest.mark.asyncio
    async def test_safe_batch_transfer_from_overflow(self, minted_factory):
        erc1155, account1, account2, _ = minted_factory

        sender = account2.contract_address
        recipient = account1.contract_address
        transfer_values = to_uint_array([0, 1, 0])

        # Bring 1 recipient's balance to max possible
        await signer.send_transaction(
            account1, erc1155.contract_address, 'mintBatch',
            [recipient, *prepare_calldata(TOKEN_IDS), *prepare_calldata(MAX_UINT_VALUES), DATA]
        )

        # Issuing recipient any more on just 1 token_id
        # should revert due to overflow
        await assert_revert(signer.send_transaction(
            account2, erc1155.contract_address, 'safeBatchTransferFrom',
            [
                sender, recipient, *prepare_calldata(TOKEN_IDS),
                *prepare_calldata(transfer_values), DATA
            ]),
            "ERC1155: balance overflow")


    @pytest.mark.asyncio
    async def test_safe_batch_transfer_from_to_receiver(self, minted_factory):
        erc1155, _, account2, receiver = minted_factory

        sender = account2.contract_address
        recipient = receiver.contract_address

        await signer.send_transaction(
            account2, erc1155.contract_address, 'safeBatchTransferFrom',
            [
                sender, recipient, *prepare_calldata(TOKEN_IDS),
                *prepare_calldata(TRANSFER_VALUES), DATA
            ])

        execution_info = await erc1155.balanceOfBatch(
            [sender]*3+[recipient]*3, TOKEN_IDS*2).execute()
        assert execution_info.result.balances[:3] == TRANSFER_DIFFERENCES
        assert execution_info.result.balances[3:] == TRANSFER_VALUES


    @pytest.mark.asyncio
    async def test_safe_batch_transfer_from_to_receiver_rejection(self, 
            minted_factory):
        erc1155, _, account2, receiver = minted_factory

        sender = account2.contract_address
        recipient = receiver.contract_address

        await assert_revert(signer.send_transaction(
            account2, erc1155.contract_address, 'safeBatchTransferFrom',
            [
                sender, recipient, *prepare_calldata(TOKEN_IDS),
                *prepare_calldata(TRANSFER_VALUES), *REJECT_DATA
            ]),
            "ERC1155: ERC1155Receiver rejected tokens")


    @pytest.mark.asyncio
    async def test_safe_batch_transfer_from_to_non_receiver(self, 
            minted_factory):
        erc1155, _, account, _ = minted_factory

        sender = account.contract_address
        recipient = erc1155.contract_address

        await assert_revert(signer.send_transaction(
            account, erc1155.contract_address, 'safeBatchTransferFrom',
            [
                sender, recipient, *prepare_calldata(TOKEN_IDS),
                *prepare_calldata(TRANSFER_VALUES), DATA
            ]),
            "ERC1155: transfer to non-ERC1155Receiver implementer")
