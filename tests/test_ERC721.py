import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils.Signer import Signer


def str_to_felt(text):
    b_text = bytes(text, 'UTF-8')
    return int.from_bytes(b_text, "big")


def uint(a):
    return(a, 0)


signer = Signer(123456789987654321)

MAX_AMOUNT = (2**128 - 1, 2**128 - 1)
ZERO_ADDRESS = 0
BASE_URI = str_to_felt('https://api.example.com/v1/')

# bools (for readability)
false = 0
true = 1
not_bool = 2

user1 = 123
user2 = 234
user3 = 345
user4 = 456
user5 = 567

first_token_id = (5042, 0)
second_token_id = (7921, 1)
third_token_id = (0, 13)
fourth_token_id = MAX_AMOUNT
fifth_token_id = (234, 345)
sixth_token_id = (9999, 9999)
eighth_token_id = (445, 101)
seventh_token_id = (987, 654)
other_owned_token = (123, 321)
nonexistent_token = (111, 222)
token_to_burn = (12345, 6789)


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
            str_to_felt("Non Fungible Token"),  # name
            str_to_felt("NFT"),                 # ticker
            BASE_URI,                           # base_uri
            account.contract_address,           # contract_owner
        ]
    )

    erc721_holder = await starknet.deploy("contracts/token/utils/ERC721Holder.cairo")
    return starknet, erc721, account, erc721_holder


@pytest.mark.asyncio
async def test_constructor(erc721_factory):
    _, erc721, _, _ = erc721_factory
    execution_info = await erc721.name().call()
    assert execution_info.result == (str_to_felt("Non Fungible Token"),)

    execution_info = await erc721.symbol().call()
    assert execution_info.result == (str_to_felt("NFT"),)


#
# Mint
#


@pytest.mark.asyncio
@pytest.mark.parametrize('tokens, number_of_tokens', [
    [first_token_id, 1],
    [second_token_id, 2],
    [third_token_id, 3],
    [fourth_token_id, 4],
    [fifth_token_id, 5],
    [sixth_token_id, 6]
])
async def test_mint(erc721_factory, tokens, number_of_tokens):
    _, erc721, account, _ = erc721_factory

    # mint tokens to account
    await signer.send_transaction(
        account, erc721.contract_address, 'mint', [
            account.contract_address, *tokens]
    )

    # checks balance
    execution_info = await erc721.balanceOf(account.contract_address).call()
    assert execution_info.result == (uint(number_of_tokens),)

    # checks that account owns correct tokens
    execution_info = await erc721.ownerOf(tokens).call()
    assert execution_info.result == (account.contract_address,)


@pytest.mark.asyncio
async def test_mint_duplicate_token_id(erc721_factory):
    _, erc721, account, _ = erc721_factory

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
    _, erc721, account, _ = erc721_factory

    try:
        # minting to zero address should fail
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                ZERO_ADDRESS, *nonexistent_token]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_mint_approve_should_be_zero_address(erc721_factory):
    _, erc721, account, _ = erc721_factory

    await signer.send_transaction(
        account, erc721.contract_address, 'mint', [
            account.contract_address, *seventh_token_id]
    )

    # approved address should be zero for newly minted tokens
    execution_info = await erc721.getApproved(seventh_token_id).call()
    assert execution_info.result == (0,)


