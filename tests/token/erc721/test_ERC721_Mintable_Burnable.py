import pytest
from starkware.starknet.testing.starknet import Starknet
from signers import MockSigner
from utils import (
    str_to_felt, ZERO_ADDRESS, TRUE, FALSE, assert_revert, INVALID_UINT256,
    assert_event_emitted, get_contract_class, cached_contract, to_uint, sub_uint, add_uint
)


signer = MockSigner(123456789987654321)

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


@pytest.fixture(scope='module')
def contract_classes():
    account_cls = get_contract_class('openzeppelin/account/Account.cairo')
    erc721_cls = get_contract_class(
        'openzeppelin/token/erc721/ERC721_Mintable_Burnable.cairo')
    erc721_holder_cls = get_contract_class(
        'openzeppelin/token/erc721/utils/ERC721_Holder.cairo')
    unsupported_cls = get_contract_class(
        'tests/mocks/Initializable.cairo')

    return account_cls, erc721_cls, erc721_holder_cls, unsupported_cls


@pytest.fixture(scope='module')
async def erc721_init(contract_classes):
    account_cls, erc721_cls, erc721_holder_cls, unsupported_cls = contract_classes
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
        unsupported
    )


@pytest.fixture
def erc721_factory(contract_classes, erc721_init):
    account_cls, erc721_cls, erc721_holder_cls, unsupported_cls = contract_classes
    state, account1, account2, erc721, erc721_holder, unsupported = erc721_init
    _state = state.copy()
    account1 = cached_contract(_state, account_cls, account1)
    account2 = cached_contract(_state, account_cls, account2)
    erc721 = cached_contract(_state, erc721_cls, erc721)
    erc721_holder = cached_contract(_state, erc721_holder_cls, erc721_holder)
    unsupported = cached_contract(_state, unsupported_cls, unsupported)

    return erc721, account1, account2, erc721_holder, unsupported


# Note that depending on what's being tested, test cases alternate between
# accepting `erc721_minted`, `erc721_factory`, and `erc721_unsupported` fixtures
@pytest.fixture
async def erc721_minted(erc721_factory):
    erc721, account, account2, erc721_holder, _ = erc721_factory
    # mint tokens to account
    for token in TOKENS:
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                account.contract_address, *token]
        )

    return erc721, account, account2, erc721_holder


# Fixture for testing contracts that do not accept safe ERC721 transfers
@pytest.fixture
async def erc721_unsupported(erc721_factory):
    erc721, account, account2, erc721_holder, unsupported = erc721_factory
    for token in TOKENS:
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                account.contract_address, *token]
        )

    return erc721, account, account2, erc721_holder, unsupported


#
# Constructor
#


@pytest.mark.asyncio
async def test_constructor(erc721_factory):
    erc721, _, _, _, _ = erc721_factory
    execution_info = await erc721.name().invoke()
    assert execution_info.result == (str_to_felt("Non Fungible Token"),)

    execution_info = await erc721.symbol().invoke()
    assert execution_info.result == (str_to_felt("NFT"),)


#
# balanceOf
#


@pytest.mark.asyncio
async def test_balanceOf(erc721_factory):
    erc721, account, _, _, _ = erc721_factory

    # mint tokens to account
    for token in TOKENS:
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                account.contract_address, *token]
        )

    execution_info = await erc721.balanceOf(account.contract_address).invoke()
    n_tokens = len(TOKENS)
    assert execution_info.result == (to_uint(n_tokens),)

    # user should have zero tokens
    execution_info = await erc721.balanceOf(RECIPIENT).invoke()
    assert execution_info.result == (to_uint(0),)


@pytest.mark.asyncio
async def test_balanceOf_zero_address(erc721_factory):
    erc721, account, _, _, _ = erc721_factory

    # mint tokens to account
    await signer.send_transaction(
        account, erc721.contract_address, 'mint', [
            account.contract_address, *TOKEN]
    )

    # should revert when querying zero address
    await assert_revert(
        erc721.balanceOf(ZERO_ADDRESS).invoke(),
        reverted_with="ERC721: balance query for the zero address"
    )


