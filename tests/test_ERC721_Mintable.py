import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils import Signer, uint, str_to_felt, MAX_UINT256, assert_revert
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode


signer = Signer(123456789987654321)

ZERO_ADDRESS = 0

# bools (for readability)
false = 0
true = 1
not_bool = 2

# random user addresses
user1 = 123
user2 = 234
user3 = 345
user4 = 456
user5 = 567

# random uint256 tokenIDs
first_token_id = (5042, 0)
second_token_id = (7921, 1)
third_token_id = (0, 13)
fourth_token_id = MAX_UINT256
fifth_token_id = (234, 345)
sixth_token_id = (9999, 9999)
seventh_token_id = (987, 654)
eighth_token_id = (445, 101)
other_owned_token = (123, 321)
nonexistent_token = (111, 222)
token_to_burn = (12345, 6789)

# random data (mimicking bytes in Solidity)
data = [str_to_felt('0x42'), str_to_felt('0x89'), str_to_felt('0x55')]


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
        "contracts/token/ERC721_Mintable.cairo",
        constructor_calldata=[
            str_to_felt("Non Fungible Token"),  # name
            str_to_felt("NFT"),                 # ticker
            account.contract_address            # owner
        ]
    )

    erc721_holder = await starknet.deploy("contracts/token/utils/ERC721_Holder.cairo")
    return starknet, erc721, account, erc721_holder


@pytest.mark.asyncio
async def test_constructor(erc721_factory):
    _, erc721, _, _ = erc721_factory
    execution_info = await erc721.name().call()
    assert execution_info.result == (str_to_felt("Non Fungible Token"),)

    execution_info = await erc721.symbol().call()
    assert execution_info.result == (str_to_felt("NFT"),)

#
# balanceOf
#


@pytest.mark.asyncio
async def test_balanceOf(erc721_factory):
    _, erc721, account, _ = erc721_factory

    # mint tokens to account
    tokens = [first_token_id, second_token_id]
    for token in tokens:
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                account.contract_address, *token]
        )

    # account should have two tokens
    execution_info = await erc721.balanceOf(account.contract_address).call()
    assert execution_info.result == (uint(2),)

    # user1 should have zero tokens
    execution_info = await erc721.balanceOf(user1).call()
    assert execution_info.result == (uint(0),)


@pytest.mark.asyncio
async def test_balanceOf_zero_address(erc721_factory):
    _, erc721, _, _ = erc721_factory

    # should revert when querying zero address
    await assert_revert(erc721.balanceOf(ZERO_ADDRESS).call())


#
# ownerOf
#

@pytest.mark.asyncio
async def test_ownerOf(erc721_factory):
    _, erc721, account, _ = erc721_factory

    # should return account's address
    execution_info = await erc721.ownerOf(first_token_id).call()
    assert execution_info.result == (account.contract_address,)


@pytest.mark.asyncio
async def test_ownerOf_nonexistent_token(erc721_factory):
    _, erc721, _, _ = erc721_factory

    # should revert when querying zero address
    await assert_revert(erc721.ownerOf(nonexistent_token).call())


#
# Mint
#


