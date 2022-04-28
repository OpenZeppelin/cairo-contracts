import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils import (
    Signer, uint, add_uint, sub_uint, MAX_UINT256, get_contract_def, cached_contract, assert_revert, assert_event_emitted)

signer = Signer(123456789987654321)
account_path = 'openzeppelin/account/Account.cairo'
erc1155_path = 'openzeppelin/token/erc1155/ERC1155_Mintable_Burnable.cairo'
receiver_path = 'tests/mocks/ERC1155_receiver_mock.cairo'


def uint_array(arr):
    return list(map(uint, arr))


def uarr2cd(arr):
    acc = [len(arr)]
    for lo, hi in arr:
        acc.append(lo)
        acc.append(hi)
    return acc
# Constants


TRUE = 1
FALSE = 0
NON_BOOLEAN = 2
ZERO_ADDRESS = 0

DATA = []

TOKEN_ID = uint(111)
MINT_AMOUNT = uint(1000)
BURN_AMOUNT = uint(500)
TRANSFER_AMOUNT = uint(500)
INVALID_UINT = uint(MAX_UINT256[0]+1)

ACCOUNT = 123
ACCOUNTS = [123, 234, 345]
TOKEN_IDS = uint_array([111, 222, 333])
MINT_AMOUNTS = uint_array([1000, 2000, 3000])
BURN_AMOUNTS = uint_array([500, 1000, 1500])
TRANSFER_AMOUNTS = uint_array([500, 1000, 1500])
TRANSFER_DIFFERENCE = [uint(m[0]-t[0])
                       for m, t in zip(MINT_AMOUNTS, TRANSFER_AMOUNTS)]
INVALID_AMOUNTS = uint_array([1, MAX_UINT256[0]+1, 1])
INVALID_IDS = uint_array([111, MAX_UINT256[0]+1, 333])

MAX_UINT_AMOUNTS = [uint(1), MAX_UINT256, uint(1)]

id_ERC165 = int('0x01ffc9a7', 16)
id_IERC1155 = int('0xd9b67a26', 16)
id_IERC1155_MetadataURI = int('0x0e89341c', 16)
id_mandatory_unsupported = int('0xffffffff', 16)
id_random = int('0xaabbccdd', 16)

SUPPORTED_INTERFACES = [id_ERC165, id_IERC1155, id_IERC1155_MetadataURI]
UNSUPPORTED_INTERFACES = [id_mandatory_unsupported, id_random]


# Fixtures

@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
def contract_defs():
    account_def = get_contract_def(account_path)
    erc1155_def = get_contract_def(erc1155_path)
    receiver_def = get_contract_def(receiver_path)
    return account_def, erc1155_def, receiver_def


@pytest.fixture(scope='module')
async def erc1155_init(contract_defs):
    account_def, erc1155_def, receiver_def = contract_defs
    starknet = await Starknet.empty()
    account1 = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )
    account2 = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )
    erc1155 = await starknet.deploy(
        contract_def=erc1155_def,
        constructor_calldata=[0, account1.contract_address]
    )
    receiver = await starknet.deploy(
        contract_def=receiver_def
    )
    return (
        starknet.state,
        account1,
        account2,
        erc1155,
        receiver
    )


@pytest.fixture
def erc1155_factory(contract_defs, erc1155_init):
    account_def, erc1155_def, receiver_def = contract_defs
    state, account1, account2, erc1155, receiver = erc1155_init
    _state = state.copy()
    account1 = cached_contract(_state, account_def, account1)
    account2 = cached_contract(_state, account_def, account2)
    erc1155 = cached_contract(_state, erc1155_def, erc1155)
    receiver = cached_contract(_state, receiver_def, receiver)
    return erc1155, account1, account2, receiver


@pytest.fixture(scope='module')
async def erc1155_minted_init(contract_defs, erc1155_init):
    account_def, erc1155_def, receiver_def = contract_defs
    state, owner, account, erc1155, receiver = erc1155_init
    _state = state.copy()
    owner = cached_contract(_state, account_def, owner)
    account = cached_contract(_state, account_def, account)
    erc1155 = cached_contract(_state, erc1155_def, erc1155)
    receiver = cached_contract(_state, receiver_def, receiver)
    await signer.send_transaction(
        owner, erc1155.contract_address, 'mintBatch',
        [
            account.contract_address,  # to
            *uarr2cd(TOKEN_IDS),  # ids
            *uarr2cd(MINT_AMOUNTS),  # amounts
            0  # data
        ]
    )
    return _state, erc1155, owner, account, receiver


@pytest.fixture
def erc1155_minted_factory(contract_defs, erc1155_minted_init):
    account_def, erc1155_def, receiver_def = contract_defs
    state, erc1155, owner, account, receiver = erc1155_minted_init
    _state = state.copy()
    owner = cached_contract(_state, account_def, owner)
    account = cached_contract(_state, account_def, account)
    erc1155 = cached_contract(_state, erc1155_def, erc1155)
    receiver = cached_contract(_state, receiver_def, receiver)
    return erc1155, owner, account, receiver


# Tests

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
async def test_supports_interface(erc1155_factory):
    erc1155, _, _, _ = erc1155_factory

    for supported_id in SUPPORTED_INTERFACES:
        execution_info = await erc1155.supportsInterface(
            supported_id
        ).invoke()
        assert execution_info.result.is_supported == TRUE

    for unsupported_id in UNSUPPORTED_INTERFACES:
        execution_info = await erc1155.supportsInterface(
            unsupported_id
        ).invoke()
        assert execution_info.result.is_supported == FALSE

#
# Set/Get approval
#


@pytest.mark.asyncio
async def test_set_approval_for_all(erc1155_factory):
    erc1155, account, _, _ = erc1155_factory

    operator = ACCOUNT
    approval = TRUE

    await signer.send_transaction(
        account, erc1155.contract_address, 'setApprovalForAll',
        [operator, approval]
    )

    execution_info = await erc1155.isApprovedForAll(
        account.contract_address,
        operator
    ).invoke()

    assert execution_info.result.is_approved == approval

    operator = ACCOUNT
    approval = FALSE

    await signer.send_transaction(
        account, erc1155.contract_address, 'setApprovalForAll',
        [operator, approval]
    )

    execution_info = await erc1155.isApprovedForAll(
        account.contract_address,
        operator
    ).invoke()

    assert execution_info.result.is_approved == approval


@pytest.mark.asyncio
async def test_set_approval_for_all_emits_event(erc1155_factory):
    erc1155, account, _, _ = erc1155_factory

    operator = ACCOUNT
    approval = TRUE

    execution_info = await signer.send_transaction(
        account, erc1155.contract_address, 'setApprovalForAll',
        [operator, approval]
    )
    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='ApprovalForAll',
        data=[
            account.contract_address,
            operator,  # operator
            approval
        ]
    )

    operator = ACCOUNT
    approval = FALSE

    execution_info = await signer.send_transaction(
        account, erc1155.contract_address, 'setApprovalForAll',
        [operator, approval]
    )
    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='ApprovalForAll',
        data=[
            account.contract_address,
            operator,  # operator
            approval
        ]
    )


@pytest.mark.asyncio
async def test_set_approval_for_all_non_boolean(erc1155_factory):
    erc1155, account, _, _ = erc1155_factory

    operator = ACCOUNT
    approval = NON_BOOLEAN

    await assert_revert(signer.send_transaction(
        account, erc1155.contract_address, 'setApprovalForAll',
        [operator, approval]
    ))

#
# Balance getters
#


@pytest.mark.asyncio
async def test_balance_of(erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory
    user = account.contract_address
    execution_info = await erc1155.balanceOf(user, TOKEN_IDS[0]).invoke()
    assert execution_info.result.balance == MINT_AMOUNTS[0]


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
async def test_balance_of_batch_uneven_arrays(erc1155_factory):
    erc1155, _, _, _ = erc1155_factory

    accounts = ACCOUNTS
    ids = TOKEN_IDS

    # len(accounts) != len(ids)
    await assert_revert(
        erc1155.balanceOfBatch(accounts[:2], ids).invoke(),
        "ERC1155: accounts and ids length mismatch")
    await assert_revert(
        erc1155.balanceOfBatch(accounts, ids[:2]).invoke(),
        "ERC1155: accounts and ids length mismatch")


#
# Minting
#

@pytest.mark.asyncio
async def test_mint(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory
    recipient = account.contract_address
    token_id = TOKEN_ID
    amount = MINT_AMOUNT

    await signer.send_transaction(
        owner, erc1155.contract_address, 'mint',
        [
            recipient,
            *token_id,
            *amount,
            0  # data
        ]
    )

    execution_info = await erc1155.balanceOf(recipient, token_id).invoke()
    assert execution_info.result.balance == amount


@pytest.mark.asyncio
async def test_mint_emits_event(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory
    recipient = account.contract_address
    token_id = TOKEN_ID
    amount = MINT_AMOUNT

    execution_info = await signer.send_transaction(
        owner, erc1155.contract_address, 'mint',
        [
            recipient,
            *token_id,
            *amount,
            0  # data
        ]
    )

    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='TransferSingle',
        data=[
            owner.contract_address,  # operator
            ZERO_ADDRESS,  # from
            recipient,  # to
            *token_id,
            *amount
        ]
    )


@pytest.mark.asyncio
async def test_mint_to_zero_address(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory

    recipient = ZERO_ADDRESS
    token_id = TOKEN_ID
    amount = MINT_AMOUNT

    # minting to 0 address should fail
    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mint',
            [
                recipient,  # to
                *token_id,
                *amount,
                0  # data
            ]
        ),
        "ERC1155: mint to the zero address"
    )


@pytest.mark.asyncio
async def test_mint_overflow(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory

    recipient = account.contract_address
    token_id = TOKEN_ID

    # Bring recipient's balance to max possible, should pass (recipient's balance is 0)
    amount = MAX_UINT256
    await signer.send_transaction(
        owner, erc1155.contract_address, 'mint',
        [
            recipient,  # to
            *token_id,
            *amount,
            0  # data
        ]
    )

    # Issuing recipient any more should revert due to overflow
    amount = uint(1)
    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mint',
            [
                recipient,  # to
                *token_id,
                *amount,
                0  # data
            ]
        ),
        "ERC1155: balance overflow"
    )

    # upon rejection, there should be MAX balance
    execution_info = await erc1155.balanceOf(recipient, token_id).invoke()
    assert execution_info.result.balance == MAX_UINT256


