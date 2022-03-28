import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils import Signer, contract_path

signer = Signer(123456789987654321)


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
async def ownable_factory():
    starknet = await Starknet.empty()
    account1 = await starknet.deploy(
        contract_path("openzeppelin/account/Account.cairo"),
        constructor_calldata=[signer.public_key]
    )

    account2 = await starknet.deploy(
        contract_path("openzeppelin/account/Account.cairo"),
        constructor_calldata=[signer.public_key]
    )

    ownable = await starknet.deploy(
        contract_path("tests/mocks/Ownable.cairo"),
        constructor_calldata=[account1.contract_address]
    )
    return starknet, ownable, account1, account2


@pytest.mark.asyncio
async def test_constructor(ownable_factory):
    _, ownable, account1, _ = ownable_factory
    expected = await ownable.get_owner().call()
    assert expected.result.owner == account1.contract_address


@pytest.mark.asyncio
async def test_transfer_ownership(ownable_factory):
    _, ownable, account1, account2 = ownable_factory
    await signer.send_transaction(account1, ownable.contract_address, 'transfer_ownership', [account2.contract_address])
    executed_info = await ownable.get_owner().call()
    assert executed_info.result == (account2.contract_address,)


@pytest.mark.asyncio
async def test_renounce_ownership(ownable_factory):
    _, ownable, account1, account2 = ownable_factory
    await signer.send_transaction(account2, ownable.contract_address, 'renounce_ownership', [])
    executed_info = await ownable.get_owner().call()
    assert executed_info.result == (0,)
