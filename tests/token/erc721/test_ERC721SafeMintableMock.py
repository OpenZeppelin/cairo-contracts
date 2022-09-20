import pytest
from signers import MockSigner
from utils import (
    ZERO_ADDRESS, INVALID_UINT256, assert_revert,
    assert_event_emitted, get_contract_class, cached_contract, to_uint,
    State, Account
)
from ERC721BaseSuite import ERC721Base, NAME, SYMBOL, DATA, TOKEN, TOKENS
from access.OwnableBaseSuite import OwnableBase


signer = MockSigner(123456789987654321)


@pytest.fixture(scope='module')
def contract_classes():
    account_cls = Account.get_class
    erc721_cls = get_contract_class('ERC721SafeMintableMock')
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
        unsupported
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


class TestERC721SafeMintableMock(ERC721Base, OwnableBase):
    #
    # safeMint
    #

    @pytest.mark.asyncio
    async def test_safeMint_to_erc721_supported_contract(self, contract_factory):
        erc721, account, _, erc721_holder, _ = contract_factory

        await signer.send_transaction(
            account, erc721.contract_address, 'safeMint', [
                erc721_holder.contract_address,
                *TOKEN,
                len(DATA),
                *DATA
            ]
        )

        # check balance
        execution_info = await erc721.balanceOf(erc721_holder.contract_address).call()
        assert execution_info.result == (to_uint(1),)

        # check owner
        execution_info = await erc721.ownerOf(TOKEN).call()
        assert execution_info.result == (erc721_holder.contract_address,)


    @pytest.mark.asyncio
    async def test_safeMint_emits_event(self, contract_factory):
        erc721, account, _, erc721_holder, _ = contract_factory

        tx_exec_info = await signer.send_transaction(
            account, erc721.contract_address, 'safeMint', [
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
                ZERO_ADDRESS,
                erc721_holder.contract_address,
                *TOKEN
            ]
        )


    @pytest.mark.asyncio
    async def test_safeMint_to_account(self, contract_factory):
        erc721, account, recipient, _, _ = contract_factory

        await signer.send_transaction(
            account, erc721.contract_address, 'safeMint', [
                recipient.contract_address,
                *TOKEN,
                len(DATA),
                *DATA
            ]
        )

        # check balance
        execution_info = await erc721.balanceOf(recipient.contract_address).call()
        assert execution_info.result == (to_uint(1),)

        # check owner
        execution_info = await erc721.ownerOf(TOKEN).call()
        assert execution_info.result == (recipient.contract_address,)


    @pytest.mark.asyncio
    async def test_safeMint_to_zero_address(self, contract_factory):
        erc721, account, _, _, _ = contract_factory

        # to zero address should be rejected
        await assert_revert(signer.send_transaction(
            account, erc721.contract_address, 'safeMint', [
                ZERO_ADDRESS,
                *TOKEN,
                len(DATA),
                *DATA
            ]),
            reverted_with="ERC721: cannot mint to the zero address"
        )


    @pytest.mark.asyncio
    async def test_safeMint_from_zero_address(self, contract_factory):
        erc721, _, _, erc721_holder, _ = contract_factory

        # Caller address is `0` when not using an account contract
        await assert_revert(
            erc721.safeMint(
                erc721_holder.contract_address,
                TOKEN,
                DATA
            ).execute(),
            reverted_with="Ownable: caller is the zero address"
        )


    @pytest.mark.asyncio
    async def test_safeMint_from_not_owner(self, contract_factory):
        erc721, _, other, erc721_holder, _ = contract_factory

        await assert_revert(signer.send_transaction(
            other, erc721.contract_address, 'safeMint', [
                erc721_holder.contract_address,
                *TOKEN,
                len(DATA),
                *DATA
            ]),
            reverted_with="Ownable: caller is not the owner"
        )


    @pytest.mark.asyncio
    async def test_safeMint_to_unsupported_contract(self, contract_factory):
        erc721, account, _, _, unsupported = contract_factory

        await assert_revert(signer.send_transaction(
            account, erc721.contract_address, 'safeMint', [
                unsupported.contract_address,
                *TOKEN,
                len(DATA),
                *DATA
            ])
        )


    @pytest.mark.asyncio
    async def test_safeMint_invalid_uint256(self, contract_factory):
        erc721, account, recipient, _, _ = contract_factory

        await assert_revert(signer.send_transaction(
            account, erc721.contract_address, 'safeMint', [
                recipient.contract_address,
                *INVALID_UINT256,
                len(DATA),
                *DATA
            ]),
            reverted_with="ERC721: token_id is not a valid Uint256"
        )