#
# ownerOf
#


@pytest.mark.asyncio
async def test_ownerOf(erc721_factory):
    erc721, account, _, _, _ = erc721_factory

    # mint tokens to account
    for token in TOKENS:
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                account.contract_address, *token]
        )

        # should return account's address
        execution_info = await erc721.ownerOf(token).invoke()
        assert execution_info.result == (account.contract_address,)


@pytest.mark.asyncio
async def test_ownerOf_nonexistent_token(erc721_factory):
    erc721, account, _, _, _ = erc721_factory

    # mint token to account
    await signer.send_transaction(
        account, erc721.contract_address, 'mint', [
            account.contract_address, *TOKEN]
    )

    # should revert when querying nonexistent token
    await assert_revert(
        erc721.ownerOf(NONEXISTENT_TOKEN).invoke(),
        reverted_with="ERC721: owner query for nonexistent token"
    )


@pytest.mark.asyncio
async def test_ownerOf_invalid_uint256(erc721_factory):
    erc721, _, _, _, _ = erc721_factory

    # should revert when querying nonexistent token
    await assert_revert(
        erc721.ownerOf(INVALID_UINT256).invoke(),
        reverted_with="ERC721: token_id is not a valid Uint256"
    )


#
# mint
#


@pytest.mark.asyncio
async def test_mint_emits_event(erc721_factory):
    erc721, account, _, _, _ = erc721_factory

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


# using fixture with already minted tokens
@pytest.mark.asyncio
async def test_mint(erc721_minted):
    erc721, account, _, _ = erc721_minted

    # checks balance
    execution_info = await erc721.balanceOf(account.contract_address).invoke()
    assert execution_info.result == (to_uint(2),)

    # checks that account owns correct tokens
    for token in TOKENS:
        execution_info = await erc721.ownerOf(token).invoke()
        assert execution_info.result == (account.contract_address,)


@pytest.mark.asyncio
async def test_mint_duplicate_token_id(erc721_minted):
    erc721, account, _, _ = erc721_minted

    # minting duplicate token_id should fail
    await assert_revert(signer.send_transaction(
        account, erc721.contract_address, 'mint', [
            account.contract_address,
            *TOKEN
        ]),
        reverted_with="ERC721: token already minted"
    )


@pytest.mark.asyncio
async def test_mint_to_zero_address(erc721_minted):
    erc721, account, _, _ = erc721_minted

    # minting to zero address should fail
    await assert_revert(signer.send_transaction(
        account, erc721.contract_address, 'mint', [
            ZERO_ADDRESS,
            *NONEXISTENT_TOKEN
        ]),
        reverted_with="ERC721: cannot mint to the zero address"
    )


@pytest.mark.asyncio
async def test_mint_approve_should_be_zero_address(erc721_minted):
    erc721, _, _, _ = erc721_minted

    # approved address should be zero for newly minted tokens
    for token in TOKENS:
        execution_info = await erc721.getApproved(token).invoke()
        assert execution_info.result == (0,)


@pytest.mark.asyncio
async def test_mint_by_not_owner(erc721_factory):
    erc721, _, not_owner, _, _ = erc721_factory

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
async def test_burn(erc721_minted):
    erc721, account, _, _ = erc721_minted

    execution_info = await erc721.balanceOf(account.contract_address).invoke()
    previous_balance = execution_info.result.balance

    # burn token
    await signer.send_transaction(
        account, erc721.contract_address, 'burn', [*TOKEN]
    )

    # account balance should subtract one
    execution_info = await erc721.balanceOf(account.contract_address).invoke()
    assert execution_info.result.balance == sub_uint(
        previous_balance, to_uint(1)
    )

    # approve should be cleared to zero, therefore,
    # 'getApproved()' call should fail
    await assert_revert(
        erc721.getApproved(TOKEN).invoke(),
        reverted_with="ERC721: approved query for nonexistent token"
    )

    # 'token_to_burn' owner should be zero; therefore,
    # 'ownerOf()' call should fail
    await assert_revert(
        erc721.ownerOf(TOKEN).invoke(),
        reverted_with="ERC721: owner query for nonexistent token"
    )


