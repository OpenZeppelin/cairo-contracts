import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils.Signer import Signer

signer = Signer(123456789987654321)
signer2 = Signer(234567899876543211)
signer3 = Signer(345678998765432112)

MAX_AMOUNT = (2**128 - 1, 2**128 - 1)
ZERO_ADDRESS = 0

user1 = 123
user2 = 234
user3 = 345
user4 = 456
user5 = 567

first_token_id = (5042, 0)
second_token_id = (7921, 1)
third_token_id = (0, 13)
fourth_token_id = MAX_AMOUNT
nonexistent_token = (111, 222)
token_to_burn = (12345, 6789)


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


#
# Mint
#


@pytest.mark.asyncio
async def test_mint(erc721_factory):
    _, erc721, account = erc721_factory

    # mint three tokens to account
    await signer.send_transaction(
        account, erc721.contract_address, 'mint', [
            account.contract_address, *first_token_id]
    )
    await signer.send_transaction(
        account, erc721.contract_address, 'mint', [
            account.contract_address, *second_token_id]
    )
    await signer.send_transaction(
        account, erc721.contract_address, 'mint', [
            account.contract_address, *third_token_id]
    )

    # checks balance
    execution_info = await erc721.balance_of(account.contract_address).call()
    assert execution_info.result == (uint(3),)

    # checks that account owns correct tokens
    execution_info = await erc721.owner_of(first_token_id).call()
    assert execution_info.result == (account.contract_address,)

    execution_info = await erc721.owner_of(second_token_id).call()
    assert execution_info.result == (account.contract_address,)

    execution_info = await erc721.owner_of(third_token_id).call()
    assert execution_info.result == (account.contract_address,)


@pytest.mark.asyncio
async def test_mint_duplicate_token_id(erc721_factory):
    _, erc721, account = erc721_factory

    try:
        # minting duplicate token_id should fail
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                account.contract_address, *first_token_id]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_mint_to_zero_address(erc721_factory):
    _, erc721, account = erc721_factory
    zero_address = 0

    try:
        # minting to zero address should fail
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                zero_address, *nonexistent_token]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


#
# Burn
#

