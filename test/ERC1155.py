import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils.Signer import Signer

signer = Signer(123456789987654321)


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
async def erc1155_factory():
    starknet = await Starknet.empty()
    account = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

    await account.initialize(account.contract_address).invoke()

    erc1155 = await starknet.deploy(
        "contracts/token/ERC1155.cairo",
        constructor_calldata=[account.contract_address, 2, 1, 2, 2, 1000, 500] # token_id: token_no => 1 : 1000 / 2 : 500
    )
    return starknet, erc1155, account

@pytest.mark.asyncio
async def test_constructor(erc1155_factory):
    _, erc1155, account = erc1155_factory

    execution_info = await erc1155.get_total_supply(1).call()
    assert execution_info.result == (1000,)
    execution_info = await erc1155.get_total_supply(2).call()
    assert execution_info.result == (500,)

    execution_info = await erc1155.balance_of(account.contract_address, 1).call()
    assert execution_info.result == (1000,)
    execution_info = await erc1155.balance_of(account.contract_address, 2).call()
    assert execution_info.result == (500,)