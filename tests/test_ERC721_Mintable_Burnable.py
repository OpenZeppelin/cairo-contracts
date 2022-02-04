import pytest
import asyncio
from starkware.starknet.compiler.compile import compile_starknet_files
from starkware.starknet.testing.starknet import Starknet, StarknetContract
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils import (
    Signer, str_to_felt, ZERO_ADDRESS, TRUE, FALSE,
    assert_revert, to_uint, sub_uint, add_uint
)

signer = Signer(123456789987654321)

account_path = 'contracts/Account.cairo'
erc721_path = 'contracts/token/ERC721_Mintable_Burnable.cairo'
erc721_holder_path = 'contracts/token/utils/ERC721_Holder.cairo'
unsupported_path = 'contracts/Initializable.cairo'

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
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
def contract_defs():
    account_def = compile_starknet_files(
        files=[account_path],
        debug_info=True
    )
    erc721_def = compile_starknet_files(
        files=[erc721_path],
        debug_info=True
    )
    erc721_holder_def = compile_starknet_files(
        files=[erc721_holder_path],
        debug_info=True
    )
    unsupported_def = compile_starknet_files(
        files=[unsupported_path],
        debug_info=True
    )
    return account_def, erc721_def, erc721_holder_def, unsupported_def


@pytest.fixture(scope='module')
async def erc721_init(contract_defs):
    account_def, erc721_def, erc721_holder_def, unsupported_def = contract_defs
    starknet = await Starknet.empty()
    account1 = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )
    account2 = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )
    erc721 = await starknet.deploy(
        contract_def=erc721_def,
        constructor_calldata=[
            str_to_felt("Non Fungible Token"),  # name
            str_to_felt("NFT"),                 # ticker
            account1.contract_address
        ]
    )
    erc721_holder = await starknet.deploy(
        contract_def=erc721_holder_def,
        constructor_calldata=[]
    )
    unsupported = await starknet.deploy(
        contract_def=unsupported_def,
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
def erc721_factory(contract_defs, erc721_init):
    account_def, erc721_def, erc721_holder_def, unsupported_def = contract_defs
    state, account1, account2, erc721, erc721_holder, unsupported = erc721_init
    _state = state.copy()
    account1 = StarknetContract(
        state=_state,
        abi=account_def.abi,
        contract_address=account1.contract_address,
        deploy_execution_info=account1.deploy_execution_info
    )
    account2 = StarknetContract(
        state=_state,
        abi=account_def.abi,
        contract_address=account2.contract_address,
        deploy_execution_info=account2.deploy_execution_info
    )
    erc721 = StarknetContract(
        state=_state,
        abi=erc721_def.abi,
        contract_address=erc721.contract_address,
        deploy_execution_info=erc721.deploy_execution_info
    )
    erc721_holder = StarknetContract(
        state=_state,
        abi=erc721_holder_def.abi,
        contract_address=erc721_holder.contract_address,
        deploy_execution_info=erc721_holder.deploy_execution_info
    )
    unsupported = StarknetContract(
        state=_state,
        abi=unsupported_def.abi,
        contract_address=unsupported.contract_address,
        deploy_execution_info=unsupported.deploy_execution_info
    )
    return erc721, account1, account2, erc721_holder, unsupported


@pytest.fixture
# Note that depending on what's being tested, test cases alternate between
# accepting `erc721_minted`, `erc721_factory`, and `erc721_unsupported` fixtures
async def erc721_minted(erc721_factory):
    erc721, account, account2, erc721_holder, _ = erc721_factory
    # mint tokens to account
    for token in TOKENS:
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                account.contract_address, *token]
        )

    return erc721, account, account2, erc721_holder


@pytest.fixture
# Fixture for testing contracts that do not accept safe ERC721 transfers
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
        reverted_with='ERC721_base: balance query for nonexistent token'
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
        reverted_with='ERC721_base: owner query for nonexistent token'
    )


#
# mint
#


@pytest.mark.asyncio
# using fixture with already minted tokens
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
        reverted_with='ERC721_base: token already minted'
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
        reverted_with='ERC721_base: mint to the zero address'
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
        reverted_with='Ownable_base: caller is not the owner'
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
        reverted_with='ERC721_base: approved query for nonexistent token'
    )

    # 'token_to_burn' owner should be zero; therefore,
    # 'ownerOf()' call should fail
    await assert_revert(
        erc721.ownerOf(TOKEN).invoke(),
        reverted_with='ERC721_base: owner query for nonexistent token'
    )


@pytest.mark.asyncio
async def test_burn_nonexistent_token(erc721_minted):
    erc721, account, _, _ = erc721_minted

    await assert_revert(signer.send_transaction(
        account, erc721.contract_address, 'burn', [
            *NONEXISTENT_TOKEN
        ]),
        reverted_with='ERC721_base: owner query for nonexistent token'
    )


@pytest.mark.asyncio
async def test_burn_unowned_token(erc721_minted):
    erc721, account, other, _ = erc721_minted

    # other should not be able to burn account's token
    await assert_revert(
        signer.send_transaction(
            other, erc721.contract_address, 'burn', [*TOKEN]
        ),
        reverted_with='ERC721_base: caller is not the token owner'
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
        reverted_with='ERC721_base: caller is not the token owner'
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
        erc721.approve(spender.contract_address, TOKEN).invoke(),
        reverted_with='ERC721_base: approve from the zero address'
    )


@pytest.mark.asyncio
async def test_approve_owner_is_recipient(erc721_minted):
    erc721, account, _, _ = erc721_minted

    # should fail when owner is the same as address-to-be-approved
    await assert_revert(signer.send_transaction(
        account, erc721.contract_address, 'approve', [
            account.contract_address,
            *TOKEN
        ]),
        reverted_with='ERC721_base: approval to current owner'
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
        reverted_with='ERC721_base: approve caller is not owner nor approved for all'
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

    await assert_revert(signer.send_transaction(
        account, erc721.contract_address, 'setApprovalForAll', [
            spender.contract_address,
            not_bool
        ]),
        reverted_with='ERC721_base: approved value is not a boolean'
    )


@pytest.mark.asyncio
async def test_setApprovalForAll_owner_is_operator(erc721_minted):
    erc721, account, _, _ = erc721_minted

    await assert_revert(signer.send_transaction(
        account, erc721.contract_address, 'setApprovalForAll', [
            account.contract_address,
            TRUE
        ]),
        reverted_with='ERC721_base: approve to caller'
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
        reverted_with='ERC721_base: either caller is the zero address or not approved'
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
        reverted_with='ERC721_base: transfer to the zero address'
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
        reverted_with='ERC721_base: either caller is the zero address or not approved'
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
    await assert_revert(
        signer.send_transaction(
            spender, erc721.contract_address, 'safeTransferFrom', [
                account.contract_address,
                erc721_holder.contract_address,
                *TOKEN,
                len(DATA),
                *DATA
            ]),
        reverted_with='ERC721_base: either caller is the zero address or is not approved'
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
        reverted_with='ERC721_base: transfer to the zero address'
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
        reverted_with='ERC721_base: either caller is the zero address or is not approved'
    )


@pytest.mark.asyncio
async def test_safeTransferFrom_to_unsupported_contract(erc721_unsupported):
    erc721, account, _, _, unsupported = erc721_unsupported

    try:
        await signer.send_transaction(
            account, erc721.contract_address, 'safeTransferFrom', [
                account.contract_address,
                unsupported.contract_address,
                *TOKEN,
                len(DATA),
                *DATA
            ]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.ENTRY_POINT_NOT_FOUND_IN_CONTRACT


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
        reverted_with='ERC721_base: URI query for nonexistent token'
    )


@pytest.mark.asyncio
async def test_setTokenURI_from_not_owner(erc721_minted):
    erc721, _, not_owner, _ = erc721_minted

    await assert_revert(signer.send_transaction(
        not_owner, erc721.contract_address, 'setTokenURI', [
            *TOKEN,
            SAMPLE_URI_1
        ]),
        reverted_with='Ownable_base: caller is not the owner'
    )


@pytest.mark.asyncio
async def test_setTokenURI_for_nonexistent_token(erc721_minted):
    erc721, account, _, _ = erc721_minted

    await assert_revert(signer.send_transaction(
        account, erc721.contract_address, 'setTokenURI', [
            *NONEXISTENT_TOKEN,
            SAMPLE_URI_1
        ]),
        reverted_with='ERC721_base: token does not exist'
    )