@pytest.mark.asyncio
@pytest.mark.parametrize('tokens, number_of_tokens', [
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

    # minting duplicate token_id should fail
    await assert_revert(signer.send_transaction(
        account, erc721.contract_address, 'mint', [
            account.contract_address, *first_token_id
        ]
    ))


@ pytest.mark.asyncio
async def test_mint_to_zero_address(erc721_factory):
    _, erc721, account, _ = erc721_factory

    # minting to zero address should fail
    await assert_revert(signer.send_transaction(
        account, erc721.contract_address, 'mint', [
            ZERO_ADDRESS,
            *nonexistent_token
        ]
    ))


@ pytest.mark.asyncio
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

    # minting from not_owner should fail
    await assert_revert(signer.send_transaction(
        not_owner, erc721.contract_address, 'mint', [
            not_owner.contract_address,
            *eighth_token_id
        ]
    ))


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
    await assert_revert(erc721.getApproved(token_to_burn).call())

    # 'token_to_burn' owner should be zero; therefore,
    # 'ownerOf()' call should fail
    await assert_revert(erc721.ownerOf(token_to_burn).call())


@pytest.mark.asyncio
async def test_burn_nonexistent_token(erc721_factory):
    _, erc721, account, _ = erc721_factory

    await assert_revert(signer.send_transaction(
        account, erc721.contract_address, 'burn', [
            *nonexistent_token
        ]
    ))


@pytest.mark.asyncio
async def test_burn_contract_owner_token_by_different_account(erc721_factory):
    starknet, erc721, _, _ = erc721_factory
    not_owner = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

    # not_owner should not be able to burn tokens
    await assert_revert(signer.send_transaction(
        not_owner, erc721.contract_address, 'burn', [
            *first_token_id
        ]
    ))

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
    await assert_revert(erc721.approve(user1, third_token_id).invoke())


@pytest.mark.asyncio
async def test_approve_owner_is_recipient(erc721_factory):
    _, erc721, account, _ = erc721_factory

    # should fail when owner is the same as address-to-be-approved
    await assert_revert(signer.send_transaction(
        account, erc721.contract_address, 'approve', [
            account.contract_address,
            *third_token_id
        ]
    ))


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

    # 'approve' should fail since user5 owns 'other_owned_token'
    await assert_revert(signer.send_transaction(
        account, erc721.contract_address, 'approve', [
            spender.contract_address,
            *other_owned_token
        ]
    ))


@pytest.mark.asyncio
async def test_approve_on_already_approved(erc721_factory):
    _, erc721, account, _ = erc721_factory

    # first approval
    await signer.send_transaction(
        account, erc721.contract_address, 'approve', [
            user1, *first_token_id]
    )

    # repeat approval
    await signer.send_transaction(
        account, erc721.contract_address, 'approve', [
            user1, *first_token_id]
    )

    # check that approval does not change
    execution_info = await erc721.getApproved(first_token_id).call()
    assert execution_info.result == (user1,)


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

    await assert_revert(signer.send_transaction(
        account, erc721.contract_address, 'setApprovalForAll', [
            user2,
            not_bool
        ]
    ))


@pytest.mark.asyncio
async def test_setApprovalForAll_owner_is_operator(erc721_factory):
    _, erc721, account, _ = erc721_factory

    await assert_revert(signer.send_transaction(
        account, erc721.contract_address, 'setApprovalForAll', [
            account.contract_address,
            true
        ]
    ))


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

    # should be rejected when not approved
    await assert_revert(signer.send_transaction(
        spender, erc721.contract_address, 'transferFrom', [
            account.contract_address,
            recipient,
            *fourth_token_id
        ]
    ))


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

    # to zero address should be rejected
    await assert_revert(signer.send_transaction(
        spender, erc721.contract_address, 'transferFrom', [
            account.contract_address,
            ZERO_ADDRESS,
            *fifth_token_id
        ]
    ))


#
# supportsInterface
#


@pytest.mark.asyncio
@pytest.mark.parametrize('interface_id, result', [
    [str_to_felt('0x01ffc9a7'), true],      # IERC165 id
    [str_to_felt('0x80ac58cd'), true],      # IERC721 id
    [str_to_felt('0x5b5e139f'), true],      # IERC721_Metadata id
    [str_to_felt('0xffffffff'), false],     # id explicitly not supported
    [str_to_felt('0xabcd1234'), false],     # id implicitly not supported
])
async def test_supportsInterface(erc721_factory, interface_id, result):
    _, erc721, _, _ = erc721_factory

    execution_info = await erc721.supportsInterface(interface_id).call()
    assert execution_info.result == (result,)


@pytest.mark.asyncio
async def test_safeTransferFrom(erc721_factory):
    _, erc721, account, erc721_holder = erc721_factory

    await signer.send_transaction(
        account, erc721.contract_address, 'safeTransferFrom', [
            account.contract_address,
            erc721_holder.contract_address,
            *fifth_token_id,
            len(data),
            *data
        ]
    )

    # check balance
    execution_info = await erc721.balanceOf(erc721_holder.contract_address).call()
    assert execution_info.result == (uint(1),)

    # check owner
    execution_info = await erc721.ownerOf(fifth_token_id).call()
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
            spender.contract_address, *sixth_token_id]
    )

    # spender transfers token from account to erc721_holder
    await signer.send_transaction(
        spender, erc721.contract_address, 'safeTransferFrom', [
            account.contract_address,
            erc721_holder.contract_address,
            *sixth_token_id,
            len(data),
            *data
        ]
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
            account.contract_address,
            erc721_holder.contract_address,
            *seventh_token_id,
            len(data),
            *data
        ]
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

    # should fail when not approved or owner
    await assert_revert(signer.send_transaction(
        spender, erc721.contract_address, 'safeTransferFrom', [
            account.contract_address,
            erc721_holder.contract_address,
            *seventh_token_id,
            len(data),
            *data
        ]
    ))