@pytest.mark.asyncio
async def test_mint_invalid_uint(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory

    recipient = account.contract_address
    token_id = TOKEN_ID
    invalid_id = INVALID_UINT
    amount = MINT_AMOUNT
    invalid_amount = INVALID_UINT

    # issuing an invalid uint256 (i.e. either the low or high felts >= 2**128) should revert
    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mint',
            [
                recipient,  # to
                *token_id,
                *invalid_amount,
                0  # data
            ]
        ),
        "ERC1155: amount is not a valid Uint256"
    )
    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mint',
            [
                recipient,  # to
                *invalid_id,
                *amount,
                0  # data
            ]
        ),
        "ERC1155: id is not a valid Uint256"
    )

    # balance should remain 0 <- redundant
    # execution_info = await erc1155.balanceOf(recipient,token_id).invoke()
    # assert execution_info.result.balance == uint(0)

#
# Burning
#


@pytest.mark.asyncio
async def test_burn(erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    subject = account.contract_address
    token_id = TOKEN_ID
    burn_amount = BURN_AMOUNT

    await signer.send_transaction(
        account, erc1155.contract_address, 'burn',
        [subject, *token_id, *burn_amount]
    )

    execution_info = await erc1155.balanceOf(subject, token_id).invoke()
    assert execution_info.result.balance == sub_uint(MINT_AMOUNT, burn_amount)


@pytest.mark.asyncio
async def test_burn_emits_event(erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    subject = account.contract_address
    token_id = TOKEN_ID
    burn_amount = BURN_AMOUNT

    execution_info = await signer.send_transaction(
        account, erc1155.contract_address, 'burn',
        [subject, *token_id, *burn_amount]
    )

    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='TransferSingle',
        data=[
            subject,  # operator
            subject,  # from
            ZERO_ADDRESS,  # to
            *token_id,
            *burn_amount
        ]
    )


@pytest.mark.asyncio
async def test_burn_approved(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    operator = account1.contract_address
    subject = account2.contract_address
    token_id = TOKEN_ID
    burn_amount = BURN_AMOUNT
    approval = TRUE

    # account2 approves account
    await signer.send_transaction(
        account2, erc1155.contract_address, 'setApprovalForAll',
        [operator, approval])

    await signer.send_transaction(
        account1, erc1155.contract_address, 'burn',
        [subject, *token_id, *burn_amount]
    )

    execution_info = await erc1155.balanceOf(subject, token_id).invoke()
    assert execution_info.result.balance == sub_uint(MINT_AMOUNT, burn_amount)


@pytest.mark.asyncio
async def test_burn_approved_emits_event(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    operator = account1.contract_address
    subject = account2.contract_address
    token_id = TOKEN_ID
    burn_amount = BURN_AMOUNT
    approval = TRUE

    # account2 approves account
    await signer.send_transaction(
        account2, erc1155.contract_address, 'setApprovalForAll',
        [operator, approval])

    execution_info = await signer.send_transaction(
        account1, erc1155.contract_address, 'burn',
        [subject, *token_id, *burn_amount]
    )

    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='TransferSingle',
        data=[
            operator,  # operator
            subject,  # from
            ZERO_ADDRESS,  # to
            *token_id,
            *burn_amount
        ]
    )


@pytest.mark.asyncio
async def test_burn_insufficient_balance(erc1155_factory):
    erc1155, _, account, _ = erc1155_factory

    subject = account.contract_address
    token_id = TOKEN_ID
    burn_amount = BURN_AMOUNT

    # Burn non-0 amount w/ 0 balance
    await assert_revert(
        signer.send_transaction(
            account, erc1155.contract_address, 'burn',
            [subject, *token_id, *burn_amount]),
        "ERC1155: burn amount exceeds balance"
    )

# batch minting


@pytest.mark.asyncio
async def test_mint_batch(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory

    recipient = account.contract_address
    token_ids = TOKEN_IDS
    amounts = MINT_AMOUNTS

    # mint amount[i] of token_id[i] to recipient
    await signer.send_transaction(
        owner, erc1155.contract_address, 'mintBatch',
        [recipient, *uarr2cd(token_ids), *uarr2cd(amounts), 0])

    execution_info = await erc1155.balanceOfBatch([recipient]*3, token_ids).invoke()
    assert execution_info.result.balances == amounts


@pytest.mark.asyncio
async def test_mint_batch_emits_event(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory

    recipient = account.contract_address
    token_ids = TOKEN_IDS
    amounts = MINT_AMOUNTS

    # mint amount[i] of token_id[i] to recipient
    execution_info = await signer.send_transaction(
        owner, erc1155.contract_address, 'mintBatch',
        [recipient, *uarr2cd(token_ids), *uarr2cd(amounts), 0])

    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='TransferBatch',
        data=[
            owner.contract_address,  # operator
            ZERO_ADDRESS,  # from
            recipient,  # to
            *uarr2cd(token_ids),
            *uarr2cd(amounts),
        ]
    )


@pytest.mark.asyncio
async def test_mint_batch_to_zero_address(erc1155_factory):
    erc1155, owner, _, _ = erc1155_factory

    recipient = ZERO_ADDRESS
    token_ids = TOKEN_IDS
    amounts = MINT_AMOUNTS

    # mint amount[i] of token_id[i] to recipient
    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mintBatch',
            [recipient, *uarr2cd(token_ids), *uarr2cd(amounts), 0]),
        "ERC1155: mint to the zero address"
    )


@pytest.mark.asyncio
async def test_mint_batch_overflow(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory

    recipient = account.contract_address
    token_ids = TOKEN_IDS
    amounts = MAX_UINT_AMOUNTS

    # Bring 1 recipient's balance to max possible, should pass (recipient's balance is 0)
    await signer.send_transaction(
        owner, erc1155.contract_address, 'mintBatch',
        [recipient, *uarr2cd(token_ids), *uarr2cd(amounts), 0])

    # Issuing recipient any more on just 1 token_id should revert due to overflow
    amounts = uint_array([0, 1, 0])
    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mintBatch',
            [recipient, *uarr2cd(token_ids), *uarr2cd(amounts), 0]),
        "ERC1155: balance overflow"
    )


