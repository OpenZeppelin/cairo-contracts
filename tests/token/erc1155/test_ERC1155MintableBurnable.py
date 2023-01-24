import pytest
from signers import MockSigner
from utils import State, Account, get_contract_class, cached_contract, assert_event_emitted

from access.OwnableBaseSuite import OwnableBase
from ERC1155BaseSuite import (
    ERC1155Base, to_uint_array, prepare_calldata,
    TOKEN_ID, MINT_VALUE,
    MINT_VALUE,TOKEN_IDS,
    MINT_VALUES, MAX_UINT_VALUES,
    INVALID_VALUES, INVALID_IDS,
    DATA, REJECT_DATA, DEFAULT_URI
)

from nile.utils import (
    MAX_UINT256, ZERO_ADDRESS, INVALID_UINT256, TRUE, FALSE,
    to_uint, add_uint, sub_uint, assert_revert
)

signer = MockSigner(123456789987654321)

#
# Constants
#
BURN_value = to_uint(500)
BURN_VALUES = [BURN_value, to_uint(1000), to_uint(1500)]
BURN_DIFFERENCES = [sub_uint(m, b) for m, b in zip(MINT_VALUES, BURN_VALUES)]

#
# Fixtures
#


@pytest.fixture(scope='module')
def contract_classes():
    account_cls = Account.get_class
    erc1155_cls = get_contract_class('ERC1155MintableBurnable')
    receiver_cls = get_contract_class('ERC1155Holder')
    return account_cls, erc1155_cls, receiver_cls


@pytest.fixture(scope='module')
async def erc1155_init(contract_classes):
    _, erc1155_cls, receiver_cls = contract_classes
    starknet = await State.init()
    account1 = await Account.deploy(signer.public_key)
    account2 = await Account.deploy(signer.public_key)
    erc1155 = await starknet.deploy(
        contract_class=erc1155_cls,
        constructor_calldata=[DEFAULT_URI, account1.contract_address]
    )
    receiver = await starknet.deploy(
        contract_class=receiver_cls
    )
    return (
        starknet.state,
        account1,
        account2,
        erc1155,
        receiver
    )


@pytest.fixture
def contract_factory(contract_classes, erc1155_init):
    account_cls, erc1155_cls, receiver_cls = contract_classes
    state, account1, account2, erc1155, receiver = erc1155_init
    _state = state.copy()
    account1 = cached_contract(_state, account_cls, account1)
    account2 = cached_contract(_state, account_cls, account2)
    erc1155 = cached_contract(_state, erc1155_cls, erc1155)
    receiver = cached_contract(_state, receiver_cls, receiver)
    return erc1155, account1, account2, receiver


@pytest.fixture
async def minted_factory(contract_classes, erc1155_init):
    account_cls, erc1155_cls, receiver_cls = contract_classes
    state, owner, account, erc1155, receiver = erc1155_init
    _state = state.copy()
    owner = cached_contract(_state, account_cls, owner)
    account = cached_contract(_state, account_cls, account)
    erc1155 = cached_contract(_state, erc1155_cls, erc1155)
    receiver = cached_contract(_state, receiver_cls, receiver)
    await signer.send_transaction(
        owner, erc1155.contract_address, 'mintBatch',
        [
            account.contract_address,         # to
            *prepare_calldata(TOKEN_IDS),     # ids
            *prepare_calldata(MINT_VALUES),   # values
            DATA
        ]
    )
    return erc1155, owner, account, receiver



class TestERC1155MintableBurnable(ERC1155Base, OwnableBase):
    #
    # Minting
    #

    @pytest.mark.asyncio
    async def test_mint(self, contract_factory):
        erc1155, owner, account, _ = contract_factory

        recipient = account.contract_address

        await signer.send_transaction(
            owner, erc1155.contract_address, 'mint',
            [recipient, *TOKEN_ID, *MINT_VALUE, DATA])

        execution_info = await erc1155.balanceOf(recipient, TOKEN_ID).execute()
        assert execution_info.result.balance == MINT_VALUE


    @pytest.mark.asyncio
    async def test_mint_emits_event(self, contract_factory):
        erc1155, owner, account, _ = contract_factory

        recipient = account.contract_address

        execution_info = await signer.send_transaction(
            owner, erc1155.contract_address, 'mint',
            [recipient, *TOKEN_ID, *MINT_VALUE, DATA])

        assert_event_emitted(
            execution_info,
            from_address=erc1155.contract_address,
            name='TransferSingle',
            data=[
                owner.contract_address,  # operator
                ZERO_ADDRESS,            # from
                recipient,               # to
                *TOKEN_ID,
                *MINT_VALUE
            ]
        )


    @pytest.mark.asyncio
    async def test_mint_to_zero_address(self, contract_factory):
        erc1155, owner, _, _ = contract_factory

        await assert_revert(
            signer.send_transaction(
                owner, erc1155.contract_address, 'mint',
                [ZERO_ADDRESS, *TOKEN_ID, *MINT_VALUE, DATA]),
            "ERC1155: mint to the zero address")


    @pytest.mark.asyncio
    async def test_mint_overflow(self, contract_factory):
        erc1155, owner, account, _ = contract_factory

        recipient = account.contract_address

        # Bring recipient's balance to max possible
        await signer.send_transaction(
            owner, erc1155.contract_address, 'mint',
            [recipient, *TOKEN_ID, *MAX_UINT256, DATA])

        # Issuing recipient any more should revert due to overflow
        await assert_revert(
            signer.send_transaction(
                owner, erc1155.contract_address, 'mint',
                [recipient, *TOKEN_ID, *to_uint(1), DATA]),
            "ERC1155: balance overflow")


    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "value,token_id,error",
        [
            (MINT_VALUE, INVALID_UINT256,
            "ERC1155: token_id is not a valid Uint256"),
            (INVALID_UINT256, TOKEN_ID, 
            "ERC1155: value is not a valid Uint256")
        ]
    )
    async def test_mint_invalid_uint(self, contract_factory, value, token_id, error):
        erc1155, owner, account, _ = contract_factory

        recipient = account.contract_address

        await assert_revert(
            signer.send_transaction(
                owner, erc1155.contract_address, 'mint',
                [recipient, *token_id, *value, DATA]),
            error)


    @pytest.mark.asyncio
    async def test_mint_receiver(self, contract_factory):
        erc1155, owner, _, receiver = contract_factory

        recipient = receiver.contract_address

        await signer.send_transaction(
            owner, erc1155.contract_address, 'mint',
            [recipient, *TOKEN_ID, *MINT_VALUE, DATA])

        execution_info = await erc1155.balanceOf(
            recipient, TOKEN_ID).execute()
        assert execution_info.result.balance == MINT_VALUE


    @pytest.mark.asyncio
    async def test_mint_receiver_rejection(self, contract_factory):
        erc1155, owner, _, receiver = contract_factory

        recipient = receiver.contract_address

        await assert_revert(
            signer.send_transaction(
                owner, erc1155.contract_address, 'mint',
                [recipient, *TOKEN_ID, *MINT_VALUE, *REJECT_DATA]),
            "ERC1155: ERC1155Receiver rejected tokens")


    @pytest.mark.asyncio
    async def test_mint_to_unsafe_contract(self, contract_factory):
        erc1155, owner, _, _ = contract_factory

        recipient = erc1155.contract_address

        await assert_revert(
            signer.send_transaction(
                owner, erc1155.contract_address, 'mint',
                [recipient, *TOKEN_ID, *MINT_VALUE, DATA]),
            "ERC1155: transfer to non-ERC1155Receiver implementer")

    #
    # Burning
    #


    @pytest.mark.asyncio
    async def test_burn(self, minted_factory):
        erc1155, _, account, _ = minted_factory

        subject = account.contract_address

        await signer.send_transaction(
            account, erc1155.contract_address, 'burn',
            [subject, *TOKEN_ID, *BURN_value])

        execution_info = await erc1155.balanceOf(subject, TOKEN_ID).execute()
        assert execution_info.result.balance == sub_uint(MINT_VALUE, BURN_value)


    @pytest.mark.asyncio
    async def test_burn_emits_event(self, minted_factory):
        erc1155, _, account, _ = minted_factory

        subject = account.contract_address

        execution_info = await signer.send_transaction(
            account, erc1155.contract_address, 'burn',
            [subject, *TOKEN_ID, *BURN_value])

        assert_event_emitted(
            execution_info,
            from_address=erc1155.contract_address,
            name='TransferSingle',
            data=[
                subject,       # operator
                subject,       # from
                ZERO_ADDRESS,  # to
                *TOKEN_ID,
                *BURN_value
            ]
        )


    @pytest.mark.asyncio
    async def test_burn_approved(self, minted_factory):
        erc1155, account1, account2, _ = minted_factory

        operator = account1.contract_address
        subject = account2.contract_address

        # account2 approves account
        await signer.send_transaction(
            account2, erc1155.contract_address, 'setApprovalForAll',
            [operator, TRUE])

        await signer.send_transaction(
            account1, erc1155.contract_address, 'burn',
            [subject, *TOKEN_ID, *BURN_value])

        execution_info = await erc1155.balanceOf(subject, TOKEN_ID).execute()
        assert execution_info.result.balance == sub_uint(MINT_VALUE, BURN_value)


    @pytest.mark.asyncio
    async def test_burn_approved_emits_event(self, minted_factory):
        erc1155, account1, account2, _ = minted_factory

        operator = account1.contract_address
        subject = account2.contract_address

        # account2 approves account
        await signer.send_transaction(
            account2, erc1155.contract_address, 'setApprovalForAll',
            [operator, TRUE]
        )

        execution_info = await signer.send_transaction(
            account1, erc1155.contract_address, 'burn',
            [subject, *TOKEN_ID, *BURN_value]
        )

        assert_event_emitted(
            execution_info,
            from_address=erc1155.contract_address,
            name='TransferSingle',
            data=[
                operator,      # operator
                subject,       # from
                ZERO_ADDRESS,  # to
                *TOKEN_ID,
                *BURN_value
            ]
        )


    @pytest.mark.asyncio
    async def test_burn_insufficient_balance(self, minted_factory):
        erc1155, _, account, _ = minted_factory

        subject = account.contract_address
        burn_value = add_uint(MINT_VALUE, to_uint(1))

        await assert_revert(
            signer.send_transaction(
                account, erc1155.contract_address, 'burn',
                [subject, *TOKEN_ID, *burn_value]),
            "ERC1155: burn value exceeds balance")


    @pytest.mark.asyncio
    async def test_burn_invalid_value(self, contract_factory):
        erc1155, owner, account, _ = contract_factory

        burner = account.contract_address

        # mint max possible to avoid insufficient balance
        await signer.send_transaction(
            owner, erc1155.contract_address, 'mint',
            [burner, *TOKEN_ID, *MAX_UINT256, DATA])

        await assert_revert(
            signer.send_transaction(
                account, erc1155.contract_address, 'burn',
                [burner, *TOKEN_ID, *INVALID_UINT256]),
            "ERC1155: value is not a valid Uint256")


    @pytest.mark.asyncio
    async def test_burn_invalid_id(self, minted_factory):
        erc1155, _, account, _ = minted_factory

        burner = account.contract_address

        await assert_revert(
            signer.send_transaction(
                account, erc1155.contract_address, 'burn',
                [burner, *INVALID_UINT256, *to_uint(0)]),
            "ERC1155: token_id is not a valid Uint256")


    #
    # Batch Minting
    #


    @pytest.mark.asyncio
    async def test_mint_batch(self, contract_factory):
        erc1155, owner, account, _ = contract_factory

        recipient = account.contract_address

        await signer.send_transaction(
            owner, erc1155.contract_address, 'mintBatch',
            [recipient, *prepare_calldata(TOKEN_IDS), *prepare_calldata(MINT_VALUES), DATA])

        execution_info = await erc1155.balanceOfBatch(
            [recipient]*3, TOKEN_IDS).execute()
        assert execution_info.result.balances == MINT_VALUES


    @pytest.mark.asyncio
    async def test_mint_batch_emits_event(self, contract_factory):
        erc1155, owner, account, _ = contract_factory

        recipient = account.contract_address

        execution_info = await signer.send_transaction(
            owner, erc1155.contract_address, 'mintBatch',
            [recipient, *prepare_calldata(TOKEN_IDS), *prepare_calldata(MINT_VALUES), DATA])

        assert_event_emitted(
            execution_info,
            from_address=erc1155.contract_address,
            name='TransferBatch',
            data=[
                owner.contract_address,  # operator
                ZERO_ADDRESS,            # from
                recipient,               # to
                *prepare_calldata(TOKEN_IDS),
                *prepare_calldata(MINT_VALUES),
            ]
        )


    @pytest.mark.asyncio
    async def test_mint_batch_to_zero_address(self, contract_factory):
        erc1155, owner, _, _ = contract_factory

        await assert_revert(
            signer.send_transaction(
                owner, erc1155.contract_address, 'mintBatch',
                [ZERO_ADDRESS, *prepare_calldata(TOKEN_IDS), *prepare_calldata(MINT_VALUES), DATA]),
            "ERC1155: mint to the zero address")


    @pytest.mark.asyncio
    async def test_mint_batch_overflow(self, contract_factory):
        erc1155, owner, account, _ = contract_factory

        recipient = account.contract_address

        # Bring recipient's balance to max possible
        await signer.send_transaction(
            owner, erc1155.contract_address, 'mintBatch',
            [recipient, *prepare_calldata(TOKEN_IDS), *prepare_calldata(MAX_UINT_VALUES), DATA])

        # Issuing recipient any more on just 1 token_id
        # should revert due to overflow
        values = to_uint_array([0, 1, 0])
        await assert_revert(
            signer.send_transaction(
                owner, erc1155.contract_address, 'mintBatch',
                [recipient, *prepare_calldata(TOKEN_IDS), *prepare_calldata(values), DATA]),
            "ERC1155: balance overflow")


    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "values,token_ids,error",
        [
            (INVALID_VALUES, TOKEN_IDS, "ERC1155: value is not a valid Uint256"),
            (MINT_VALUES, INVALID_IDS, "ERC1155: token_id is not a valid Uint256")
        ])
    async def test_mint_batch_invalid_uint(self, contract_factory, values, token_ids, error):
        erc1155, owner, account, _ = contract_factory

        recipient = account.contract_address

        await assert_revert(
            signer.send_transaction(
                owner, erc1155.contract_address, 'mintBatch',
                [recipient, *prepare_calldata(token_ids), *prepare_calldata(values), DATA]),
            error)


    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "values,token_ids",
        [
            (MINT_VALUES[:2], TOKEN_IDS),
            (MINT_VALUES, TOKEN_IDS[:2])
        ])
    async def test_mint_batch_uneven_arrays(self, contract_factory, values, token_ids):
        erc1155, owner, account, _ = contract_factory

        recipient = account.contract_address

        await assert_revert(
            signer.send_transaction(
                owner, erc1155.contract_address, 'mintBatch',
                [recipient, *prepare_calldata(token_ids), *prepare_calldata(values), DATA]),
            "ERC1155: ids and values length mismatch")


    @pytest.mark.asyncio
    async def test_mint_batch_to_receiver(self, contract_factory):
        erc1155, owner, _, receiver = contract_factory

        recipient = receiver.contract_address

        await signer.send_transaction(
            owner, erc1155.contract_address, 'mintBatch',
            [
                recipient, *prepare_calldata(TOKEN_IDS),
                *prepare_calldata(MINT_VALUES), DATA
            ])

        execution_info = await erc1155.balanceOfBatch(
            [recipient]*3, TOKEN_IDS).execute()
        assert execution_info.result.balances == MINT_VALUES


    @pytest.mark.asyncio
    async def test_mint_batch_to_receiver_rejection(self, contract_factory):
        erc1155, owner, _, receiver = contract_factory

        recipient = receiver.contract_address

        await assert_revert(signer.send_transaction(
            owner, erc1155.contract_address, 'mintBatch',
            [
                recipient, *prepare_calldata(TOKEN_IDS),
                *prepare_calldata(MINT_VALUES), *REJECT_DATA
            ]),
            "ERC1155: ERC1155Receiver rejected tokens")


    @pytest.mark.asyncio
    async def test_mint_batch_to_non_receiver(self, contract_factory):
        erc1155, owner, _, _ = contract_factory

        recipient = erc1155.contract_address

        await assert_revert(signer.send_transaction(
            owner, erc1155.contract_address, 'mintBatch',
            [
                recipient, *prepare_calldata(TOKEN_IDS),
                *prepare_calldata(MINT_VALUES), DATA
            ]),
            "ERC1155: transfer to non-ERC1155Receiver implementer")

    #
    # Batch Burning
    #


    @pytest.mark.asyncio
    async def test_burn_batch(self, minted_factory):
        erc1155, _, account, _ = minted_factory

        burner = account.contract_address

        await signer.send_transaction(
            account, erc1155.contract_address, 'burnBatch',
            [burner, *prepare_calldata(TOKEN_IDS), *prepare_calldata(BURN_VALUES)])

        execution_info = await erc1155.balanceOfBatch(
            [burner]*3, TOKEN_IDS).execute()
        assert execution_info.result.balances == BURN_DIFFERENCES


    @pytest.mark.asyncio
    async def test_burn_batch_emits_event(self, minted_factory):
        erc1155, _, account, _ = minted_factory

        burner = account.contract_address

        execution_info = await signer.send_transaction(
            account, erc1155.contract_address, 'burnBatch',
            [burner, *prepare_calldata(TOKEN_IDS), *prepare_calldata(BURN_VALUES)])

        assert_event_emitted(
            execution_info,
            from_address=erc1155.contract_address,
            name='TransferBatch',
            data=[
                burner,        # operator
                burner,        # from
                ZERO_ADDRESS,  # to
                *prepare_calldata(TOKEN_IDS),
                *prepare_calldata(BURN_VALUES),
            ]
        )


    @pytest.mark.asyncio
    async def test_burn_batch_from_approved(self, minted_factory):
        erc1155, account1, account2, _ = minted_factory

        burner = account2.contract_address
        operator = account1.contract_address

        await signer.send_transaction(
            account2, erc1155.contract_address, 'setApprovalForAll',
            [operator, TRUE])

        await signer.send_transaction(
            account1, erc1155.contract_address, 'burnBatch',
            [burner, *prepare_calldata(TOKEN_IDS), *prepare_calldata(BURN_VALUES)])

        execution_info = await erc1155.balanceOfBatch(
            [burner]*3, TOKEN_IDS).execute()
        assert execution_info.result.balances == BURN_DIFFERENCES


    @pytest.mark.asyncio
    async def test_burn_batch_from_approved_emits_event(self, minted_factory):
        erc1155, account1, account2, _ = minted_factory

        burner = account2.contract_address
        operator = account1.contract_address

        await signer.send_transaction(
            account2, erc1155.contract_address, 'setApprovalForAll',
            [operator, TRUE])

        execution_info = await signer.send_transaction(
            account1, erc1155.contract_address, 'burnBatch',
            [burner, *prepare_calldata(TOKEN_IDS), *prepare_calldata(BURN_VALUES)])

        assert_event_emitted(
            execution_info,
            from_address=erc1155.contract_address,
            name='TransferBatch',
            data=[
                operator,      # operator
                burner,        # from
                ZERO_ADDRESS,  # to
                *prepare_calldata(TOKEN_IDS),
                *prepare_calldata(BURN_VALUES),
            ]
        )


    @pytest.mark.asyncio
    async def test_burn_batch_from_unapproved(self, minted_factory):
        erc1155, account1, account2, _ = minted_factory

        burner = account2.contract_address
        operator = account1.contract_address

        await signer.send_transaction(
            account2, erc1155.contract_address, 'setApprovalForAll',
            [operator, FALSE])

        await assert_revert(signer.send_transaction(
            account1, erc1155.contract_address, 'burnBatch',
            [burner, *prepare_calldata(TOKEN_IDS), *prepare_calldata(BURN_VALUES)]),
            "ERC1155: caller is not owner nor approved")


    @pytest.mark.asyncio
    async def test_burn_batch_from_zero_address(self, minted_factory):
        erc1155, _, _, _ = minted_factory

        values = [to_uint(0)]*3

        # Attempt to burn nothing (since cannot mint non_zero balance to burn)
        # note invoking this way (without signer) gives caller address of 0
        await assert_revert(
            erc1155.burnBatch(ZERO_ADDRESS, TOKEN_IDS, values).execute(),
            "ERC1155: burn from the zero address")


    @pytest.mark.asyncio
    async def test_burn_batch_insufficent_balance(self, minted_factory):
        erc1155, _, account, _ = minted_factory

        burner = account.contract_address
        values = MINT_VALUES.copy()
        values[1] = add_uint(values[1], to_uint(1))

        await assert_revert(
            signer.send_transaction(
                account, erc1155.contract_address, 'burnBatch',
                [burner, *prepare_calldata(TOKEN_IDS), *prepare_calldata(values)]),
            "ERC1155: burn value exceeds balance")


    @pytest.mark.asyncio
    async def test_burn_batch_invalid_value(self, contract_factory):
        erc1155, owner, account, _ = contract_factory

        burner = account.contract_address

        # mint max possible to avoid insufficient balance
        await signer.send_transaction(
            owner, erc1155.contract_address, 'mintBatch',
            [burner, *prepare_calldata(TOKEN_IDS), *prepare_calldata(MAX_UINT_VALUES), 0])

        # attempt passing an invalid uint in batch
        await assert_revert(
            signer.send_transaction(
                account, erc1155.contract_address, 'burnBatch',
                [burner, *prepare_calldata(TOKEN_IDS), *prepare_calldata(INVALID_VALUES)]),
            "ERC1155: value is not a valid Uint256")


    @pytest.mark.asyncio
    async def test_burn_batch_invalid_id(self, minted_factory):
        erc1155, _, account, _ = minted_factory

        burner = account.contract_address
        burn_values = [to_uint(0)]*3

        await assert_revert(
            signer.send_transaction(
                account, erc1155.contract_address, 'burnBatch',
                [burner, *prepare_calldata(INVALID_IDS), *prepare_calldata(burn_values)]),
            "ERC1155: token_id is not a valid Uint256")


    @pytest.mark.asyncio
    @pytest.mark.parametrize(
        "values,token_ids",
        [
            (BURN_VALUES[:2], TOKEN_IDS),
            (BURN_VALUES, TOKEN_IDS[:2])
        ]
    )
    async def test_burn_batch_uneven_arrays(self, 
            minted_factory, values, token_ids):
        erc1155, _, account, _ = minted_factory

        burner = account.contract_address

        await assert_revert(
            signer.send_transaction(
                account, erc1155.contract_address, 'burnBatch',
                [burner, *prepare_calldata(token_ids), *prepare_calldata(values)]),
            "ERC1155: ids and values length mismatch")
