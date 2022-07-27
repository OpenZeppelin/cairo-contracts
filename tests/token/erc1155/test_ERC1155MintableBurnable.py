import pytest
from starkware.starknet.testing.starknet import Starknet
from signers import MockSigner
from utils import (
    uint, to_uint, add_uint, sub_uint,
    MAX_UINT256, ZERO_ADDRESS, INVALID_UINT256, TRUE, FALSE,
    get_contract_class, cached_contract,
    assert_revert, assert_event_emitted
)

signer = MockSigner(123456789987654321)

#
# Helpers
#


def uint_array(arr):
    return list(map(uint, arr))


def to_uint_array(arr):
    return list(map(to_uint, arr))


def uarr2cd(arr):
    acc = [len(arr)]
    for lo, hi in arr:
        acc.append(lo)
        acc.append(hi)
    return acc

#
# Constants
#


NOT_BOOLEAN = 3
ACCOUNT = 123
TOKEN_ID = to_uint(111)
MINT_AMOUNT = to_uint(1000)
BURN_AMOUNT = to_uint(500)
TRANSFER_AMOUNT = to_uint(500)

ACCOUNTS = [123, 234, 345]
TOKEN_IDS = [TOKEN_ID, to_uint(222), to_uint(333)]
MINT_AMOUNTS = [MINT_AMOUNT, to_uint(2000), to_uint(3000)]
BURN_AMOUNTS = [BURN_AMOUNT, to_uint(1000), to_uint(1500)]
BURN_DIFFERENCES = [sub_uint(m, b) for m, b in zip(MINT_AMOUNTS, BURN_AMOUNTS)]
TRANSFER_AMOUNTS = [TRANSFER_AMOUNT, to_uint(1000), to_uint(1500)]
TRANSFER_DIFFERENCES = [sub_uint(m, t)
                        for m, t in zip(MINT_AMOUNTS, TRANSFER_AMOUNTS)]
MAX_UINT_AMOUNTS = [to_uint(1), MAX_UINT256, to_uint(1)]
INVALID_AMOUNTS = uint_array([1, MAX_UINT256[0]+1, 1])
INVALID_IDS = uint_array([111, MAX_UINT256[0]+1, 333])


DATA = 0
REJECT_DATA = [1, 0]

IERC165_ID = int('0x01ffc9a7', 16)
IERC1155_ID = int('0xd9b67a26', 16)
IERC1155_MetadataURI = int('0x0e89341c', 16)
ERC165_UNSUPPORTED = int('0xffffffff', 16)
UNSUPPORTED_ID = int('0xaabbccdd', 16)

SUPPORTED_INTERFACES = [IERC165_ID, IERC1155_ID, IERC1155_MetadataURI]
UNSUPPORTED_INTERFACES = [ERC165_UNSUPPORTED, UNSUPPORTED_ID]

#
# Fixtures
#


@pytest.fixture(scope='module')
def contract_classes():
    account_cls = get_contract_class('Account')
    erc1155_cls = get_contract_class('ERC1155MintableBurnable')
    receiver_cls = get_contract_class('ERC1155ReceiverMock')
    return account_cls, erc1155_cls, receiver_cls


@pytest.fixture(scope='module')
async def erc1155_init(contract_classes):
    account_cls, erc1155_cls, receiver_cls = contract_classes
    starknet = await Starknet.empty()
    account1 = await starknet.deploy(
        contract_class=account_cls,
        constructor_calldata=[signer.public_key]
    )
    account2 = await starknet.deploy(
        contract_class=account_cls,
        constructor_calldata=[signer.public_key]
    )
    erc1155 = await starknet.deploy(
        contract_class=erc1155_cls,
        constructor_calldata=[0, account1.contract_address]
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
def erc1155_factory(contract_classes, erc1155_init):
    account_cls, erc1155_cls, receiver_cls = contract_classes
    state, account1, account2, erc1155, receiver = erc1155_init
    _state = state.copy()
    account1 = cached_contract(_state, account_cls, account1)
    account2 = cached_contract(_state, account_cls, account2)
    erc1155 = cached_contract(_state, erc1155_cls, erc1155)
    receiver = cached_contract(_state, receiver_cls, receiver)
    return erc1155, account1, account2, receiver


@pytest.fixture
async def erc1155_minted_factory(contract_classes, erc1155_init):
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
            account.contract_address,  # to
            *uarr2cd(TOKEN_IDS),  # ids
            *uarr2cd(MINT_AMOUNTS),  # amounts
            0  # data
        ]
    )
    return erc1155, owner, account, receiver

#
# Constructor
#


@pytest.mark.asyncio
async def test_constructor(erc1155_factory):
    erc1155, _, _, _ = erc1155_factory

    execution_info = await erc1155.uri().invoke()
    assert execution_info.result.uri == 0

#
# ERC165
#