@pytest.mark.asyncio
async def test_mint_by_not_owner(erc721_factory):
    starknet, erc721, _, _ = erc721_factory
    not_owner = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

    try:
        # minting from not_owner should fail
        await signer.send_transaction(
            not_owner, erc721.contract_address, 'mint', [
                not_owner.contract_address, *eighth_token_id]
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
    _, erc721, account, _ = erc721_factory

    # mint 'token_to_burn' to account
    await signer.send_transaction(
        account, erc721.contract_address, 'mint', [
            account.contract_address, *token_to_burn]
    )

    execution_info = await erc721.balanceOf(account.contract_address).call()
    previous_balance = execution_info.result.balance

    # burn token
    await signer.send_transaction(
        account, erc721.contract_address, 'burn', [*token_to_burn]
    )

    # account balance should subtract one
    execution_info = await erc721.balanceOf(account.contract_address).call()
    assert (previous_balance[0] - 1, previous_balance[1]
            ) == execution_info.result.balance

    # approve should be cleared to zero, therefore,
    # 'getApproved()' call should fail
    try:
        await erc721.getApproved(token_to_burn).call()
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

    # 'token_to_burn' owner should be zero; therefore,
    # 'ownerOf()' call should fail
    try:
        await erc721.ownerOf(token_to_burn).call()
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_burn_nonexistent_token(erc721_factory):
    _, erc721, account, _ = erc721_factory

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


@pytest.mark.asyncio
async def test_burn_contract_owner_token_by_different_account(erc721_factory):
    starknet, erc721, _, _ = erc721_factory
    not_owner = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

    try:
        # not_owner should not be able to burn tokens
        await signer.send_transaction(
            not_owner, erc721.contract_address, 'burn', [*first_token_id]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_burn_token_not_owned_by_contract_owner(erc721_factory):
    starknet, erc721, account, _ = erc721_factory
    not_owner = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

    # mint token to non_contract_owner
    await signer.send_transaction(
        account, erc721.contract_address, 'mint', [
            not_owner.contract_address, *token_to_burn]
    )

    try:
        # should fail because contract owner does not own token
        await signer.send_transaction(
            account, erc721.contract_address, 'burn', [*token_to_burn]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

    # send token to owner
    await signer.send_transaction(
        not_owner, erc721.contract_address, 'transferFrom', [
            not_owner.contract_address, account.contract_address, *token_to_burn]
    )

    # burn token
    await signer.send_transaction(
        account, erc721.contract_address, 'burn', [*token_to_burn]
    )


#
# Approve
#


@pytest.mark.asyncio
async def test_approve(erc721_factory):
    _, erc721, account, _ = erc721_factory

    await signer.send_transaction(
        account, erc721.contract_address, 'approve', [user1, *first_token_id]
    )

    execution_info = await erc721.getApproved(first_token_id).call()
    assert execution_info.result == (user1,)


@pytest.mark.asyncio
async def test_approve_on_setApprovalForAll(erc721_factory):
    starknet, erc721, account, _ = erc721_factory
    spender = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

    # set approval_for_all from account to spender
    await signer.send_transaction(
        account, erc721.contract_address, 'setApprovalForAll', [
            spender.contract_address, true]
    )

    # approve spender to spend account's 'first_token_id' to user1
    await signer.send_transaction(
        spender, erc721.contract_address, 'approve', [
            user1, *first_token_id]
    )

    execution_info = await erc721.getApproved(first_token_id).call()
    assert execution_info.result == (user1,)


@pytest.mark.asyncio
async def test_approve_from_zero_address(erc721_factory):
    _, erc721, _, _ = erc721_factory

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
    _, erc721, account, _ = erc721_factory

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
    starknet, erc721, account, _ = erc721_factory
    spender = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

    # mint to user5 — NOT account
    await signer.send_transaction(
        account, erc721.contract_address, 'mint', [
            user5, *other_owned_token]
    )

    try:
        # should fail since user5 owns 'other_owned_token'
        await signer.send_transaction(
            account, erc721.contract_address, 'approve', [
                spender.contract_address, *other_owned_token]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


#
# setApprovalForAll
#


@pytest.mark.asyncio
async def test_setApprovalForAll(erc721_factory):
    _, erc721, account, _ = erc721_factory

    await signer.send_transaction(
        account, erc721.contract_address, 'setApprovalForAll', [user2, true]
    )

    execution_info = await erc721.isApprovedForAll(account.contract_address, user2).call()
    assert execution_info.result == (true,)


@pytest.mark.asyncio
async def test_setApprovalForAll_when_operator_was_set_as_not_approved(erc721_factory):
    _, erc721, account, _ = erc721_factory

    await signer.send_transaction(
        account, erc721.contract_address, 'setApprovalForAll', [user2, false]
    )

    await signer.send_transaction(
        account, erc721.contract_address, 'setApprovalForAll', [user2, true]
    )

    execution_info = await erc721.isApprovedForAll(account.contract_address, user2).call()
    assert execution_info.result == (true,)


@pytest.mark.asyncio
async def test_setApprovalForAll_with_invalid_bool_arg(erc721_factory):
    _, erc721, account, _ = erc721_factory

    try:
        await signer.send_transaction(
            account, erc721.contract_address, 'setApprovalForAll', [
                user2, not_bool]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_setApprovalForAll_owner_is_operator(erc721_factory):
    _, erc721, account, _ = erc721_factory

    try:
        await signer.send_transaction(
            account, erc721.contract_address, 'setApprovalForAll', [
                account.contract_address, true]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


#
# transferFrom
#


@pytest.mark.asyncio
async def test_transferFrom_owner(erc721_factory):
    _, erc721, account, _ = erc721_factory

    # get account's previous balance
    execution_info = await erc721.balanceOf(account.contract_address).call()
    previous_balance = execution_info.result.balance

    # transfers token from owner to recipient
    await signer.send_transaction(
        account, erc721.contract_address, 'transferFrom', [
            account.contract_address, user1, *first_token_id]
    )

    # checks user balance
    execution_info = await erc721.balanceOf(user1).call()
    assert execution_info.result == (uint(1),)

    # checks account balance
    execution_info = await erc721.balanceOf(account.contract_address).call()
    assert execution_info.result == (
        (previous_balance[0] - 1, previous_balance[1]),)

    # checks token has new owner
    execution_info = await erc721.ownerOf(first_token_id).call()
    assert execution_info.result == (user1,)

    # checks approval is cleared for token_id
    execution_info = await erc721.getApproved(first_token_id).call()
    assert execution_info.result == (0,)


@pytest.mark.asyncio
async def test_transferFrom_approved_user(erc721_factory):
    starknet, erc721, account, _ = erc721_factory
    spender = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

    # approve spender
    await signer.send_transaction(
        account, erc721.contract_address, 'approve', [
            spender.contract_address, *second_token_id]
    )

    # spender transfers token from account to recipient
    await signer.send_transaction(
        spender, erc721.contract_address, 'transferFrom', [
            account.contract_address, user2, *second_token_id]
    )

    # checks user balance
    execution_info = await erc721.balanceOf(user2).call()
    assert execution_info.result == (uint(1),)


@pytest.mark.asyncio
async def test_transferFrom_operator(erc721_factory):
    starknet, erc721, account, _ = erc721_factory
    spender = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )
    recipient = user3

    # setApprovalForAll
    await signer.send_transaction(
        account, erc721.contract_address, 'setApprovalForAll', [
            spender.contract_address, true]
    )

    # spender transfers token from account to recipient
    await signer.send_transaction(
        spender, erc721.contract_address, 'transferFrom', [
            account.contract_address, recipient, *third_token_id]
    )

    # checks user balance
    execution_info = await erc721.balanceOf(recipient).call()
    assert execution_info.result == (uint(1),)


@pytest.mark.asyncio
async def test_transferFrom_when_not_approved_or_owner(erc721_factory):
    starknet, erc721, account, _ = erc721_factory
    spender = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )
    recipient = user3

    # setApprovalForAll to false
    await signer.send_transaction(
        account, erc721.contract_address, 'setApprovalForAll', [
            spender.contract_address, false]
    )

    try:
        # should be rejected when not approved
        await signer.send_transaction(
            spender, erc721.contract_address, 'transferFrom', [
                account.contract_address, recipient, *nonexistent_token]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_transferFrom_to_zero_address(erc721_factory):
    starknet, erc721, account, _ = erc721_factory
    spender = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

    # setApprovalForAll
    await signer.send_transaction(
        account, erc721.contract_address, 'setApprovalForAll', [
            spender.contract_address, true]
    )

    try:
        # to zero address should be rejected
        await signer.send_transaction(
            spender, erc721.contract_address, 'transferFrom', [
                account.contract_address, ZERO_ADDRESS, *fourth_token_id]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


#
# supportsInterface
#


@pytest.mark.asyncio
async def test_supportsInterface(erc721_factory):
    _, erc721, _, _ = erc721_factory
    supported_interface = str_to_felt('0x01ffc9a7')
    unsupported_interface = str_to_felt('0xffffffff')

    execution_info = await erc721.supportsInterface(supported_interface).call()
    assert execution_info.result == (1,)

    execution_info = await erc721.supportsInterface(unsupported_interface).call()
    assert execution_info.result == (0,)


#
# safeTransfer
#

@pytest.mark.asyncio
async def test_safeTransferFrom(erc721_factory):
    _, erc721, account, erc721_holder = erc721_factory

    await signer.send_transaction(
        account, erc721.contract_address, 'safeTransferFrom', [
            account.contract_address, erc721_holder.contract_address, *fourth_token_id, 0]
    )

    execution_info = await erc721.balanceOf(erc721_holder.contract_address).call()
    assert execution_info.result == (uint(1),)

    execution_info = await erc721.ownerOf(fourth_token_id).call()
    assert execution_info.result == (erc721_holder.contract_address,)


@pytest.mark.asyncio
async def test_safeTransferFrom_from_approved(erc721_factory):
    starknet, erc721, account, erc721_holder = erc721_factory
    spender = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

    execution_info = await erc721.balanceOf(erc721_holder.contract_address).call()
    previous_balance = execution_info.result.balance

    # approve spender
    await signer.send_transaction(
        account, erc721.contract_address, 'approve', [
            spender.contract_address, *fifth_token_id]
    )

    # spender transfers token from account to erc721_holder
    await signer.send_transaction(
        spender, erc721.contract_address, 'safeTransferFrom', [
            account.contract_address, erc721_holder.contract_address, *fifth_token_id, 0]
    )

    # erc721_holder balance check
    execution_info = await erc721.balanceOf(erc721_holder.contract_address).call()
    assert execution_info.result == (
        (previous_balance[0] + 1, previous_balance[1]),)


@pytest.mark.asyncio
async def test_safeTransferFrom_from_operator(erc721_factory):
    starknet, erc721, account, erc721_holder = erc721_factory
    spender = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

    execution_info = await erc721.balanceOf(erc721_holder.contract_address).call()
    previous_balance = execution_info.result.balance

    # setApprovalForAll
    await signer.send_transaction(
        account, erc721.contract_address, 'setApprovalForAll', [
            spender.contract_address, true]
    )

    # spender transfers token from account to erc721_holder
    await signer.send_transaction(
        spender, erc721.contract_address, 'safeTransferFrom', [
            account.contract_address, erc721_holder.contract_address, *seventh_token_id, 0]
    )

    # erc721_holder balance check
    execution_info = await erc721.balanceOf(erc721_holder.contract_address).call()
    assert execution_info.result == (
        (previous_balance[0] + 1, previous_balance[1]),)


@pytest.mark.asyncio
async def test_safeTransferFrom_when_not_approved_or_owner(erc721_factory):
    starknet, erc721, account, erc721_holder = erc721_factory
    spender = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

    try:
        # spender was not approved to transfer seventh_token_id from account
        await signer.send_transaction(
            spender, erc721.contract_address, 'safeTransferFrom', [
                account.contract_address, erc721_holder.contract_address, *seventh_token_id, 0]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_safeTransferFrom_to_zero_address(erc721_factory):
    _, erc721, account, _ = erc721_factory

    # mint new token
    await signer.send_transaction(
        account, erc721.contract_address, 'mint', [
            account.contract_address, *eighth_token_id]
    )

    try:
        # to zero address should be rejected
        await signer.send_transaction(
            account, erc721.contract_address, 'safeTransferFrom', [
                account.contract_address, ZERO_ADDRESS, *eighth_token_id, 0]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_safeTransferFrom_to_unsupported_contract(erc721_factory):
    starknet, erc721, account, _ = erc721_factory
    unsupported_account = await starknet.deploy(
        "contracts/token/ERC20.cairo",
        constructor_calldata=[
            str_to_felt("Token"),
            str_to_felt("TKN"),
            account.contract_address
        ]
    )

    try:
        # unsupported_account uses erc20 contract in order to not cause
        # issues once differentiating EOA from contracts is resolved
        await signer.send_transaction(
            account, erc721.contract_address, 'safeTransferFrom', [
                account.contract_address, unsupported_account.contract_address, *eighth_token_id, 0]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.ENTRY_POINT_NOT_FOUND_IN_CONTRACT

    # unsafe method should pass
    await signer.send_transaction(
        account, erc721.contract_address, 'transferFrom', [
            account.contract_address, unsupported_account.contract_address, *eighth_token_id]
    )

    # balance reflects unsafe transfer
    execution_info = await erc721.balanceOf(unsupported_account.contract_address).call()
    assert execution_info.result == (uint(1),)


#
# tokenURI
#


@pytest.mark.asyncio
async def test_tokenURI(erc721_factory):
    _, erc721, _, _ = erc721_factory

    # tokenURI
    execution_info = await erc721.tokenURI(first_token_id).call()
    assert execution_info.result.uri[0] == BASE_URI
    assert execution_info.result.uri[1] == first_token_id[0]
    assert execution_info.result.uri[2] == first_token_id[1]


@pytest.mark.asyncio
async def test_tokenURI_with_nonexistent_token(erc721_factory):
    _, erc721, _, _ = erc721_factory

    try:
        # nonexistent token should make this call fail
        await erc721.tokenURI(nonexistent_token).call()
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_tokenURI_with_no_base_uri(erc721_factory):
    starknet, _, account, _ = erc721_factory

    # creating a new contract instance to set the base_uri
    # to zero
    new_erc721 = await starknet.deploy(
        "contracts/token/ERC721.cairo",
        constructor_calldata=[
            str_to_felt("Non Fungible Token"),  # name
            str_to_felt("NFT"),                 # ticker
            0,                                  # base_uri
            account.contract_address            # contract_owner
        ]
    )

    # mint
    await signer.send_transaction(
        account, new_erc721.contract_address, 'mint', [
            account.contract_address, *first_token_id]
    )

    # tokenURI
    execution_info = await new_erc721.tokenURI(first_token_id).call()
    assert execution_info.result.uri[0] == first_token_id[0]
    assert execution_info.result.uri[1] == first_token_id[1]
