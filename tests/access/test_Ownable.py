import pytest
from starkware.starknet.testing.starknet import Starknet
from utils import Signer, contract_path


signer = Signer(123456789987654321)


@pytest.fixture(scope='module')
async def ownable_factory():
    starknet = await Starknet.empty()
    owner = await starknet.deploy(
        contract_path("openzeppelin/account/Account.cairo"),
        constructor_calldata=[signer.public_key]
    )

    ownable = await starknet.deploy(
        contract_path("tests/mocks/Ownable.cairo"),
        constructor_calldata=[owner.contract_address]
    )
    return starknet, ownable, owner


@pytest.mark.asyncio
async def test_constructor(ownable_factory):
    _, ownable, owner = ownable_factory
    expected = await ownable.get_owner().call()
    assert expected.result.owner == owner.contract_address


@pytest.mark.asyncio
async def test_transfer_ownership(ownable_factory):
    _, ownable, owner = ownable_factory
    new_owner = 123
    await signer.send_transaction(owner, ownable.contract_address, 'transfer_ownership', [new_owner])
    executed_info = await ownable.get_owner().call()
    assert executed_info.result == (new_owner,)