@pytest.mark.asyncio
async def test_burn_emits_event(erc721_minted):
    erc721, account, _, _ = erc721_minted

    # mint token to account
    tx_exec_info = await signer.send_transaction(
        account, erc721.contract_address, 'burn', [
            *TOKEN
        ]
    )

    assert_event_emitted(
        tx_exec_info,
        from_address=erc721.contract_address,
        name='Transfer',
        data=[
            account.contract_address,
            ZERO_ADDRESS,
            *TOKEN
        ]
    )


@pytest.mark.asyncio
async def test_burn_nonexistent_token(erc721_minted):
    erc721, account, _, _ = erc721_minted

    await assert_revert(signer.send_transaction(
        account, erc721.contract_address, 'burn', [
            *NONEXISTENT_TOKEN
        ]),
        reverted_with="ERC721: owner query for nonexistent token"
    )


@pytest.mark.asyncio
async def test_burn_unowned_token(erc721_minted):
    erc721, account, other, _ = erc721_minted

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
async def test_burn_from_zero_address(erc721_minted):
    erc721, _, _, _ = erc721_minted

    await assert_revert(
        erc721.burn(TOKEN).invoke(),
        reverted_with="ERC721: caller is not the token owner"
    )


#
# approve
#


@pytest.mark.asyncio
async def test_approve(erc721_minted):
    erc721, account, spender, _ = erc721_minted

    await signer.send_transaction(
        account, erc721.contract_address, 'approve', [
            spender.contract_address, *TOKEN]
    )

    execution_info = await erc721.getApproved(TOKEN).invoke()
    assert execution_info.result == (spender.contract_address,)


@pytest.mark.asyncio
async def test_approve_emits_event(erc721_minted):
    erc721, account, spender, _ = erc721_minted

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
async def test_approve_on_setApprovalForAll(erc721_minted):
    erc721, account, spender, _ = erc721_minted

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

    execution_info = await erc721.getApproved(TOKEN).invoke()
    assert execution_info.result == (RECIPIENT,)


@pytest.mark.asyncio
async def test_approve_from_zero_address(erc721_minted):
    erc721, _, spender, _ = erc721_minted

    # Without using an account abstraction, the caller address
    # (get_caller_address) is zero
    await assert_revert(
        erc721.approve(
            spender.contract_address, TOKEN).invoke(),
        reverted_with="ERC721: cannot approve from the zero address"
    )


@pytest.mark.asyncio
async def test_approve_owner_is_recipient(erc721_minted):
    erc721, account, _, _ = erc721_minted

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
async def test_approve_not_owner_or_operator(erc721_factory):
    erc721, account, spender, _, _ = erc721_factory

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
async def test_approve_on_already_approved(erc721_minted):
    erc721, account, spender, _ = erc721_minted

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
    execution_info = await erc721.getApproved(TOKEN).invoke()
    assert execution_info.result == (spender.contract_address,)


@pytest.mark.asyncio
async def test_getApproved_nonexistent_token(erc721_minted):
    erc721, _, _, _ = erc721_minted

    await assert_revert(
        erc721.getApproved(NONEXISTENT_TOKEN).invoke(),
        reverted_with="ERC721: approved query for nonexistent token"
    )


@pytest.mark.asyncio
async def test_getApproved_invalid_uint256(erc721_minted):
    erc721, _, _, _ = erc721_minted

    await assert_revert(
        erc721.getApproved(INVALID_UINT256).invoke(),
        reverted_with="ERC721: token_id is not a valid Uint256"
    )


#
# setApprovalForAll
#


