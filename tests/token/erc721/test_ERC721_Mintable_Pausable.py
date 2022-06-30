import pytest
from starkware.starknet.testing.starknet import Starknet
from signers import MockSigner
from utils import (
    str_to_felt, TRUE, FALSE, get_contract_class, cached_contract, 
    assert_revert, to_uint
)


signer = MockSigner(123456789987654321)

# random token IDs
TOKENS = [to_uint(5042), to_uint(793)]
TOKEN_TO_MINT = to_uint(33)
# random data (mimicking bytes in Solidity)
DATA = [0x42, 0x89, 0x55]


@pytest.fixture(scope='module')
def contract_classes():
    account_cls = get_contract_class('openzeppelin/account/Account.cairo')
    erc721_cls = get_contract_class(
        'openzeppelin/token/erc721/ERC721_Mintable_Pausable.cairo')
    erc721_holder_cls = get_contract_class(
        'openzeppelin/token/erc721/utils/ERC721_Holder.cairo')

    return account_cls, erc721_cls, erc721_holder_cls


@pytest.fixture(scope='module')
async def erc721_init(contract_classes):
    account_cls, erc721_cls, erc721_holder_cls = contract_classes
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
    return (
        starknet.state,
        account1,
        account2,
        erc721,
        erc721_holder
    )


@pytest.fixture
def erc721_factory(contract_classes, erc721_init):
    account_cls, erc721_cls, erc721_holder_cls = contract_classes
    state, account1, account2, erc721, erc721_holder = erc721_init
    _state = state.copy()
    account1 = cached_contract(_state, account_cls, account1)
    account2 = cached_contract(_state, account_cls, account2)
    erc721 = cached_contract(_state, erc721_cls, erc721)
    erc721_holder = cached_contract(_state, erc721_holder_cls, erc721_holder)

    return erc721, account1, account2, erc721_holder


@pytest.fixture
async def erc721_minted(erc721_factory):
    erc721, account, account2, erc721_holder = erc721_factory
    # mint tokens to account
    for token in TOKENS:
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                account.contract_address, *token]
        )

    return erc721, account, account2, erc721_holder


@pytest.mark.asyncio
async def test_pause(erc721_minted):
    erc721, owner, other, erc721_holder = erc721_minted

    # pause
    await signer.send_transaction(owner, erc721.contract_address, 'pause', [])

    execution_info = await erc721.paused().invoke()
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
async def test_unpause(erc721_minted):
    erc721, owner, other, erc721_holder = erc721_minted

    # pause
    await signer.send_transaction(owner, erc721.contract_address, 'pause', [])

    # unpause
    await signer.send_transaction(owner, erc721.contract_address, 'unpause', [])

    execution_info = await erc721.paused().invoke()
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
async def test_only_owner(erc721_minted):
    erc721, owner, other, _ = erc721_minted

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
