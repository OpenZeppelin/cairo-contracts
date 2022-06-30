import pytest
from starkware.starknet.testing.starknet import Starknet
from signers import MockSigner
from utils import get_contract_class, cached_contract


signer = MockSigner(123456789987654321)
L1_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984
ANOTHER_ADDRESS = 0xd9e1ce17f2641f24ae83637ab66a2cca9c378b9f


@pytest.fixture(scope='module')
async def registry_factory():
    # contract classes
    registry_cls = get_contract_class("openzeppelin/account/AddressRegistry.cairo")
    account_cls = get_contract_class('openzeppelin/account/Account.cairo')

    # deployments
    starknet = await Starknet.empty()
    account = await starknet.deploy(
        contract_class=account_cls,
        constructor_calldata=[signer.public_key]
    )
    registry = await starknet.deploy(
        contract_class=registry_cls,
        constructor_calldata=[]
    )

    # cache contracts
    state = starknet.state.copy()
    account = cached_contract(state, account_cls, account)
    registry = cached_contract(state, registry_cls, registry)

    return account, registry


@pytest.mark.asyncio
async def test_set_address(registry_factory):
    account, registry = registry_factory

    await signer.send_transaction(
        account, registry.contract_address, 'set_L1_address', [L1_ADDRESS]
    )
    execution_info = await registry.get_L1_address(account.contract_address).call()
    assert execution_info.result == (L1_ADDRESS,)


@pytest.mark.asyncio
async def test_update_address(registry_factory):
    account, registry = registry_factory

    await signer.send_transaction(
        account, registry.contract_address, 'set_L1_address', [L1_ADDRESS]
    )
    execution_info = await registry.get_L1_address(account.contract_address).call()
    assert execution_info.result == (L1_ADDRESS,)

    # set new address
    await signer.send_transaction(
        account, registry.contract_address, 'set_L1_address', [ANOTHER_ADDRESS]
    )
    execution_info = await registry.get_L1_address(account.contract_address).call()
    assert execution_info.result == (ANOTHER_ADDRESS,)