@pytest.mark.asyncio
async def test_mint_batch_invalid_uint(erc1155_factory):
    erc1155, owner, _, _ = erc1155_factory

    recipient = ACCOUNT
    token_ids = TOKEN_IDS
    invalid_ids = INVALID_IDS
    amounts = MINT_AMOUNTS
    invalid_amounts = INVALID_AMOUNTS

    # attempt passing an invalid amount in batch
    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mintBatch',
            [recipient, *uarr2cd(token_ids), *uarr2cd(invalid_amounts), 0]),
        "ERC1155: amount is not a valid Uint256"
    )

    # attempt passing an invalid id in batch
    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mintBatch',
            [recipient, *uarr2cd(invalid_ids), *uarr2cd(amounts), 0]),
        "ERC1155: id is not a valid Uint256"
    )


@pytest.mark.asyncio
async def test_mint_batch_uneven_arrays(erc1155_factory):
    erc1155, owner, _, _ = erc1155_factory

    recipient = ACCOUNT
    token_ids = TOKEN_IDS
    amounts = MINT_AMOUNTS

    # uneven token_ids vs amounts
    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mintBatch',
            [recipient, *uarr2cd(token_ids), *uarr2cd(amounts[:2]), 0]),
        "ERC1155: ids and amounts length mismatch"
    )

    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mintBatch',
            [recipient, *uarr2cd(token_ids[:2]), *uarr2cd(amounts), 0]),
        "ERC1155: ids and amounts length mismatch"
    )

#
# batch burning
#