@pytest.mark.asyncio
async def test_setApprovalForAll(erc721_minted):
    erc721, account, spender, _ = erc721_minted

    await signer.send_transaction(
        account, erc721.contract_address, 'setApprovalForAll', [
            spender.contract_address, TRUE]
    )

    execution_info = await erc721.isApprovedForAll(
        account.contract_address, spender.contract_address).invoke()
    assert execution_info.result == (TRUE,)


@pytest.mark.asyncio
async def test_setApprovalForAll_emits_event(erc721_minted):
    erc721, account, spender, _ = erc721_minted

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
async def test_setApprovalForAll_when_operator_was_set_as_not_approved(erc721_minted):
    erc721, account, spender, _ = erc721_minted

    await signer.send_transaction(
        account, erc721.contract_address, 'setApprovalForAll', [
            spender.contract_address, FALSE]
    )

    await signer.send_transaction(
        account, erc721.contract_address, 'setApprovalForAll', [
            spender.contract_address, TRUE]
    )

    execution_info = await erc721.isApprovedForAll(
        account.contract_address, spender.contract_address).invoke()
    assert execution_info.result == (TRUE,)


@pytest.mark.asyncio
async def test_setApprovalForAll_with_invalid_bool_arg(erc721_minted):
    erc721, account, spender, _ = erc721_minted

    not_bool = 2

    await assert_revert(
        signer.send_transaction(
            account, erc721.contract_address, 'setApprovalForAll', [
                spender.contract_address,
                not_bool
            ]),
        reverted_with="ERC721: approved is not a Cairo boolean")


@pytest.mark.asyncio
async def test_setApprovalForAll_owner_is_operator(erc721_minted):
    erc721, account, _, _ = erc721_minted

    await assert_revert(
        signer.send_transaction(
            account, erc721.contract_address, 'setApprovalForAll', [
                account.contract_address,
                TRUE
            ]),
        reverted_with="ERC721: approve to caller"
    )


@pytest.mark.asyncio
async def test_setApprovalForAll_from_zero_address(erc721_minted):
    erc721, account, _, _ = erc721_minted

    await assert_revert(
        erc721.setApprovalForAll(account.contract_address, TRUE).invoke(),
        reverted_with="ERC721: either the caller or operator is the zero address"
    )


@pytest.mark.asyncio
async def test_setApprovalForAll_operator_is_zero_address(erc721_minted):
    erc721, account, _, _ = erc721_minted

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
async def test_transferFrom_owner(erc721_minted):
    erc721, account, _, _ = erc721_minted

    # get account's previous balance
    execution_info = await erc721.balanceOf(account.contract_address).invoke()
    previous_balance = execution_info.result.balance

    # transfers token from account to recipient
    await signer.send_transaction(
        account, erc721.contract_address, 'transferFrom', [
            account.contract_address, RECIPIENT, *TOKEN]
    )

    # checks recipient balance
    execution_info = await erc721.balanceOf(RECIPIENT).invoke()
    assert execution_info.result == (to_uint(1),)

    # checks account balance
    execution_info = await erc721.balanceOf(account.contract_address).invoke()
    assert execution_info.result.balance == sub_uint(
        previous_balance, to_uint(1))

    # checks token has new owner
    execution_info = await erc721.ownerOf(TOKEN).invoke()
    assert execution_info.result == (RECIPIENT,)

    # checks approval is cleared for token_id
    execution_info = await erc721.getApproved(TOKEN).invoke()
    assert execution_info.result == (0,)


@pytest.mark.asyncio
async def test_transferFrom_emits_events(erc721_minted):
    erc721, account, spender, _ = erc721_minted

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

    assert_event_emitted(
        tx_exec_info,
        from_address=erc721.contract_address,
        name='Transfer',
        data=[
            account.contract_address,
            RECIPIENT,
            *TOKEN
        ]
    )

    assert_event_emitted(
        tx_exec_info,
        from_address=erc721.contract_address,
        name='Approval',
        data=[
            account.contract_address,
            ZERO_ADDRESS,
            *TOKEN
        ]
    )


