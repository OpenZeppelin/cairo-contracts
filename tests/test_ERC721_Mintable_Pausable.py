import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils import Signer, str_to_felt, assert_revert


signer = Signer(123456789987654321)

# bools (for readability)
false = 0
true = 1

# random uint256 tokenIDs
first_token_id = (5042, 0)
second_token_id = (7921, 1)
third_token_id = (0, 13)

# random data (mimicking bytes in Solidity)
data = [0x42, 0x89, 0x55]


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='function')
async def erc721_factory():
    starknet = await Starknet.empty()
    owner = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

    other = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

    erc721 = await starknet.deploy(
        "contracts/token/ERC721_Mintable_Pausable.cairo",
        constructor_calldata=[
            str_to_felt("Non Fungible Token"),  # name
            str_to_felt("NFT"),                 # ticker
            owner.contract_address              # owner
        ]
    )

    erc721_holder = await starknet.deploy("contracts/token/utils/ERC721_Holder.cairo")

    # mint tokens to owner
    tokens = [first_token_id, second_token_id]
    for token in tokens:
        await signer.send_transaction(
            owner, erc721.contract_address, 'mint', [
                owner.contract_address, *token]
        )

    return starknet, erc721, owner, other, erc721_holder


@pytest.mark.asyncio
async def test_pause(erc721_factory):
    _, erc721, owner, other, erc721_holder = erc721_factory

    # pause
    await signer.send_transaction(owner, erc721.contract_address, 'pause', [])

    execution_info = await erc721.paused().call()
    assert execution_info.result.paused == 1

    await assert_revert(signer.send_transaction(
        owner, erc721.contract_address, 'approve', [
            other.contract_address,
            *first_token_id
        ])
    )

    await assert_revert(signer.send_transaction(
        owner, erc721.contract_address, 'setApprovalForAll', [
            other.contract_address,
            true
        ])
    )

    await assert_revert(signer.send_transaction(
        owner, erc721.contract_address, 'transferFrom', [
            owner.contract_address,
            other.contract_address,
            *first_token_id
        ])
    )

    await assert_revert(signer.send_transaction(
        owner, erc721.contract_address, 'safeTransferFrom', [
            owner.contract_address,
            erc721_holder.contract_address,
            *first_token_id,
            len(data),
            *data
        ])
    )

    await assert_revert(signer.send_transaction(
        owner, erc721.contract_address, 'mint', [
            other.contract_address,
            *third_token_id
        ])
    )


@pytest.mark.asyncio
async def test_unpause(erc721_factory):
    _, erc721, owner, other, erc721_holder = erc721_factory

    # pause
    await signer.send_transaction(owner, erc721.contract_address, 'pause', [])

    # unpause
    await signer.send_transaction(owner, erc721.contract_address, 'unpause', [])

    execution_info = await erc721.paused().call()
    assert execution_info.result.paused == 0

    await signer.send_transaction(
        owner, erc721.contract_address, 'approve', [
            other.contract_address,
            *first_token_id
        ]
    )

    await signer.send_transaction(
        owner, erc721.contract_address, 'setApprovalForAll', [
            other.contract_address,
            true
        ]
    )

    await signer.send_transaction(
        owner, erc721.contract_address, 'transferFrom', [
            owner.contract_address,
            other.contract_address,
            *first_token_id
        ]
    )

    await signer.send_transaction(
        other, erc721.contract_address, 'safeTransferFrom', [
            owner.contract_address,
            erc721_holder.contract_address,
            *second_token_id,
            len(data),
            *data
        ]
    )

    await signer.send_transaction(
        owner, erc721.contract_address, 'mint', [
            other.contract_address,
            *third_token_id
        ]
    )


@pytest.mark.asyncio
async def test_only_owner(erc721_factory):
    _, erc721, owner, other, _ = erc721_factory

    # not-owner pause should revert
    await assert_revert(signer.send_transaction(
        other, erc721.contract_address, 'pause', []))

    # owner pause
    await signer.send_transaction(owner, erc721.contract_address, 'pause', [])

    # not-owner unpause should revert
    await assert_revert(signer.send_transaction(
        other, erc721.contract_address, 'unpause', []))

    # owner unpause
    await signer.send_transaction(owner, erc721.contract_address, 'unpause', [])
