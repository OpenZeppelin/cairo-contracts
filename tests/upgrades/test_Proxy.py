import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils import (
    Signer, assert_revert, get_contract_def, cached_contract
)

# random value
VALUE = 123

signer = Signer(123456789987654321)


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
def contract_defs():
    account_def = get_contract_def('openzeppelin/account/Account.cairo')
    implementation_def = get_contract_def(
        'tests/mocks/proxiable_implementation.cairo'
    )
    proxy_def = get_contract_def('openzeppelin/upgrades/Proxy.cairo')

    return account_def, implementation_def, proxy_def


@pytest.fixture(scope='module')
async def proxy_init(contract_defs):
    account_def, implementation_def, proxy_def = contract_defs
    starknet = await Starknet.empty()
    account = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )
    implementation = await starknet.deploy(
        contract_def=implementation_def,
        constructor_calldata=[]
    )
    proxy = await starknet.deploy(
        contract_def=proxy_def,
        constructor_calldata=[implementation.contract_address]
    )
    return (
        starknet.state,
        account,
        implementation,
        proxy
    )


@pytest.fixture
def proxy_factory(contract_defs, proxy_init):
    account_def, implementation_def, proxy_def = contract_defs
    state, account, implementation, proxy = proxy_init
    _state = state.copy()
    account = cached_contract(_state, account_def, account)
    implementation = cached_contract(
        _state,
        implementation_def,
        implementation
    )
    proxy = cached_contract(_state, proxy_def, proxy)

    return account, implementation, proxy


@pytest.mark.asyncio
async def test_constructor_sets_correct_implementation(proxy_factory):
    account, implementation, proxy = proxy_factory

    execution_info = await signer.send_transaction(
        account, proxy.contract_address, 'get_implementation', []
    )
    assert execution_info.result.response == [implementation.contract_address]


@pytest.mark.asyncio
async def test_initializer(proxy_factory):
    account, _, proxy = proxy_factory

    await signer.send_transaction(
        account, proxy.contract_address, 'initializer', [
            account.contract_address]
    )


@pytest.mark.asyncio
async def test_default_fallback(proxy_factory):
    account, _, proxy = proxy_factory

    # set value through proxy
    await signer.send_transaction(
        account, proxy.contract_address, 'set_value', [VALUE]
    )

    # get value through proxy
    execution_info = execution_info = await signer.send_transaction(
        account, proxy.contract_address, 'get_value', []
    )
    assert execution_info.result.response == [VALUE]


@pytest.mark.asyncio
async def test_fallback_when_selector_does_not_exist(proxy_factory):
    account, _, proxy = proxy_factory

    await assert_revert(
        signer.send_transaction(
            account, proxy.contract_address, 'bad_selector', []
        )
    )