@pytest.mark.asyncio
async def test_burn(erc721_factory):
    _, erc721, account = erc721_factory

    # mint 'token_to_burn' to account
    await signer.send_transaction(
        account, erc721.contract_address, 'mint', [
            account.contract_address, *token_to_burn]
    )

    execution_info = await erc721.balance_of(account.contract_address).call()
    previous_balance = execution_info.result.res

    # burn token
    await signer.send_transaction(
        account, erc721.contract_address, 'burn', [*token_to_burn]
    )

    # account balance should subtract one
    execution_info = await erc721.balance_of(account.contract_address).call()
    assert (previous_balance[0] - 1, previous_balance[1]
            ) == execution_info.result.res

    # approve should be cleared to zero, therefore,
    # 'get_approved()' call should fail
    try:
        await erc721.get_approved(token_to_burn).call()
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

    # 'token_to_burn' owner should be zero; therefore,
    # 'owner_of()' call should fail
    try:
        await erc721.owner_of(token_to_burn).call()
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_burn_nonexistent_token(erc721_factory):
    _, erc721, account = erc721_factory

    # 'token_to_burn' is already burned; therefore,
    # should fail
    try:
        await signer.send_transaction(
            account, erc721.contract_address, 'burn', [*token_to_burn]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


#
# Approve
#


@pytest.mark.asyncio
async def test_approve(erc721_factory):
    _, erc721, account = erc721_factory

    await signer.send_transaction(
        account, erc721.contract_address, 'approve', [user1, *first_token_id]
    )

    execution_info = await erc721.get_approved(first_token_id).call()
    assert execution_info.result == (user1,)


@pytest.mark.asyncio
async def test_approve_on_set_approval_for_all(erc721_factory):
    starknet, erc721, account = erc721_factory
    spender = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

    # set approval_for_all from account to spender
    await signer.send_transaction(
        account, erc721.contract_address, 'set_approval_for_all', [
            spender.contract_address, 1]
    )

    # approve spender to spend account's 'first_token_id' to user1
    await signer.send_transaction(
        spender, erc721.contract_address, 'approve', [
            user1, *first_token_id]
    )

    execution_info = await erc721.get_approved(first_token_id).call()
    assert execution_info.result == (user1,)


@pytest.mark.asyncio
async def test_approve_from_zero_address(erc721_factory):
    _, erc721, _ = erc721_factory

    # Without using an account abstraction, the caller address
    # (get_caller_address) is zero
    try:
        await erc721.approve(user1, third_token_id).invoke()
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_approve_owner_equals_recipient(erc721_factory):
    _, erc721, account = erc721_factory

    try:
        # should fail when owner is the same as address-to-be-approved
        await signer.send_transaction(
            account, erc721.contract_address, 'approve', [
                account.contract_address, *third_token_id]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_approve_not_owner_or_operator(erc721_factory):
    _, erc721, account = erc721_factory

    try:
        # should fail since user1 now owns 'first_token_id'
        await signer.send_transaction(
            account, erc721.contract_address, 'approve', [
                account.contract_address, *first_token_id]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


#
# Set_approval_for_all
#


@pytest.mark.asyncio
async def test_set_approval_for_all(erc721_factory):
    _, erc721, account = erc721_factory

    true = 1
    await signer.send_transaction(
        account, erc721.contract_address, 'set_approval_for_all', [user2, true]
    )

    execution_info = await erc721.is_approved_for_all(account.contract_address, user2).call()
    assert execution_info.result == (true,)


@pytest.mark.asyncio
async def test_set_approval_for_all_with_invalid_bool_arg(erc721_factory):
    _, erc721, account = erc721_factory
    not_bool = 2

    try:
        await signer.send_transaction(
            account, erc721.contract_address, 'set_approval_for_all', [
                user2, not_bool]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_set_approval_for_all_owner_is_operator(erc721_factory):
    _, erc721, account = erc721_factory

    try:
        await signer.send_transaction(
            account, erc721.contract_address, 'set_approval_for_all', [
                account.contract_address, 1]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


#
# Transfer_from
#


@pytest.mark.asyncio
async def test_transfer_from_owner(erc721_factory):
    _, erc721, account = erc721_factory

    # get account's previous balance
    execution_info = await erc721.balance_of(account.contract_address).call()
    previous_balance = execution_info.result.res

    # transfers token from owner to recipient
    await signer.send_transaction(
        account, erc721.contract_address, 'transfer_from', [
            account.contract_address, user1, *first_token_id]
    )

    # checks user balance
    execution_info = await erc721.balance_of(user1).call()
    assert execution_info.result == (uint(1),)

    # checks account balance
    execution_info = await erc721.balance_of(account.contract_address).call()
    assert execution_info.result == (
        (previous_balance[0] - 1, previous_balance[1]),)

    # checks token has new owner
    execution_info = await erc721.owner_of(first_token_id).call()
    assert execution_info.result == (user1,)

    # checks approval is cleared for token_id
    execution_info = await erc721.get_approved(first_token_id).call()
    assert execution_info.result == (0,)


@pytest.mark.asyncio
async def test_transfer_from_approved_user(erc721_factory):
    starknet, erc721, account = erc721_factory
    spender = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )
    recipient = user2

    # approve spender
    await signer.send_transaction(
        account, erc721.contract_address, 'approve', [
            spender.contract_address, *second_token_id]
    )

    # spender transfers token from account to recipient
    await signer.send_transaction(
        spender, erc721.contract_address, 'transfer_from', [
            account.contract_address, recipient, *second_token_id]
    )

    # checks user balance
    execution_info = await erc721.balance_of(recipient).call()
    assert execution_info.result == (uint(1),)


@pytest.mark.asyncio
async def test_transfer_from_operator(erc721_factory):
    starknet, erc721, account = erc721_factory
    spender = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )
    recipient = user3

    # set_approval_for_all
    await signer.send_transaction(
        account, erc721.contract_address, 'set_approval_for_all', [
            spender.contract_address, 1]
    )

    # spender transfers token from account to recipient
    await signer.send_transaction(
        spender, erc721.contract_address, 'transfer_from', [
            account.contract_address, recipient, *third_token_id]
    )

    # checks user balance
    execution_info = await erc721.balance_of(recipient).call()
    assert execution_info.result == (uint(1),)


@pytest.mark.asyncio
async def test_transfer_from_when_not_approved_or_owner(erc721_factory):
    starknet, erc721, account = erc721_factory
    spender = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )
    recipient = user3

    # set_approval_for_all to false ('0')
    await signer.send_transaction(
        account, erc721.contract_address, 'set_approval_for_all', [
            spender.contract_address, 0]
    )

    try:
        # should be rejected
        await signer.send_transaction(
            spender, erc721.contract_address, 'transfer_from', [
                account.contract_address, recipient, *fourth_token_id]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_transfer_from_to_zero_address(erc721_factory):
    starknet, erc721, account = erc721_factory
    spender = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

    # set_approval_for_all
    await signer.send_transaction(
        account, erc721.contract_address, 'set_approval_for_all', [
            spender.contract_address, 1]
    )

    try:
        # to zero address should be rejected
        await signer.send_transaction(
            spender, erc721.contract_address, 'transfer_from', [
                account.contract_address, ZERO_ADDRESS, *fourth_token_id]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED
