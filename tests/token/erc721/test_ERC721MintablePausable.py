import pytest
from signers import MockSigner
from utils import (
    str_to_felt, TRUE, FALSE, get_contract_class, cached_contract,
    assert_revert, assert_event_emitted, to_uint, ZERO_ADDRESS, State, Account
)
from ERC721BaseSuite import ERC721Base, NAME, SYMBOL, TOKENS, TOKEN, NONEXISTENT_TOKEN, DATA
from access.OwnableBaseSuite import OwnableBase


signer = MockSigner(123456789987654321)

# testing vars
TOKEN_TO_MINT = to_uint(33)


@pytest.fixture(scope='module')
def contract_classes():
    account_cls = Account.get_class
    erc721_cls = get_contract_class('ERC721MintablePausable')
    erc721_holder_cls = get_contract_class('ERC721Holder')
    unsupported_cls = get_contract_class('Initializable')

    return account_cls, erc721_cls, erc721_holder_cls, unsupported_cls


@pytest.fixture(scope='module')
async def erc721_init(contract_classes):
    account_cls, erc721_cls, erc721_holder_cls, unsupported_cls = contract_classes
    starknet = await State.init()
    account1 = await Account.deploy(signer.public_key)
    account2 = await Account.deploy(signer.public_key)
    erc721 = await starknet.deploy(
        contract_class=erc721_cls,
        constructor_calldata=[
            NAME,                       # name
            SYMBOL,                     # ticker
            account1.contract_address   # owner
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
        unsupported,
    )


@pytest.fixture
def contract_factory(contract_classes, erc721_init):
    account_cls, erc721_cls, erc721_holder_cls, unsupported_cls = contract_classes
    state, account1, account2, erc721, erc721_holder, unsupported = erc721_init
    _state = state.copy()
    account1 = cached_contract(_state, account_cls, account1)
    account2 = cached_contract(_state, account_cls, account2)
    erc721 = cached_contract(_state, erc721_cls, erc721)
    erc721_holder = cached_contract(_state, erc721_holder_cls, erc721_holder)
    unsupported = cached_contract(_state, unsupported_cls, unsupported)

    return erc721, account1, account2, erc721_holder, unsupported


@pytest.fixture
async def erc721_minted(contract_factory):
    erc721, account, account2, erc721_holder, unsupported = contract_factory
    # mint tokens to account
    for token in TOKENS:
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                account.contract_address, *token]
        )

    return erc721, account, account2, erc721_holder, unsupported