@pytest.mark.asyncio
async def test_transferFrom_approved_user(erc721_minted):
    erc721, account, spender, _ = erc721_minted

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
    execution_info = await erc721.balanceOf(RECIPIENT).invoke()
    assert execution_info.result == (to_uint(1),)


@pytest.mark.asyncio
async def test_transferFrom_operator(erc721_minted):
    erc721, account, spender, _ = erc721_minted

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
    execution_info = await erc721.balanceOf(RECIPIENT).invoke()
    assert execution_info.result == (to_uint(1),)


@pytest.mark.asyncio
async def test_transferFrom_when_not_approved_or_owner(erc721_minted):
    erc721, account, spender, _ = erc721_minted

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
async def test_transferFrom_to_zero_address(erc721_minted):
    erc721, account, spender, _ = erc721_minted

    # setApprovalForAll
    await signer.send_transaction(
        account, erc721.contract_address, 'setApprovalForAll', [
            spender.contract_address, TRUE]
    )

    # to zero address should be rejected
    await assert_revert(signer.send_transaction(
        spender, erc721.contract_address, 'transferFrom', [
            account.contract_address,
            ZERO_ADDRESS,
            *TOKEN
        ]),
        reverted_with="ERC721: cannot transfer to the zero address"
    )


@pytest.mark.asyncio
async def test_transferFrom_invalid_uint256(erc721_minted):
    erc721, account, _, _ = erc721_minted

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
async def test_transferFrom_from_zero_address(erc721_minted):
    erc721, account, _, _ = erc721_minted

    # caller address is `0` when not using an account contract
    await assert_revert(
        erc721.transferFrom(
            account.contract_address,
            RECIPIENT,
            TOKEN
        ).invoke(),
        reverted_with="ERC721: either is not approved or the caller is the zero address"
    )


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
async def test_supportsInterface(erc721_factory, interface_id, result):
    erc721, _, _, _, _ = erc721_factory

    execution_info = await erc721.supportsInterface(interface_id).invoke()
    assert execution_info.result == (result,)


#
# safeTransferFrom
#


@pytest.mark.asyncio
async def test_safeTransferFrom(erc721_minted):
    erc721, account, _, erc721_holder = erc721_minted

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
    execution_info = await erc721.balanceOf(erc721_holder.contract_address).invoke()
    assert execution_info.result == (to_uint(1),)

    # check owner
    execution_info = await erc721.ownerOf(TOKEN).invoke()
    assert execution_info.result == (erc721_holder.contract_address,)


@pytest.mark.asyncio
async def test_safeTransferFrom_emits_events(erc721_minted):
    erc721, account, _, erc721_holder = erc721_minted

    tx_exec_info = await signer.send_transaction(
        account, erc721.contract_address, 'safeTransferFrom', [
            account.contract_address,
            erc721_holder.contract_address,
            *TOKEN,
            len(DATA),
            *DATA
        ]
    )

    assert_event_emitted(
        tx_exec_info,
        from_address=erc721.contract_address,
        name='Transfer',
        data=[
            account.contract_address,
            erc721_holder.contract_address,
            *TOKEN
        ]
    )

    assert_event_emitted(
        tx_exec_info,
        from_address=erc721.contract_address,
        name='Approval',
        data=[
            account.contract_address,
            ZERO_ADDRESS,
            *TOKEN
        ]
    )


@pytest.mark.asyncio
async def test_safeTransferFrom_from_approved(erc721_minted):
    erc721, account, spender, erc721_holder = erc721_minted

    execution_info = await erc721.balanceOf(erc721_holder.contract_address).invoke()
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
    execution_info = await erc721.balanceOf(erc721_holder.contract_address).invoke()
    assert execution_info.result.balance == add_uint(
        previous_balance, to_uint(1)
    )