@pytest.mark.asyncio
async def test_safeTransferFrom_to_zero_address(erc721_factory):
    _, erc721, account, _ = erc721_factory

    # mint new token
    await signer.send_transaction(
        account, erc721.contract_address, 'mint', [
            account.contract_address, *eighth_token_id]
    )

    # to zero address should be rejected
    await assert_revert(signer.send_transaction(
        account, erc721.contract_address, 'safeTransferFrom', [
            account.contract_address,
            ZERO_ADDRESS,
            *eighth_token_id,
            len(data),
            *data
        ]
    ))


@pytest.mark.asyncio
async def test_safeTransferFrom_to_unsupported_contract(erc721_factory):
    starknet, erc721, account, _ = erc721_factory
    unsupported_account = await starknet.deploy(
        "contracts/token/ERC20.cairo",
        constructor_calldata=[
            str_to_felt("Token"),
            str_to_felt("TKN"),
            *uint(1),
            account.contract_address
        ]
    )

    try:
        # unsupported_account uses erc20 contract in order to not cause
        # issues once differentiating EOA from contracts is resolved
        await signer.send_transaction(
            account, erc721.contract_address, 'safeTransferFrom', [
                account.contract_address,
                unsupported_account.contract_address,
                *eighth_token_id,
                len(data),
                *data
            ]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.ENTRY_POINT_NOT_FOUND_IN_CONTRACT


@pytest.mark.asyncio
async def test_safeTransferFrom_to_account(erc721_factory):
    starknet, erc721, account, _ = erc721_factory

    account2 = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

    await signer.send_transaction(
        account, erc721.contract_address, 'safeTransferFrom', [
            account.contract_address,
            account2.contract_address,
            *eighth_token_id,
            len(data),
            *data
        ]
    )

    # check balance
    execution_info = await erc721.balanceOf(account2.contract_address).call()
    assert execution_info.result == (uint(1),)

    # check owner
    execution_info = await erc721.ownerOf(eighth_token_id).call()
    assert execution_info.result == (account2.contract_address,)

#
# tokenURI
#


@pytest.mark.asyncio
async def test_tokenURI(erc721_factory):
    _, erc721, account, _ = erc721_factory

    sample_uri = str_to_felt('mock://mytoken')

    # should be zero when tokenURI is not set
    execution_info = await erc721.tokenURI(first_token_id).call()
    assert execution_info.result == (0,)

    # setTokenURI for first_token_id
    await signer.send_transaction(
        account, erc721.contract_address, 'setTokenURI', [
            *first_token_id, sample_uri]
    )

    execution_info = await erc721.tokenURI(first_token_id).call()
    assert execution_info.result == (sample_uri,)

    # setTokenURI for second_token_id
    await signer.send_transaction(
        account, erc721.contract_address, 'setTokenURI', [
            *second_token_id, sample_uri]
    )

    execution_info = await erc721.tokenURI(second_token_id).call()
    assert execution_info.result == (sample_uri,)


@pytest.mark.asyncio
async def test_tokenURI_should_revert_for_nonexistent_token(erc721_factory):
    _, erc721, _, _ = erc721_factory

    # should revert for nonexistent token
    await assert_revert(erc721.tokenURI(nonexistent_token).call())