class TestERC721MintablePausable(ERC721Base, OwnableBase):
    #
    # mint
    #

    @pytest.mark.asyncio
    async def test_mint_emits_event(self, contract_factory):
        erc721, account, _, _, _ = contract_factory

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


    @pytest.mark.asyncio
    async def test_mint(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        # checks balance
        execution_info = await erc721.balanceOf(account.contract_address).execute()
        assert execution_info.result == (to_uint(2),)

        # checks that account owns correct tokens
        for token in TOKENS:
            execution_info = await erc721.ownerOf(token).execute()
            assert execution_info.result == (account.contract_address,)


    @pytest.mark.asyncio
    async def test_mint_duplicate_token_id(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        # minting duplicate token_id should fail
        await assert_revert(signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                account.contract_address,
                *TOKEN
            ]),
            reverted_with="ERC721: token already minted"
        )


    @pytest.mark.asyncio
    async def test_mint_to_zero_address(self, erc721_minted):
        erc721, account, *_ = erc721_minted

        # minting to zero address should fail
        await assert_revert(signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                ZERO_ADDRESS,
                *NONEXISTENT_TOKEN
            ]),
            reverted_with="ERC721: cannot mint to the zero address"
        )


    @pytest.mark.asyncio
    async def test_mint_approve_should_be_zero_address(self, erc721_minted):
        erc721, *_ = erc721_minted

        # approved address should be zero for newly minted tokens
        for token in TOKENS:
            execution_info = await erc721.getApproved(token).execute()
            assert execution_info.result == (0,)


    @pytest.mark.asyncio
    async def test_mint_by_not_owner(self, contract_factory):
        erc721, _, not_owner, _, _ = contract_factory

        # minting from not_owner should fail
        await assert_revert(signer.send_transaction(
            not_owner, erc721.contract_address, 'mint', [
                not_owner.contract_address,
                *TOKENS[0]
            ]),
            reverted_with="Ownable: caller is not the owner"
        )

    #
    # pause
    #

    @pytest.mark.asyncio
    async def test_pause(self, erc721_minted):
        erc721, owner, other, erc721_holder, _ = erc721_minted

        # pause
        await signer.send_transaction(owner, erc721.contract_address, 'pause', [])

        execution_info = await erc721.paused().execute()
        assert execution_info.result.paused == TRUE

        await assert_revert(signer.send_transaction(
            owner, erc721.contract_address, 'approve', [
                other.contract_address,
                *TOKENS[0]
            ]),
            reverted_with="Pausable: paused"
        )

        await assert_revert(signer.send_transaction(
            owner, erc721.contract_address, 'setApprovalForAll', [
                other.contract_address,
                TRUE
            ]),
            reverted_with="Pausable: paused"
        )

        await assert_revert(signer.send_transaction(
            owner, erc721.contract_address, 'transferFrom', [
                owner.contract_address,
                other.contract_address,
                *TOKENS[0]
            ]),
            reverted_with="Pausable: paused"
        )

        await assert_revert(signer.send_transaction(
            owner, erc721.contract_address, 'safeTransferFrom', [
                owner.contract_address,
                erc721_holder.contract_address,
                *TOKENS[1],
                len(DATA),
                *DATA
            ]),
            reverted_with="Pausable: paused"
        )

        await assert_revert(signer.send_transaction(
            owner, erc721.contract_address, 'mint', [
                other.contract_address,
                *TOKEN_TO_MINT
            ]),
            reverted_with="Pausable: paused"
        )


    @pytest.mark.asyncio
    async def test_unpause(self, erc721_minted):
        erc721, owner, other, erc721_holder, _ = erc721_minted

        # pause
        await signer.send_transaction(owner, erc721.contract_address, 'pause', [])

        # unpause
        await signer.send_transaction(owner, erc721.contract_address, 'unpause', [])

        execution_info = await erc721.paused().execute()
        assert execution_info.result.paused == FALSE

        await signer.send_transaction(
            owner, erc721.contract_address, 'approve', [
                other.contract_address,
                *TOKENS[0]
            ]
        )

        await signer.send_transaction(
            owner, erc721.contract_address, 'setApprovalForAll', [
                other.contract_address,
                TRUE
            ]
        )

        await signer.send_transaction(
            owner, erc721.contract_address, 'transferFrom', [
                owner.contract_address,
                other.contract_address,
                *TOKENS[0]
            ]
        )

        await signer.send_transaction(
            other, erc721.contract_address, 'safeTransferFrom', [
                owner.contract_address,
                erc721_holder.contract_address,
                *TOKENS[1],
                len(DATA),
                *DATA
            ]
        )

        await signer.send_transaction(
            owner, erc721.contract_address, 'mint', [
                other.contract_address,
                *TOKEN_TO_MINT
            ]
        )


    @pytest.mark.asyncio
    async def test_only_owner(self, erc721_minted):
        erc721, owner, other, *_ = erc721_minted

        # not-owner pause should revert
        await assert_revert(
            signer.send_transaction(
                other, erc721.contract_address, 'pause', []),
            reverted_with="Ownable: caller is not the owner"
        )

        # owner pause
        await signer.send_transaction(owner, erc721.contract_address, 'pause', [])

        # not-owner unpause should revert
        await assert_revert(
            signer.send_transaction(
                other, erc721.contract_address, 'unpause', []),
            reverted_with="Ownable: caller is not the owner"
        )

        # owner unpause
        await signer.send_transaction(owner, erc721.contract_address, 'unpause', [])