@pytest.mark.asyncio
async def test_safeTransferFrom_from_operator(erc721_minted):
    erc721, account, spender, erc721_holder = erc721_minted

    execution_info = await erc721.balanceOf(erc721_holder.contract_address).invoke()
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
    execution_info = await erc721.balanceOf(erc721_holder.contract_address).invoke()
    assert execution_info.result.balance == add_uint(
        previous_balance, to_uint(1)
    )


@pytest.mark.asyncio
async def test_safeTransferFrom_when_not_approved_or_owner(erc721_minted):
    erc721, account, spender, erc721_holder = erc721_minted

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
async def test_safeTransferFrom_to_zero_address(erc721_minted):
    erc721, account, _, _ = erc721_minted

    # to zero address should be rejected
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


@pytest.mark.asyncio
async def test_safeTransferFrom_from_zero_address(erc721_minted):
    erc721, account, _, erc721_holder = erc721_minted

    # caller address is `0` when not using an account contract
    await assert_revert(
        erc721.safeTransferFrom(
            account.contract_address,
            erc721_holder.contract_address,
            TOKEN,
            DATA
        ).invoke(),
        reverted_with="ERC721: either is not approved or the caller is the zero address"
    )


@pytest.mark.asyncio
async def test_safeTransferFrom_to_unsupported_contract(erc721_unsupported):
    erc721, account, _, _, unsupported = erc721_unsupported

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
async def test_safeTransferFrom_to_account(erc721_minted):
    erc721, account, account2, _ = erc721_minted

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
    execution_info = await erc721.balanceOf(account2.contract_address).invoke()
    assert execution_info.result == (to_uint(1),)

    # check owner
    execution_info = await erc721.ownerOf(TOKEN).invoke()
    assert execution_info.result == (account2.contract_address,)


@pytest.mark.asyncio
async def test_safeTransferFrom_invalid_uint256(erc721_minted):
    erc721, account, _, erc721_holder = erc721_minted

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
async def test_tokenURI(erc721_minted):
    erc721, account, _, _ = erc721_minted

    token_1 = TOKENS[0]
    token_2 = TOKENS[1]

    # should be zero when tokenURI is not set
    execution_info = await erc721.tokenURI(token_1).invoke()
    assert execution_info.result == (0,)

    # setTokenURI for token_1
    await signer.send_transaction(
        account, erc721.contract_address, 'setTokenURI', [
            *token_1,
            SAMPLE_URI_1
        ]
    )

    execution_info = await erc721.tokenURI(token_1).invoke()
    assert execution_info.result == (SAMPLE_URI_1,)

    # setTokenURI for token_2
    await signer.send_transaction(
        account, erc721.contract_address, 'setTokenURI', [
            *token_2,
            SAMPLE_URI_2
        ]
    )

    execution_info = await erc721.tokenURI(token_2).invoke()
    assert execution_info.result == (SAMPLE_URI_2,)


@pytest.mark.asyncio
async def test_tokenURI_should_revert_for_nonexistent_token(erc721_minted):
    erc721, _, _, _ = erc721_minted

    # should revert for nonexistent token
    await assert_revert(
        erc721.tokenURI(NONEXISTENT_TOKEN).invoke(),
        reverted_with="ERC721_Metadata: URI query for nonexistent token"
    )


@pytest.mark.asyncio
async def test_setTokenURI_from_not_owner(erc721_minted):
    erc721, _, not_owner, _ = erc721_minted

    await assert_revert(signer.send_transaction(
        not_owner, erc721.contract_address, 'setTokenURI', [
            *TOKEN,
            SAMPLE_URI_1
        ]),
        reverted_with="Ownable: caller is not the owner"
    )


@pytest.mark.asyncio
async def test_setTokenURI_for_nonexistent_token(erc721_minted):
    erc721, _, not_owner, _ = erc721_minted

    await assert_revert(signer.send_transaction(
        not_owner, erc721.contract_address, 'setTokenURI', [
            *NONEXISTENT_TOKEN,
            SAMPLE_URI_1
        ]),
        reverted_with="Ownable: caller is not the owner"
    )