@pytest.mark.asyncio
async def test_burn_batch(erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    burner = account.contract_address
    token_ids = TOKEN_IDS
    burn_amounts = BURN_AMOUNTS

    await signer.send_transaction(
        account, erc1155.contract_address, 'burnBatch',
        [burner, *uarr2cd(token_ids), *uarr2cd(burn_amounts)])

    execution_info = await erc1155.balanceOfBatch([burner]*3, token_ids).invoke()
    assert execution_info.result.balances == [
        sub_uint(m, b) for m, b in zip(MINT_AMOUNTS, burn_amounts)]


@pytest.mark.asyncio
async def test_burn_batch_emits_event(erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    burner = account.contract_address
    token_ids = TOKEN_IDS
    burn_amounts = BURN_AMOUNTS

    execution_info = await signer.send_transaction(
        account, erc1155.contract_address, 'burnBatch',
        [burner, *uarr2cd(token_ids), *uarr2cd(burn_amounts)])

    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='TransferBatch',
        data=[
            burner,  # operator
            burner,  # from
            ZERO_ADDRESS,  # to
            *uarr2cd(token_ids),
            *uarr2cd(burn_amounts),
        ]
    )


@pytest.mark.asyncio
async def test_burn_batch_from_approved(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    burner = account2.contract_address
    operator = account1.contract_address
    token_ids = TOKEN_IDS
    burn_amounts = BURN_AMOUNTS
    approval = TRUE

    # account approves account2
    await signer.send_transaction(
        account2, erc1155.contract_address, 'setApprovalForAll',
        [operator, approval])

    await signer.send_transaction(
        account1, erc1155.contract_address, 'burnBatch',
        [burner, *uarr2cd(token_ids), *uarr2cd(burn_amounts)])

    execution_info = await erc1155.balanceOfBatch([burner]*3, token_ids).invoke()
    assert execution_info.result.balances == [
        sub_uint(m, b) for m, b in zip(MINT_AMOUNTS, burn_amounts)]


@pytest.mark.asyncio
async def test_burn_batch_from_approved_emits_event(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    burner = account2.contract_address
    operator = account1.contract_address
    token_ids = TOKEN_IDS
    burn_amounts = BURN_AMOUNTS
    approval = TRUE

    # account approves account2
    await signer.send_transaction(
        account2, erc1155.contract_address, 'setApprovalForAll',
        [operator, approval])

    execution_info = await signer.send_transaction(
        account1, erc1155.contract_address, 'burnBatch',
        [burner, *uarr2cd(token_ids), *uarr2cd(burn_amounts)])

    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='TransferBatch',
        data=[
            operator,  # operator
            burner,  # from
            ZERO_ADDRESS,  # to
            *uarr2cd(token_ids),
            *uarr2cd(burn_amounts),
        ]
    )


@pytest.mark.asyncio
async def test_burn_batch_from_unapproved(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    burner = account2.contract_address
    operator = account1.contract_address
    token_ids = TOKEN_IDS
    burn_amounts = BURN_AMOUNTS
    approval = FALSE

    # account approves account2
    await signer.send_transaction(
        account2, erc1155.contract_address, 'setApprovalForAll',
        [operator, approval])

    await assert_revert(signer.send_transaction(
        account1, erc1155.contract_address, 'burnBatch',
        [burner, *uarr2cd(token_ids), *uarr2cd(burn_amounts)]))


@pytest.mark.asyncio
async def test_burn_batch_from_zero_address(erc1155_minted_factory):
    erc1155, _, _, _ = erc1155_minted_factory
    burner = ZERO_ADDRESS
    token_ids = TOKEN_IDS
    amounts = [uint(0)]*3

    # Attempt to burn nothing (since cannot mint non_zero balance to burn)
    # call from 0 address
    await assert_revert(
        erc1155.burnBatch(burner, token_ids, amounts).invoke()  # ,
        # "ERC1155: burn from the zero address"
    )


@pytest.mark.asyncio
async def test_burn_batch_insufficent_balance(erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    burner = account.contract_address
    token_ids = TOKEN_IDS
    amounts = [MINT_AMOUNTS[0], add_uint(
        MINT_AMOUNTS[1], uint(1)), MINT_AMOUNTS[2]]

    await assert_revert(
        signer.send_transaction(
            account, erc1155.contract_address, 'burnBatch',
            [burner, *uarr2cd(token_ids), *uarr2cd(amounts)]),
        "ERC1155: burn amount exceeds balance"
    )

    # todo nonzero balance


@pytest.mark.asyncio
async def test_burn_batch_invalid_uint(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory
    burner = account.contract_address
    token_ids = TOKEN_IDS
    mint_amounts = MAX_UINT_AMOUNTS
    burn_amounts = INVALID_AMOUNTS

    # mint max possible to avoid insufficient balance
    await signer.send_transaction(
        owner, erc1155.contract_address, 'mintBatch',
        [burner, *uarr2cd(token_ids), *uarr2cd(mint_amounts), 0])

    # attempt passing an invalid uint in batch
    await assert_revert(
        signer.send_transaction(
            account, erc1155.contract_address, 'burnBatch',
            [burner, *uarr2cd(token_ids), *uarr2cd(burn_amounts)]),
        "ERC1155: amount is not a valid Uint256"
    )


@pytest.mark.asyncio
async def test_burn_batch_uneven_arrays(erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    burner = account.contract_address
    amounts = BURN_AMOUNTS
    token_ids = TOKEN_IDS

    # uneven token_ids vs amounts
    await assert_revert(
        signer.send_transaction(
            account, erc1155.contract_address, 'burnBatch',
            [burner, *uarr2cd(token_ids), *uarr2cd(amounts[:2])]),
        "ERC1155: ids and amounts length mismatch"
    )
    await assert_revert(
        signer.send_transaction(
            account, erc1155.contract_address, 'burnBatch',
            [burner, *uarr2cd(token_ids[:2]), *uarr2cd(amounts)]),
        "ERC1155: ids and amounts length mismatch"
    )

#
# Transfer
#


@pytest.mark.asyncio
async def test_safe_transfer_from(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    sender = account2.contract_address
    recipient = account1.contract_address
    token_id = TOKEN_ID
    transfer_amount = TRANSFER_AMOUNT

    await signer.send_transaction(
        account2, erc1155.contract_address, 'safeTransferFrom',
        [sender, recipient, *token_id, *transfer_amount, 0])

    execution_info = await erc1155.balanceOf(sender, token_id).invoke()
    assert execution_info.result.balance == sub_uint(
        MINT_AMOUNTS[0], transfer_amount)
    execution_info = await erc1155.balanceOf(recipient, token_id).invoke()
    assert execution_info.result.balance == transfer_amount


@pytest.mark.asyncio
async def test_safe_transfer_from_emits_event(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    sender = account2.contract_address
    recipient = account1.contract_address
    token_id = TOKEN_ID
    transfer_amount = TRANSFER_AMOUNT

    execution_info = await signer.send_transaction(
        account2, erc1155.contract_address, 'safeTransferFrom',
        [sender, recipient, *token_id, *transfer_amount, 0])

    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='TransferSingle',
        data=[
            sender,  # operator
            sender,  # from
            recipient,  # to
            *token_id,
            *transfer_amount
        ]
    )


@pytest.mark.asyncio
async def test_safe_transfer_from_approved(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    operator = account1.contract_address
    sender = account2.contract_address
    recipient = account1.contract_address
    token_id = TOKEN_ID
    transfer_amount = TRANSFER_AMOUNT
    approval = TRUE

    # account2 approves account
    await signer.send_transaction(
        account2, erc1155.contract_address, 'setApprovalForAll',
        [operator, approval])

    # account sends transaction
    await signer.send_transaction(
        account1, erc1155.contract_address, 'safeTransferFrom',
        [sender, recipient, *token_id, *transfer_amount, 0])

    execution_info = await erc1155.balanceOf(sender, token_id).invoke()
    assert execution_info.result.balance == sub_uint(
        MINT_AMOUNTS[0], transfer_amount)
    execution_info = await erc1155.balanceOf(recipient, token_id).invoke()
    assert execution_info.result.balance == transfer_amount


@pytest.mark.asyncio
async def test_safe_transfer_from_approved_emits_event(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    operator = account1.contract_address
    sender = account2.contract_address
    recipient = account1.contract_address
    token_id = TOKEN_ID
    transfer_amount = TRANSFER_AMOUNT
    approval = TRUE

    # account2 approves account
    await signer.send_transaction(
        account2, erc1155.contract_address, 'setApprovalForAll',
        [operator, approval])

    # account sends transaction
    execution_info = await signer.send_transaction(
        account1, erc1155.contract_address, 'safeTransferFrom',
        [sender, recipient, *token_id, *transfer_amount, 0])

    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='TransferSingle',
        data=[
            operator,  # operator
            sender,  # from
            recipient,  # to
            *token_id,
            *transfer_amount
        ]
    )


@pytest.mark.asyncio
async def test_safe_transfer_from_invalid_uint(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory

    sender = account.contract_address
    recipient = owner.contract_address
    token_id = TOKEN_ID
    invalid_id = INVALID_UINT
    mint_amount = MAX_UINT256
    transfer_amount = uint(0)
    invalid_amount = INVALID_UINT

    # mint max uint to avoid possible insufficient balance error
    await signer.send_transaction(
        owner, erc1155.contract_address, 'mint',
        [sender, *token_id, *mint_amount, 0])

    await assert_revert(
        signer.send_transaction(
            account, erc1155.contract_address, 'safeTransferFrom',
            [sender, recipient, *token_id, *invalid_amount, 0]),
        "ERC1155: amount is not a valid Uint256"
    )
    # transfer 0 amount
    await assert_revert(
        signer.send_transaction(
            account, erc1155.contract_address, 'safeTransferFrom',
            [sender, recipient, *invalid_id, *transfer_amount, 0]),
        "ERC1155: id is not a valid Uint256"
    )


@pytest.mark.asyncio
async def test_safe_transfer_from_insufficient_balance(erc1155_minted_factory):
    erc1155, account, account2, _ = erc1155_minted_factory

    sender = account2.contract_address
    recipient = account.contract_address
    token_id = TOKEN_ID
    transfer_amount = add_uint(MINT_AMOUNTS[0], uint(1))

    await assert_revert(
        signer.send_transaction(
            account2, erc1155.contract_address, 'safeTransferFrom',
            [sender, recipient, *token_id, *transfer_amount, 0]),
        "ERC1155: insufficient balance for transfer"
    )


@pytest.mark.asyncio
async def test_safe_transfer_from_unapproved(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    sender = account2.contract_address
    recipient = account1.contract_address
    token_id = TOKEN_ID
    transfer_amount = TRANSFER_AMOUNT

    # unapproved account sends transaction, should fail
    await assert_revert(signer.send_transaction(
        account1, erc1155.contract_address, 'safeTransferFrom',
        [sender, recipient, *token_id, *transfer_amount, 0]))


@pytest.mark.asyncio
async def test_safe_transfer_from_to_zero_address(erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    sender = account.contract_address
    recipient = ZERO_ADDRESS
    token_id = TOKEN_ID
    transfer_amount = TRANSFER_AMOUNT

    await assert_revert(signer.send_transaction(
        account, erc1155.contract_address, 'safeTransferFrom',
        [sender, recipient, *token_id, *transfer_amount, 0]))


@pytest.mark.asyncio
async def test_safe_transfer_from_overflow(erc1155_minted_factory):
    erc1155, owner, account, _ = erc1155_minted_factory

    sender = account.contract_address
    recipient = owner.contract_address
    token_id = TOKEN_ID
    transfer_amount = TRANSFER_AMOUNT
    max_amount = MAX_UINT256

    # Bring recipient's balance to max possible, should pass (recipient's balance is 0)
    await signer.send_transaction(
        owner, erc1155.contract_address, 'mint',
        [recipient, *token_id, *max_amount, 0])

    # Issuing recipient any more should revert due to overflow
    await assert_revert(signer.send_transaction(
        account, erc1155.contract_address, 'safeTransferFrom',
        [sender, recipient, *token_id, *transfer_amount, 0]
    ))


# Batch Transfer
@pytest.mark.asyncio
async def test_safe_batch_transfer_from(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory
    sender = account2.contract_address
    recipient = account1.contract_address
    token_ids = TOKEN_IDS
    transfer_amounts = TRANSFER_AMOUNTS
    difference = TRANSFER_DIFFERENCE

    await signer.send_transaction(
        account2, erc1155.contract_address, 'safeBatchTransferFrom',
        [sender, recipient, *uarr2cd(token_ids), *uarr2cd(transfer_amounts), 0])

    execution_info = await erc1155.balanceOfBatch([sender]*3+[recipient]*3, token_ids*2).invoke()
    assert execution_info.result.balances[:3] == difference
    assert execution_info.result.balances[3:] == transfer_amounts


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_emits_event(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory
    sender = account2.contract_address
    recipient = account1.contract_address
    token_ids = TOKEN_IDS
    transfer_amounts = TRANSFER_AMOUNTS

    execution_info = await signer.send_transaction(
        account2, erc1155.contract_address, 'safeBatchTransferFrom',
        [sender, recipient, *uarr2cd(token_ids), *uarr2cd(transfer_amounts), 0])

    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='TransferBatch',
        data=[
            sender,  # operator
            sender,  # from
            recipient,  # to
            *uarr2cd(token_ids),
            *uarr2cd(transfer_amounts),
        ]
    )


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_approved(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    sender = account2.contract_address
    operator = account1.contract_address
    recipient = account1.contract_address
    token_ids = TOKEN_IDS
    transfer_amounts = TRANSFER_AMOUNTS
    difference = TRANSFER_DIFFERENCE
    approval = TRUE

    # account approves account2
    await signer.send_transaction(
        account2, erc1155.contract_address, 'setApprovalForAll',
        [operator, approval])

    await signer.send_transaction(
        account1, erc1155.contract_address, 'safeBatchTransferFrom',
        [sender, recipient, *uarr2cd(token_ids), *uarr2cd(transfer_amounts), 0])

    execution_info = await erc1155.balanceOfBatch([sender]*3+[recipient]*3, token_ids*2).invoke()
    assert execution_info.result.balances[:3] == difference
    assert execution_info.result.balances[3:] == transfer_amounts


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_approved_emits_event(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    sender = account2.contract_address
    operator = account1.contract_address
    recipient = account1.contract_address
    token_ids = TOKEN_IDS
    transfer_amounts = TRANSFER_AMOUNTS
    approval = TRUE

    # account approves account2
    await signer.send_transaction(
        account2, erc1155.contract_address, 'setApprovalForAll',
        [operator, approval])

    execution_info = await signer.send_transaction(
        account1, erc1155.contract_address, 'safeBatchTransferFrom',
        [sender, recipient, *uarr2cd(token_ids), *uarr2cd(transfer_amounts), 0])

    assert_event_emitted(
        execution_info,
        from_address=erc1155.contract_address,
        name='TransferBatch',
        data=[
            operator,  # operator
            sender,  # from
            recipient,  # to
            *uarr2cd(token_ids),
            *uarr2cd(transfer_amounts),
        ]
    )


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_invalid_uint(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory

    sender = account.contract_address
    recipient = owner.contract_address
    token_ids = TOKEN_IDS
    invalid_ids = INVALID_IDS
    mint_amounts = MAX_UINT_AMOUNTS
    invalid_amounts = INVALID_AMOUNTS
    transfer_amounts = TRANSFER_AMOUNTS

    # mint amount[i] of token_id[i] to sender
    await signer.send_transaction(
        owner, erc1155.contract_address, 'mintBatch',
        [sender, *uarr2cd(token_ids), *uarr2cd(mint_amounts), 0])

    await assert_revert(signer.send_transaction(
        account, erc1155.contract_address, 'safeBatchTransferFrom',
        [sender, recipient, *uarr2cd(token_ids), *uarr2cd(invalid_amounts), 0]))
    # attempt transfer 0 due to insufficient balance error
    await assert_revert(signer.send_transaction(
        account, erc1155.contract_address, 'safeBatchTransferFrom',
        [sender, recipient, *uarr2cd(invalid_ids), *uarr2cd(transfer_amounts), 0]))


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_insufficient_balance(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory
    sender = account2.contract_address
    recipient = account1.contract_address
    token_ids = TOKEN_IDS
    transfer_amounts = [MINT_AMOUNTS[0], add_uint(
        MINT_AMOUNTS[1], uint(1)), MINT_AMOUNTS[2]]

    await assert_revert(signer.send_transaction(
        account2, erc1155.contract_address, 'safeBatchTransferFrom',
        [sender, recipient, *uarr2cd(token_ids), *uarr2cd(transfer_amounts), 0]))


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_unapproved(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    sender = account2.contract_address
    recipient = account1.contract_address
    token_ids = TOKEN_IDS
    transfer_amounts = TRANSFER_AMOUNTS

    await assert_revert(signer.send_transaction(
        account1, erc1155.contract_address, 'safeBatchTransferFrom',
        [sender, recipient, *uarr2cd(token_ids), *uarr2cd(transfer_amounts), 0]))


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_to_zero_address(erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    sender = account.contract_address
    recipient = ZERO_ADDRESS
    token_ids = TOKEN_IDS
    transfer_amounts = TRANSFER_AMOUNTS

    await assert_revert(signer.send_transaction(
        account,
        erc1155.contract_address,
        'safeBatchTransferFrom', [sender, recipient, *uarr2cd(token_ids), *uarr2cd(transfer_amounts), 0]))


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_uneven_arrays(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    sender = account2.contract_address
    recipient = account1.contract_address
    transfer_amounts = TRANSFER_AMOUNTS
    token_ids = TOKEN_IDS

    # uneven token_ids vs amounts
    await assert_revert(signer.send_transaction(
        account2, erc1155.contract_address, 'safeBatchTransferFrom',
        [sender, recipient, *uarr2cd(token_ids),
         *uarr2cd(transfer_amounts[:2]), 0]
    ))
    await assert_revert(signer.send_transaction(
        account2, erc1155.contract_address, 'safeBatchTransferFrom',
        [sender, recipient, *uarr2cd(token_ids[:2]),
         *uarr2cd(transfer_amounts), 0]
    ))


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_overflow(erc1155_minted_factory):
    erc1155, account1, account2, _ = erc1155_minted_factory

    sender = account2.contract_address
    recipient = account1.contract_address
    token_ids = TOKEN_IDS
    max_amounts = MAX_UINT_AMOUNTS
    transfer_amounts = uint_array([0, 1, 0])

    # Bring 1 recipient's balance to max possible, should pass (recipient's balance is 0)
    await signer.send_transaction(
        account1, erc1155.contract_address, 'mintBatch',
        [recipient, *uarr2cd(token_ids), *uarr2cd(max_amounts), 0]
    )

    # Issuing recipient any more on just 1 token_id should revert due to overflow
    await assert_revert(signer.send_transaction(
        account2, erc1155.contract_address, 'safeBatchTransferFrom',
        [sender, recipient, *uarr2cd(token_ids), *uarr2cd(transfer_amounts), 0]
    ))

#
# Unsafe recipients
#


@pytest.mark.asyncio
async def test_safe_transfer_from_to_uninstantiated_contract(erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    sender = account.contract_address
    recipient = 123
    token_id = TOKEN_ID
    transfer_amount = TRANSFER_AMOUNT

    await assert_revert(signer.send_transaction(
        account, erc1155.contract_address, 'safeTransferFrom',
        [sender, recipient, *token_id, *transfer_amount, 0]))


@pytest.mark.asyncio
async def test_safe_transfer_from_to_unsafe_contract(erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    sender = account.contract_address
    recipient = erc1155.contract_address
    token_id = TOKEN_ID
    transfer_amount = TRANSFER_AMOUNT

    await assert_revert(signer.send_transaction(
        account, erc1155.contract_address, 'safeTransferFrom',
        [sender, recipient, *token_id, *transfer_amount, 0]),
        "ERC1155: transfer to non ERC1155Receiver implementer")


@pytest.mark.asyncio
async def test_safe_transfer_from_receiver(erc1155_minted_factory):
    erc1155, _, account, receiver = erc1155_minted_factory
    # mock ERC1155_receiver accepts iff data = []

    sender = account.contract_address
    recipient = receiver.contract_address
    token_id = TOKEN_ID
    transfer_amount = TRANSFER_AMOUNT
    data_cd = [0]
    await signer.send_transaction(
        account, erc1155.contract_address, 'safeTransferFrom',
        [sender, recipient, *token_id, *transfer_amount, *data_cd])


@pytest.mark.asyncio
async def test_safe_transfer_from_receiver_rejection(erc1155_minted_factory):
    erc1155, _, account, receiver = erc1155_minted_factory
    # mock ERC1155_receiver accepts iff data = []

    sender = account.contract_address
    recipient = receiver.contract_address
    token_id = TOKEN_ID
    transfer_amount = TRANSFER_AMOUNT
    data_cd = [1, 0]
    # data = [0], mock receiver should reject
    await assert_revert(signer.send_transaction(
        account, erc1155.contract_address, 'safeTransferFrom',
        [sender, recipient, *token_id, *transfer_amount, *data_cd]),
        "ERC1155: ERC1155Receiver rejected tokens"
    )


@pytest.mark.asyncio
async def test_mint_to_unsafe_contract(erc1155_factory):
    erc1155, owner, account, _ = erc1155_factory

    recipient = erc1155.contract_address
    token_id = TOKEN_ID
    amount = MINT_AMOUNT

    # minting to 0 address should fail
    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mint',
            [
                recipient,  # to
                *token_id,
                *amount,
                0  # data
            ]
        ),
        "ERC1155: transfer to non ERC1155Receiver implementer"
    )


@pytest.mark.asyncio
async def test_mint_receiver_rejection(erc1155_factory):
    erc1155, owner, _, receiver = erc1155_factory

    recipient = receiver.contract_address
    token_id = TOKEN_ID
    amount = MINT_AMOUNT

    # minting to 0 address should fail
    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mint',
            [
                recipient,  # to
                *token_id,
                *amount,
                1, 0  # data
            ]
        ),
        "ERC1155: ERC1155Receiver rejected tokens"
    )


@pytest.mark.asyncio
async def test_mint_receiver(erc1155_factory):
    erc1155, owner, _, receiver = erc1155_factory
    recipient = receiver.contract_address
    token_id = TOKEN_ID
    amount = MINT_AMOUNT

    # minting to 0 address should fail
    await signer.send_transaction(
        owner, erc1155.contract_address, 'mint',
        [
            recipient,  # to
            *token_id,
            *amount,
            0  # data
        ]
    )


@pytest.mark.asyncio
async def test_mint_batch_to_unsafe_contract(erc1155_factory):
    erc1155, owner, _, _ = erc1155_factory

    recipient = erc1155.contract_address
    token_ids = TOKEN_IDS
    amounts = MINT_AMOUNTS

    # mint amount[i] of token_id[i] to recipient
    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mintBatch',
            [recipient, *uarr2cd(token_ids), *uarr2cd(amounts), 0]),
        "ERC1155: transfer to non ERC1155Receiver implementer"
    )


@pytest.mark.asyncio
async def test_mint_batch_receiver(erc1155_factory):
    erc1155, owner, _, _ = erc1155_factory

    recipient = erc1155.contract_address
    token_ids = TOKEN_IDS
    amounts = MINT_AMOUNTS

    # mint amount[i] of token_id[i] to recipient
    await assert_revert(
        signer.send_transaction(
            owner, erc1155.contract_address, 'mintBatch',
            [recipient, *uarr2cd(token_ids), *uarr2cd(amounts), 0]),
        "ERC1155: transfer to non ERC1155Receiver implementer"
    )


@pytest.mark.asyncio
async def test_safe_batch_transfer_from_to_unsafe_contract(erc1155_minted_factory):
    erc1155, _, account, _ = erc1155_minted_factory

    sender = account.contract_address
    recipient = erc1155.contract_address
    token_ids = TOKEN_IDS
    transfer_amounts = TRANSFER_AMOUNTS

    await assert_revert(signer.send_transaction(
        account, erc1155.contract_address, 'safeBatchTransferFrom',
        [sender, recipient, *uarr2cd(token_ids), *uarr2cd(transfer_amounts), 0]),
        "ERC1155: transfer to non ERC1155Receiver implementer")