@pytest.mark.asyncio
@pytest.mark.parametrize("supported_id", SUPPORTED_INTERFACES)
async def test_supports_interface(erc1155_factory, supported_id):
    erc1155, _, _, _ = erc1155_factory

    execution_info = await erc1155.supportsInterface(supported_id).invoke()
    assert execution_info.result.success == TRUE


@pytest.mark.asyncio
@pytest.mark.parametrize("unsupported_id", UNSUPPORTED_INTERFACES)
async def test_supports_interface_unsupported(erc1155_factory, unsupported_id):
    erc1155, _, _, _ = erc1155_factory

    execution_info = await erc1155.supportsInterface(unsupported_id).invoke()
    assert execution_info.result.success == FALSE

#
# Set/Get approval
#


@pytest.mark.asyncio
@pytest.mark.parametrize("approval", [TRUE, FALSE])
async def test_set_approval_for_all(erc1155_factory, approval):
    erc1155, account, _, _ = erc1155_factory

    approver = account.contract_address

    await signer.send_transaction(
        account, erc1155.contract_address, 'setApprovalForAll',
        [ACCOUNT, approval]
    )

    execution_info = await erc1155.isApprovedForAll(
        approver, ACCOUNT).invoke()

    assert execution_info.result.is_approved == approval


@pytest.mark.asyncio
@pytest.mark.parametrize("approval", [TRUE, FALSE])
async def test_set_approval_for_all_emits_event(erc1155_factory, approval):
    erc1155, account, _, _ = erc1155_factory

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
async def test_set_approval_for_all_non_boolean(erc1155_factory):
    erc1155, account, _, _ = erc1155_factory

    await assert_revert(signer.send_transaction(
        account, erc1155.contract_address, 'setApprovalForAll',
        [ACCOUNT, NOT_BOOLEAN]
    ))

#
# Balance getters
#


@pytest.mark.asyncio
async def test_balance_of(erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    user = account.contract_address

    execution_info = await erc1155.balanceOf(user, TOKEN_ID).invoke()
    assert execution_info.result.balance == MINT_AMOUNT


@pytest.mark.asyncio
async def test_balance_of_zero_address(erc1155_factory):
    erc1155, _, _, _ = erc1155_factory

    await assert_revert(
        erc1155.balanceOf(ZERO_ADDRESS, TOKEN_ID).invoke(),
        "ERC1155: balance query for the zero address")


@pytest.mark.asyncio
async def test_balance_of_batch(erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    accounts = [account.contract_address]*3

    execution_info = await erc1155.balanceOfBatch(accounts, TOKEN_IDS).invoke()
    assert execution_info.result.balances == MINT_AMOUNTS


@pytest.mark.asyncio
async def test_balance_of_batch_zero_address(erc1155_factory):
    erc1155, _, _, _ = erc1155_factory
    accounts = [ACCOUNT, ZERO_ADDRESS, ACCOUNT]

    await assert_revert(
        erc1155.balanceOfBatch(accounts, TOKEN_IDS).invoke(),
        "ERC1155: balance query for the zero address")


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "accounts,ids",
    [(ACCOUNTS[:2], TOKEN_IDS), (ACCOUNTS, TOKEN_IDS[:2])])
async def test_balance_of_batch_uneven_arrays(erc1155_factory, accounts, ids):
    erc1155, _, _, _ = erc1155_factory

    await assert_revert(
        erc1155.balanceOfBatch(accounts, ids).invoke(),
        "ERC1155: accounts and ids length mismatch")


@pytest.mark.asyncio
async def test_mint(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory

    recipient = account.contract_address

    await signer.send_transaction(
        owner, erc1155.contract_address, 'mint',
        [recipient, *TOKEN_ID, *MINT_AMOUNT, DATA])

    execution_info = await erc1155.balanceOf(recipient, TOKEN_ID).invoke()
    assert execution_info.result.balance == MINT_AMOUNT


@pytest.mark.asyncio
async def test_mint_emits_event(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory

    recipient = account.contract_address

    execution_info = await signer.send_transaction(
        owner, erc1155.contract_address, 'mint',
        [recipient, *TOKEN_ID, *MINT_AMOUNT, DATA])

    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='TransferSingle',
        data=[
            owner.contract_address,  # operator
            ZERO_ADDRESS,  # from
            recipient,  # to
            *TOKEN_ID,
            *MINT_AMOUNT
        ]
    )


@pytest.mark.asyncio
async def test_mint_to_zero_address(erc1155_factory):
    erc1155, owner, _, _ = erc1155_factory

    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mint',
            [ZERO_ADDRESS, *TOKEN_ID, *MINT_AMOUNT, DATA]),
        "ERC1155: mint to the zero address")


@pytest.mark.asyncio
async def test_mint_overflow(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory

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
    "amount,token_id,error",
    [
        (MINT_AMOUNT, INVALID_UINT256, "ERC1155: id is not a valid Uint256"),
        (INVALID_UINT256, TOKEN_ID, "ERC1155: amount is not a valid Uint256")
    ]
)
async def test_mint_invalid_uint(erc1155_factory, amount, token_id, error):
    erc1155, owner, account, _ = erc1155_factory

    recipient = account.contract_address

    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mint',
            [recipient, *token_id, *amount, DATA]),
        error)


@pytest.mark.asyncio
async def test_mint_receiver(erc1155_factory):
    erc1155, owner, _, receiver = erc1155_factory

    recipient = receiver.contract_address

    await signer.send_transaction(
        owner, erc1155.contract_address, 'mint',
        [recipient, *TOKEN_ID, *MINT_AMOUNT, DATA])

    execution_info = await erc1155.balanceOf(
        recipient, TOKEN_ID).invoke()
    assert execution_info.result.balance == MINT_AMOUNT


@pytest.mark.asyncio
async def test_mint_receiver_rejection(erc1155_factory):
    erc1155, owner, _, receiver = erc1155_factory

    recipient = receiver.contract_address

    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mint',
            [recipient, *TOKEN_ID, *MINT_AMOUNT, *REJECT_DATA]),
        "ERC1155: ERC1155Receiver rejected tokens")


@pytest.mark.asyncio
async def test_mint_to_unsafe_contract(erc1155_factory):
    erc1155, owner, _, _ = erc1155_factory

    recipient = erc1155.contract_address

    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mint',
            [recipient, *TOKEN_ID, *MINT_AMOUNT, DATA]),
        "ERC1155: transfer to non ERC1155Receiver implementer")

#
# Burning
#


@pytest.mark.asyncio
async def test_burn(erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    subject = account.contract_address

    await signer.send_transaction(
        account, erc1155.contract_address, 'burn',
        [subject, *TOKEN_ID, *BURN_AMOUNT])

    execution_info = await erc1155.balanceOf(subject, TOKEN_ID).invoke()
    assert execution_info.result.balance == sub_uint(MINT_AMOUNT, BURN_AMOUNT)


@pytest.mark.asyncio
async def test_burn_emits_event(erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    subject = account.contract_address

    execution_info = await signer.send_transaction(
        account, erc1155.contract_address, 'burn',
        [subject, *TOKEN_ID, *BURN_AMOUNT])

    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='TransferSingle',
        data=[
            subject,  # operator
            subject,  # from
            ZERO_ADDRESS,  # to
            *TOKEN_ID,
            *BURN_AMOUNT
        ]
    )


@pytest.mark.asyncio
async def test_burn_approved(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    operator = account1.contract_address
    subject = account2.contract_address

    # account2 approves account
    await signer.send_transaction(
        account2, erc1155.contract_address, 'setApprovalForAll',
        [operator, TRUE])

    await signer.send_transaction(
        account1, erc1155.contract_address, 'burn',
        [subject, *TOKEN_ID, *BURN_AMOUNT])

    execution_info = await erc1155.balanceOf(subject, TOKEN_ID).invoke()
    assert execution_info.result.balance == sub_uint(MINT_AMOUNT, BURN_AMOUNT)


@pytest.mark.asyncio
async def test_burn_approved_emits_event(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    operator = account1.contract_address
    subject = account2.contract_address

    # account2 approves account
    await signer.send_transaction(
        account2, erc1155.contract_address, 'setApprovalForAll',
        [operator, TRUE]
    )

    execution_info = await signer.send_transaction(
        account1, erc1155.contract_address, 'burn',
        [subject, *TOKEN_ID, *BURN_AMOUNT]
    )

    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='TransferSingle',
        data=[
            operator,  # operator
            subject,  # from
            ZERO_ADDRESS,  # to
            *TOKEN_ID,
            *BURN_AMOUNT
        ]
    )


@pytest.mark.asyncio
async def test_burn_insufficient_balance(erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    subject = account.contract_address
    burn_amount = add_uint(MINT_AMOUNT, to_uint(1))

    await assert_revert(
        signer.send_transaction(
            account, erc1155.contract_address, 'burn',
            [subject, *TOKEN_ID, *burn_amount]),
        "ERC1155: burn amount exceeds balance")


@pytest.mark.asyncio
async def test_burn_invalid_amount(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory

    burner = account.contract_address

    # mint max possible to avoid insufficient balance
    await signer.send_transaction(
        owner, erc1155.contract_address, 'mint',
        [burner, *TOKEN_ID, *MAX_UINT256, DATA])

    await assert_revert(
        signer.send_transaction(
            account, erc1155.contract_address, 'burn',
            [burner, *TOKEN_ID, *INVALID_UINT256]),
        "ERC1155: amount is not a valid Uint256")


@pytest.mark.asyncio
async def test_burn_invalid_id(erc1155_minted_factory):
    erc1155, owner, account, _ = erc1155_minted_factory

    burner = account.contract_address

    await assert_revert(
        signer.send_transaction(
            account, erc1155.contract_address, 'burn',
            [burner, *INVALID_UINT256, *to_uint(0)]),
        "ERC1155: id is not a valid Uint256")

#
# Transfer
#


@pytest.mark.asyncio
async def test_safe_transfer_from(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    sender = account2.contract_address
    recipient = account1.contract_address

    await signer.send_transaction(
        account2, erc1155.contract_address, 'safeTransferFrom',
        [sender, recipient, *TOKEN_ID, *TRANSFER_AMOUNT, DATA])

    execution_info = await erc1155.balanceOf(sender, TOKEN_ID).invoke()
    assert execution_info.result.balance == sub_uint(
        MINT_AMOUNT, TRANSFER_AMOUNT)

    execution_info = await erc1155.balanceOf(recipient, TOKEN_ID).invoke()
    assert execution_info.result.balance == TRANSFER_AMOUNT


@pytest.mark.asyncio
async def test_safe_transfer_from_emits_event(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    sender = account2.contract_address
    recipient = account1.contract_address

    execution_info = await signer.send_transaction(
        account2, erc1155.contract_address, 'safeTransferFrom',
        [sender, recipient, *TOKEN_ID, *TRANSFER_AMOUNT, DATA])

    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='TransferSingle',
        data=[
            sender,  # operator
            sender,  # from
            recipient,  # to
            *TOKEN_ID,
            *TRANSFER_AMOUNT
        ]
    )


@pytest.mark.asyncio
async def test_safe_transfer_from_approved(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

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
        [sender, recipient, *TOKEN_ID, *TRANSFER_AMOUNT, DATA])

    execution_info = await erc1155.balanceOf(sender, TOKEN_ID).invoke()
    assert execution_info.result.balance == sub_uint(
        MINT_AMOUNT, TRANSFER_AMOUNT)

    execution_info = await erc1155.balanceOf(recipient, TOKEN_ID).invoke()
    assert execution_info.result.balance == TRANSFER_AMOUNT


@pytest.mark.asyncio
async def test_safe_transfer_from_approved_emits_event(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    operator = account1.contract_address
    sender = account2.contract_address
    recipient = account1.contract_address

    await signer.send_transaction(
        account2, erc1155.contract_address, 'setApprovalForAll',
        [operator, TRUE])

    # account1/operator sends transaction
    execution_info = await signer.send_transaction(
        account1, erc1155.contract_address, 'safeTransferFrom',
        [sender, recipient, *TOKEN_ID, *TRANSFER_AMOUNT, DATA])

    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='TransferSingle',
        data=[
            operator,  # operator
            sender,  # from
            recipient,  # to
            *TOKEN_ID,
            *TRANSFER_AMOUNT
        ]
    )


@pytest.mark.asyncio
async def test_safe_transfer_from_invalid_amount(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory

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
        "ERC1155: amount is not a valid Uint256"
    )


@pytest.mark.asyncio
async def test_safe_transfer_from_invalid_id(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory

    sender = account.contract_address
    recipient = owner.contract_address

    # transfer 0 amount of invalid id to avoid 
    # insufficient balance error
    await assert_revert(
        signer.send_transaction(
            account, erc1155.contract_address, 'safeTransferFrom',
            [sender, recipient, *INVALID_UINT256, *to_uint(0), DATA]),
        "ERC1155: id is not a valid Uint256"
    )


@pytest.mark.asyncio
async def test_safe_transfer_from_insufficient_balance(erc1155_minted_factory):
    erc1155, account, account2, _ = erc1155_minted_factory

    sender = account2.contract_address
    recipient = account.contract_address

    transfer_amount = add_uint(MINT_AMOUNTS[0], to_uint(1))

    await assert_revert(
        signer.send_transaction(
            account2, erc1155.contract_address, 'safeTransferFrom',
            [sender, recipient, *TOKEN_ID, *transfer_amount, DATA]),
        "ERC1155: insufficient balance for transfer"
    )


@pytest.mark.asyncio
async def test_safe_transfer_from_unapproved(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    sender = account2.contract_address
    recipient = account1.contract_address

    await assert_revert(signer.send_transaction(
        account1, erc1155.contract_address, 'safeTransferFrom',
        [sender, recipient, *TOKEN_ID, *TRANSFER_AMOUNT, DATA]),
        "ERC1155: caller is not owner nor approved")


@pytest.mark.asyncio
async def test_safe_transfer_from_to_zero_address(erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    sender = account.contract_address

    await assert_revert(signer.send_transaction(
        account, erc1155.contract_address, 'safeTransferFrom',
        [sender, ZERO_ADDRESS, *TOKEN_ID, *TRANSFER_AMOUNT, DATA]),
        "ERC1155: transfer to the zero address")


@pytest.mark.asyncio
async def test_safe_transfer_from_overflow(erc1155_minted_factory):
    erc1155, owner, account, _ = erc1155_minted_factory

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

#
# Batch Minting
#


@pytest.mark.asyncio
async def test_mint_batch(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory

    recipient = account.contract_address

    await signer.send_transaction(
        owner, erc1155.contract_address, 'mintBatch',
        [recipient, *uarr2cd(TOKEN_IDS), *uarr2cd(MINT_AMOUNTS), DATA])

    execution_info = await erc1155.balanceOfBatch(
        [recipient]*3, TOKEN_IDS).invoke()
    assert execution_info.result.balances == MINT_AMOUNTS


@pytest.mark.asyncio
async def test_mint_batch_emits_event(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory

    recipient = account.contract_address

    execution_info = await signer.send_transaction(
        owner, erc1155.contract_address, 'mintBatch',
        [recipient, *uarr2cd(TOKEN_IDS), *uarr2cd(MINT_AMOUNTS), DATA])

    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='TransferBatch',
        data=[
            owner.contract_address,  # operator
            ZERO_ADDRESS,  # from
            recipient,  # to
            *uarr2cd(TOKEN_IDS),
            *uarr2cd(MINT_AMOUNTS),
        ]
    )


@pytest.mark.asyncio
async def test_mint_batch_to_zero_address(erc1155_factory):
    erc1155, owner, _, _ = erc1155_factory

    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mintBatch',
            [ZERO_ADDRESS, *uarr2cd(TOKEN_IDS), *uarr2cd(MINT_AMOUNTS), DATA]),
        "ERC1155: mint to the zero address")


@pytest.mark.asyncio
async def test_mint_batch_overflow(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory

    recipient = account.contract_address

    # Bring recipient's balance to max possible
    await signer.send_transaction(
        owner, erc1155.contract_address, 'mintBatch',
        [recipient, *uarr2cd(TOKEN_IDS), *uarr2cd(MAX_UINT_AMOUNTS), DATA])

    # Issuing recipient any more on just 1 token_id
    # should revert due to overflow
    amounts = uint_array([0, 1, 0])
    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mintBatch',
            [recipient, *uarr2cd(TOKEN_IDS), *uarr2cd(amounts), DATA]),
        "ERC1155: balance overflow")


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "amounts,token_ids,error",
    [
        (INVALID_AMOUNTS, TOKEN_IDS, "ERC1155: amount is not a valid Uint256"),
        (MINT_AMOUNTS, INVALID_IDS, "ERC1155: id is not a valid Uint256")
    ])
async def test_mint_batch_invalid_uint(
        erc1155_factory, amounts, token_ids, error):
    erc1155, owner, account, _ = erc1155_factory

    recipient = account.contract_address

    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mintBatch',
            [recipient, *uarr2cd(token_ids), *uarr2cd(amounts), DATA]),
        error)


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "amounts,token_ids",
    [
        (MINT_AMOUNTS[:2], TOKEN_IDS),
        (MINT_AMOUNTS, TOKEN_IDS[:2])
    ])
async def test_mint_batch_uneven_arrays(erc1155_factory, amounts, token_ids):
    erc1155, owner, account, _ = erc1155_factory

    recipient = account.contract_address

    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mintBatch',
            [recipient, *uarr2cd(token_ids), *uarr2cd(amounts), DATA]),
        "ERC1155: ids and amounts length mismatch")


@pytest.mark.asyncio
async def test_mint_batch_to_receiver(erc1155_factory):
    erc1155, owner, _, receiver = erc1155_factory

    recipient = receiver.contract_address

    await signer.send_transaction(
        owner, erc1155.contract_address, 'mintBatch',
        [
            recipient, *uarr2cd(TOKEN_IDS),
            *uarr2cd(MINT_AMOUNTS), DATA
        ])

    execution_info = await erc1155.balanceOfBatch(
        [recipient]*3, TOKEN_IDS).invoke()
    assert execution_info.result.balances == MINT_AMOUNTS


@pytest.mark.asyncio
async def test_mint_batch_to_receiver_rejection(erc1155_factory):
    erc1155, owner, _, receiver = erc1155_factory

    recipient = receiver.contract_address

    await assert_revert(signer.send_transaction(
        owner, erc1155.contract_address, 'mintBatch',
        [
            recipient, *uarr2cd(TOKEN_IDS),
            *uarr2cd(MINT_AMOUNTS), *REJECT_DATA
        ]),
        "ERC1155: ERC1155Receiver rejected tokens")


@pytest.mark.asyncio
async def test_mint_batch_to_non_receiver(erc1155_factory):
    erc1155, owner, _, _ = erc1155_factory

    recipient = erc1155.contract_address

    await assert_revert(signer.send_transaction(
        owner, erc1155.contract_address, 'mintBatch',
        [
            recipient, *uarr2cd(TOKEN_IDS),
            *uarr2cd(MINT_AMOUNTS), DATA
        ]),
        "ERC1155: transfer to non ERC1155Receiver implementer")

