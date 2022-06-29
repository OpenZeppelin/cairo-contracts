import pytest
from starkware.starknet.testing.starknet import Starknet
from signers import MockSigner
from utils import (
    str_to_felt, ZERO_ADDRESS, INVALID_UINT256, assert_revert,
    assert_event_emitted, get_contract_class, cached_contract, to_uint
)


signer = MockSigner(123456789987654321)

# random token id
TOKEN = to_uint(5042)
# random data (mimicking bytes in Solidity)
DATA = [0x42, 0x89, 0x55]


@pytest.fixture(scope='module')
def contract_classes():
    account_cls = get_contract_class('openzeppelin/account/Account.cairo')
    erc721_cls = get_contract_class('tests/mocks/ERC721_SafeMintable_mock.cairo')
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
            account1.contract_address
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


@pytest.mark.asyncio
async def test_safeMint_to_erc721_supported_contract(erc721_factory):
    erc721, account, _, erc721_holder, _ = erc721_factory

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
async def test_safeMint_emits_event(erc721_factory):
    erc721, account, _, erc721_holder, _ = erc721_factory

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
async def test_safeMint_to_account(erc721_factory):
    erc721, account, recipient, _, _ = erc721_factory

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
async def test_safeMint_to_zero_address(erc721_factory):
    erc721, account, _, _, _ = erc721_factory

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
async def test_safeMint_from_zero_address(erc721_factory):
    erc721, _, _, erc721_holder, _ = erc721_factory

    # Caller address is `0` when not using an account contract
    await assert_revert(
        erc721.safeMint(
            erc721_holder.contract_address,
            TOKEN,
            DATA
        ).invoke(),
        reverted_with="Ownable: caller is not the owner"
    )


@pytest.mark.asyncio
async def test_safeMint_from_not_owner(erc721_factory):
    erc721, _, other, erc721_holder, _ = erc721_factory

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
async def test_safeMint_to_unsupported_contract(erc721_factory):
    erc721, account, _, _, unsupported = erc721_factory

    await assert_revert(signer.send_transaction(
        account, erc721.contract_address, 'safeMint', [
            unsupported.contract_address,
            *TOKEN,
            len(DATA),
            *DATA
        ])
    )


@pytest.mark.asyncio
async def test_safeMint_invalid_uint256(erc721_factory):
    erc721, account, recipient, _, _ = erc721_factory

    await assert_revert(signer.send_transaction(
        account, erc721.contract_address, 'safeMint', [
            recipient.contract_address,
            *INVALID_UINT256,
            len(DATA),
            *DATA
        ]),
        reverted_with="ERC721: token_id is not a valid Uint256"
    )
