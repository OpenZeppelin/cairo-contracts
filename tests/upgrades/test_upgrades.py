import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils import (
    Signer, assert_revert, assert_event_emitted, get_contract_def, cached_contract
)

# random value
VALUE_1 = 123
VALUE_2 = 987


signer = Signer(123456789987654321)


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
def contract_defs():
    account_def = get_contract_def('openzeppelin/account/Account.cairo')
    v1_def = get_contract_def('tests/mocks/upgrades_v1_mock.cairo')
    v2_def = get_contract_def('tests/mocks/upgrades_v2_mock.cairo')
    proxy_def = get_contract_def('openzeppelin/upgrades/Proxy.cairo')

    return account_def, v1_def, v2_def, proxy_def


@pytest.fixture(scope='module')
async def proxy_init(contract_defs):
    account_def, dummy_v1_def, dummy_v2_def, proxy_def = contract_defs
    starknet = await Starknet.empty()
    account1 = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )
    account2 = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )
    v1 = await starknet.deploy(
        contract_def=dummy_v1_def,
        constructor_calldata=[]
    )
    v2 = await starknet.deploy(
        contract_def=dummy_v2_def,
        constructor_calldata=[]
    )
    proxy = await starknet.deploy(
        contract_def=proxy_def,
        constructor_calldata=[v1.contract_address]
    )
    return (
        starknet.state,
        account1,
        account2,
        v1,
        v2,
        proxy
    )


@pytest.fixture
def proxy_factory(contract_defs, proxy_init):
    account_def, dummy_v1_def, dummy_v2_def, proxy_def = contract_defs
    state, account1, account2, v1, v2, proxy = proxy_init
    _state = state.copy()
    account1 = cached_contract(_state, account_def, account1)
    account2 = cached_contract(_state, account_def, account2)
    v1 = cached_contract(_state, dummy_v1_def, v1)
    v2 = cached_contract(_state, dummy_v2_def, v2)
    proxy = cached_contract(_state, proxy_def, proxy)

    return account1, account2, v1, v2, proxy


@pytest.fixture
async def after_upgrade(proxy_factory):
    admin, other, v1, v2, proxy = proxy_factory

    # initialize
    await signer.send_transaction(
        admin, proxy.contract_address, 'initializer', [
            admin.contract_address
        ]
    )

    # set value
    await signer.send_transaction(
        admin, proxy.contract_address, 'set_value_1', [
            VALUE_1
        ]
    )

    # upgrade
    await signer.send_transaction(
        admin, proxy.contract_address, 'upgrade', [
            v2.contract_address
        ]
    )

    return admin, other, v1, v2, proxy


@pytest.mark.asyncio
async def test_initializer(proxy_factory):
    admin, _, _, _, proxy = proxy_factory

    await signer.send_transaction(
        admin, proxy.contract_address, 'initializer', [
            admin.contract_address
        ]
    )


@pytest.mark.asyncio
async def test_initializer_already_initialized(proxy_factory):
    admin, _, _, _, proxy = proxy_factory

    await signer.send_transaction(
        admin, proxy.contract_address, 'initializer', [
            admin.contract_address
        ]
    )

    await assert_revert(
        signer.send_transaction(
            admin, proxy.contract_address, 'initializer', [
                admin.contract_address
            ]
        ),
        reverted_with='Proxy: contract already initialized'
    )


@pytest.mark.asyncio
async def test_upgrade(proxy_factory):
    admin, _, _, v2, proxy = proxy_factory

    # initialize implementation
    await signer.send_transaction(
        admin, proxy.contract_address, 'initializer', [
            admin.contract_address
        ]
    )

    # set value
    await signer.send_transaction(
        admin, proxy.contract_address, 'set_value_1', [
            VALUE_1
        ]
    )

    # check value
    execution_info = await signer.send_transaction(
        admin, proxy.contract_address, 'get_value_1', []
    )
    assert execution_info.result.response == [VALUE_1, ]

    # upgrade
    await signer.send_transaction(
        admin, proxy.contract_address, 'upgrade', [
            v2.contract_address
        ]
    )

    # check value
    execution_info = await signer.send_transaction(
        admin, proxy.contract_address, 'get_value_1', []
    )
    assert execution_info.result.response == [VALUE_1, ]


@pytest.mark.asyncio
async def test_upgrade_event(proxy_factory):
    admin, _, _, v2, proxy = proxy_factory

    # initialize implementation
    await signer.send_transaction(
        admin, proxy.contract_address, 'initializer', [
            admin.contract_address
        ]
    )

    # upgrade
    tx_exec_info = await signer.send_transaction(
        admin, proxy.contract_address, 'upgrade', [
            v2.contract_address
        ]
    )

    # check event
    assert_event_emitted(
        tx_exec_info,
        from_address=proxy.contract_address,
        name='Upgraded',
        data=[
            v2.contract_address
        ]
    )


@pytest.mark.asyncio
async def test_upgrade_from_non_admin(proxy_factory):
    admin, non_admin, _, v2, proxy = proxy_factory

    # initialize implementation
    await signer.send_transaction(
        admin, proxy.contract_address, 'initializer', [
            admin.contract_address
        ]
    )

    # upgrade should revert
    await assert_revert(
        signer.send_transaction(
            non_admin, proxy.contract_address, 'upgrade', [
                v2.contract_address
            ]
        ),
        reverted_with="Proxy: caller is not admin"
    )


# Using `after_upgrade` fixture henceforth
@pytest.mark.asyncio
async def test_implementation_v2(after_upgrade):
    admin, _, _, v2, proxy = after_upgrade

    # check implementation address
    execution_info = await signer.send_transaction(
        admin, proxy.contract_address, 'get_implementation', []
    )
    assert execution_info.result.response == [v2.contract_address]

    # check admin
    execution_info = await signer.send_transaction(
        admin, proxy.contract_address, 'get_admin', []
    )
    assert execution_info.result.response == [admin.contract_address]

    # check value
    execution_info = await signer.send_transaction(
        admin, proxy.contract_address, 'get_value_1', []
    )
    assert execution_info.result.response == [VALUE_1, ]


@pytest.mark.asyncio
async def test_set_admin(after_upgrade):
    admin, new_admin, _, _, proxy = after_upgrade

    # change admin
    await signer.send_transaction(
        admin, proxy.contract_address, 'set_admin', [
            new_admin.contract_address
        ]
    )

    # check admin
    execution_info = await signer.send_transaction(
        admin, proxy.contract_address, 'get_admin', []
    )
    assert execution_info.result.response == [new_admin.contract_address]


@pytest.mark.asyncio
async def test_set_admin_from_non_admin(after_upgrade):
    _, non_admin, _, _, proxy = after_upgrade

    # change admin should revert
    await assert_revert(
        signer.send_transaction(
            non_admin, proxy.contract_address, 'set_admin', [
                non_admin.contract_address
            ]
        )
    )