#
# Batch Burning
#


@pytest.mark.asyncio
async def test_burn_batch(erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    burner = account.contract_address

    await signer.send_transaction(
        account, erc1155.contract_address, 'burnBatch',
        [burner, *uarr2cd(TOKEN_IDS), *uarr2cd(BURN_AMOUNTS)])

    execution_info = await erc1155.balanceOfBatch(
        [burner]*3, TOKEN_IDS).invoke()
    assert execution_info.result.balances == BURN_DIFFERENCES


@pytest.mark.asyncio
async def test_burn_batch_emits_event(erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    burner = account.contract_address

    execution_info = await signer.send_transaction(
        account, erc1155.contract_address, 'burnBatch',
        [burner, *uarr2cd(TOKEN_IDS), *uarr2cd(BURN_AMOUNTS)])

    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='TransferBatch',
        data=[
            burner,  # operator
            burner,  # from
            ZERO_ADDRESS,  # to
            *uarr2cd(TOKEN_IDS),
            *uarr2cd(BURN_AMOUNTS),
        ]
    )


@pytest.mark.asyncio
async def test_burn_batch_from_approved(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    burner = account2.contract_address
    operator = account1.contract_address

    await signer.send_transaction(
        account2, erc1155.contract_address, 'setApprovalForAll',
        [operator, TRUE])

    await signer.send_transaction(
        account1, erc1155.contract_address, 'burnBatch',
        [burner, *uarr2cd(TOKEN_IDS), *uarr2cd(BURN_AMOUNTS)])

    execution_info = await erc1155.balanceOfBatch(
        [burner]*3, TOKEN_IDS).invoke()
    assert execution_info.result.balances == BURN_DIFFERENCES


@pytest.mark.asyncio
async def test_burn_batch_from_approved_emits_event(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    burner = account2.contract_address
    operator = account1.contract_address

    await signer.send_transaction(
        account2, erc1155.contract_address, 'setApprovalForAll',
        [operator, TRUE])

    execution_info = await signer.send_transaction(
        account1, erc1155.contract_address, 'burnBatch',
        [burner, *uarr2cd(TOKEN_IDS), *uarr2cd(BURN_AMOUNTS)])

    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='TransferBatch',
        data=[
            operator,  # operator
            burner,  # from
            ZERO_ADDRESS,  # to
            *uarr2cd(TOKEN_IDS),
            *uarr2cd(BURN_AMOUNTS),
        ]
    )


@pytest.mark.asyncio
async def test_burn_batch_from_unapproved(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    burner = account2.contract_address
    operator = account1.contract_address

    await signer.send_transaction(
        account2, erc1155.contract_address, 'setApprovalForAll',
        [operator, FALSE])

    await assert_revert(signer.send_transaction(
        account1, erc1155.contract_address, 'burnBatch',
        [burner, *uarr2cd(TOKEN_IDS), *uarr2cd(BURN_AMOUNTS)]),
        "ERC1155: caller is not owner nor approved")


@pytest.mark.asyncio
async def test_burn_batch_from_zero_address(erc1155_minted_factory):
    erc1155, _, _, _ = erc1155_minted_factory

    amounts = [to_uint(0)]*3

    # Attempt to burn nothing (since cannot mint non_zero balance to burn)
    # note invoking this way (without signer) gives caller address of 0
    await assert_revert(
        erc1155.burnBatch(ZERO_ADDRESS, TOKEN_IDS, amounts).invoke(),
        "ERC1155: called from zero address")


@pytest.mark.asyncio
async def test_burn_batch_insufficent_balance(erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    burner = account.contract_address
    amounts = MINT_AMOUNTS.copy()
    amounts[1] = add_uint(amounts[1], to_uint(1))

    await assert_revert(
        signer.send_transaction(
            account, erc1155.contract_address, 'burnBatch',
            [burner, *uarr2cd(TOKEN_IDS), *uarr2cd(amounts)]),
        "ERC1155: burn amount exceeds balance")


@pytest.mark.asyncio
async def test_burn_batch_invalid_amount(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory

    burner = account.contract_address

    # mint max possible to avoid insufficient balance
    await signer.send_transaction(
        owner, erc1155.contract_address, 'mintBatch',
        [burner, *uarr2cd(TOKEN_IDS), *uarr2cd(MAX_UINT_AMOUNTS), 0])

    # attempt passing an invalid uint in batch
    await assert_revert(
        signer.send_transaction(
            account, erc1155.contract_address, 'burnBatch',
            [burner, *uarr2cd(TOKEN_IDS), *uarr2cd(INVALID_AMOUNTS)]),
        "ERC1155: amount is not a valid Uint256")


@pytest.mark.asyncio
async def test_burn_batch_invalid_id(erc1155_minted_factory):
    erc1155, owner, account, _ = erc1155_minted_factory

    burner = account.contract_address
    burn_amounts = [to_uint(0)]*3

    await assert_revert(
        signer.send_transaction(
            account, erc1155.contract_address, 'burnBatch',
            [burner, *uarr2cd(INVALID_IDS), *uarr2cd(burn_amounts)]),
        "ERC1155: id is not a valid Uint256")


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "amounts,token_ids",
    [
        (BURN_AMOUNTS[:2], TOKEN_IDS),
        (BURN_AMOUNTS, TOKEN_IDS[:2])
    ]
)
async def test_burn_batch_uneven_arrays(
        erc1155_minted_factory, amounts, token_ids):
    erc1155, _, account, _ = erc1155_minted_factory

    burner = account.contract_address

    await assert_revert(
        signer.send_transaction(
            account, erc1155.contract_address, 'burnBatch',
            [burner, *uarr2cd(token_ids), *uarr2cd(amounts)]),
        "ERC1155: ids and amounts length mismatch")

#
# Batch Transfers
#


@pytest.mark.asyncio
async def test_safe_batch_transfer_from(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    sender = account2.contract_address
    recipient = account1.contract_address

    await signer.send_transaction(
        account2, erc1155.contract_address, 'safeBatchTransferFrom',
        [
            sender, recipient, *uarr2cd(TOKEN_IDS),
            *uarr2cd(TRANSFER_AMOUNTS), DATA
        ])

    execution_info = await erc1155.balanceOfBatch(
        [sender]*3+[recipient]*3, TOKEN_IDS*2).invoke()
    assert execution_info.result.balances[:3] == TRANSFER_DIFFERENCES
    assert execution_info.result.balances[3:] == TRANSFER_AMOUNTS


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_emits_event(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    sender = account2.contract_address
    recipient = account1.contract_address

    execution_info = await signer.send_transaction(
        account2, erc1155.contract_address, 'safeBatchTransferFrom',
        [
            sender, recipient, *uarr2cd(TOKEN_IDS),
            *uarr2cd(TRANSFER_AMOUNTS), DATA
        ])

    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='TransferBatch',
        data=[
            sender,  # operator
            sender,  # from
            recipient,  # to
            *uarr2cd(TOKEN_IDS),
            *uarr2cd(TRANSFER_AMOUNTS),
        ]
    )


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_approved(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    sender = account2.contract_address
    operator = account1.contract_address
    recipient = account1.contract_address

    await signer.send_transaction(
        account2, erc1155.contract_address, 'setApprovalForAll',
        [operator, TRUE])

    await signer.send_transaction(
        account1, erc1155.contract_address, 'safeBatchTransferFrom',
        [
            sender, recipient, *uarr2cd(TOKEN_IDS),
            *uarr2cd(TRANSFER_AMOUNTS), DATA
        ])

    execution_info = await erc1155.balanceOfBatch(
        [sender]*3+[recipient]*3, TOKEN_IDS*2).invoke()
    assert execution_info.result.balances[:3] == TRANSFER_DIFFERENCES
    assert execution_info.result.balances[3:] == TRANSFER_AMOUNTS


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_approved_emits_event(
        erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    sender = account2.contract_address
    operator = account1.contract_address
    recipient = account1.contract_address

    await signer.send_transaction(
        account2, erc1155.contract_address, 'setApprovalForAll',
        [operator, TRUE])

    execution_info = await signer.send_transaction(
        account1, erc1155.contract_address, 'safeBatchTransferFrom',
        [
            sender, recipient, *uarr2cd(TOKEN_IDS),
            *uarr2cd(TRANSFER_AMOUNTS), DATA
        ])

    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='TransferBatch',
        data=[
            operator,  # operator
            sender,  # from
            recipient,  # to
            *uarr2cd(TOKEN_IDS),
            *uarr2cd(TRANSFER_AMOUNTS),
        ]
    )


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_invalid_amount(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory

    sender = account.contract_address
    recipient = owner.contract_address

    await signer.send_transaction(
        owner, erc1155.contract_address, 'mintBatch',
        [sender, *uarr2cd(TOKEN_IDS), *uarr2cd(MAX_UINT_AMOUNTS), DATA])

    await assert_revert(signer.send_transaction(
        account, erc1155.contract_address, 'safeBatchTransferFrom',
        [
            sender, recipient, *uarr2cd(TOKEN_IDS),
            *uarr2cd(INVALID_AMOUNTS), DATA
        ]),
        "ERC1155: amount is not a valid Uint256")


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_invalid_id(erc1155_minted_factory):
    erc1155, owner, account, _ = erc1155_minted_factory

    sender = account.contract_address
    recipient = owner.contract_address
    transfer_amounts = [to_uint(0)]*3

    await assert_revert(
        signer.send_transaction(
            account, erc1155.contract_address, 'safeBatchTransferFrom',
            [
                sender, recipient, *uarr2cd(INVALID_IDS),
                *uarr2cd(transfer_amounts), DATA
            ]),
        "ERC1155: id is not a valid Uint256")


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_insufficient_balance(
        erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    sender = account2.contract_address
    recipient = account1.contract_address

    amounts = amounts = MINT_AMOUNTS.copy()
    amounts[1] = add_uint(amounts[1], to_uint(1))

    await assert_revert(signer.send_transaction(
        account2, erc1155.contract_address, 'safeBatchTransferFrom',
        [sender, recipient, *uarr2cd(TOKEN_IDS), *uarr2cd(amounts), DATA]),
        "ERC1155: insufficient balance for transfer")


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_unapproved(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    sender = account2.contract_address
    recipient = account1.contract_address

    await assert_revert(signer.send_transaction(
        account1, erc1155.contract_address, 'safeBatchTransferFrom',
        [
            sender, recipient, *uarr2cd(TOKEN_IDS),
            *uarr2cd(TRANSFER_AMOUNTS), DATA
        ]),
        "ERC1155: caller is not owner nor approved")


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_to_zero_address(
        erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    sender = account.contract_address

    await assert_revert(signer.send_transaction(
        account, erc1155.contract_address, 'safeBatchTransferFrom',
        [
            sender, ZERO_ADDRESS, *uarr2cd(TOKEN_IDS),
            *uarr2cd(TRANSFER_AMOUNTS), DATA
        ]),
        "ERC1155: transfer to the zero address")


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "amounts,token_ids",
    [(TRANSFER_AMOUNTS[:2], TOKEN_IDS), (TRANSFER_AMOUNTS, TOKEN_IDS[:2])]
)
async def test_safe_batch_transfer_from_uneven_arrays(
        erc1155_minted_factory, amounts, token_ids):
    erc1155, account1, account2, _ = erc1155_minted_factory

    sender = account2.contract_address
    recipient = account1.contract_address

    await assert_revert(signer.send_transaction(
        account2, erc1155.contract_address, 'safeBatchTransferFrom',
        [sender, recipient, *uarr2cd(token_ids), *uarr2cd(amounts), DATA]),
        "ERC1155: ids and amounts length mismatch")


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_overflow(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    sender = account2.contract_address
    recipient = account1.contract_address
    transfer_amounts = uint_array([0, 1, 0])

    # Bring 1 recipient's balance to max possible
    await signer.send_transaction(
        account1, erc1155.contract_address, 'mintBatch',
        [recipient, *uarr2cd(TOKEN_IDS), *uarr2cd(MAX_UINT_AMOUNTS), DATA]
    )

    # Issuing recipient any more on just 1 token_id
    # should revert due to overflow
    await assert_revert(signer.send_transaction(
        account2, erc1155.contract_address, 'safeBatchTransferFrom',
        [
            sender, recipient, *uarr2cd(TOKEN_IDS),
            *uarr2cd(transfer_amounts), DATA
        ]),
        "ERC1155: balance overflow")


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_to_receiver(erc1155_minted_factory):
    erc1155, _, account2, receiver = erc1155_minted_factory

    sender = account2.contract_address
    recipient = receiver.contract_address

    await signer.send_transaction(
        account2, erc1155.contract_address, 'safeBatchTransferFrom',
        [
            sender, recipient, *uarr2cd(TOKEN_IDS),
            *uarr2cd(TRANSFER_AMOUNTS), DATA
        ])

    execution_info = await erc1155.balanceOfBatch(
        [sender]*3+[recipient]*3, TOKEN_IDS*2).invoke()
    assert execution_info.result.balances[:3] == TRANSFER_DIFFERENCES
    assert execution_info.result.balances[3:] == TRANSFER_AMOUNTS


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_to_receiver_rejection(
        erc1155_minted_factory):
    erc1155, _, account2, receiver = erc1155_minted_factory

    sender = account2.contract_address
    recipient = receiver.contract_address

    await assert_revert(signer.send_transaction(
        account2, erc1155.contract_address, 'safeBatchTransferFrom',
        [
            sender, recipient, *uarr2cd(TOKEN_IDS),
            *uarr2cd(TRANSFER_AMOUNTS), *REJECT_DATA
        ]),
        "ERC1155: ERC1155Receiver rejected tokens")


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_to_non_receiver(
        erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    sender = account.contract_address
    recipient = erc1155.contract_address

    await assert_revert(signer.send_transaction(
        account, erc1155.contract_address, 'safeBatchTransferFrom',
        [
            sender, recipient, *uarr2cd(TOKEN_IDS),
            *uarr2cd(TRANSFER_AMOUNTS), DATA
        ]),
        "ERC1155: transfer to non ERC1155Receiver implementer")
