import pytest
from starkware.starknet.testing.starknet import Starknet
from signers import MockSigner
from utils import (
    assert_revert,
    assert_revert_entry_point,
    assert_event_emitted,
    get_contract_class,
    cached_contract
)


# random value
VALUE_1 = 123
VALUE_2 = 987

signer = MockSigner(123456789987654321)


@pytest.fixture(scope='module')
def contract_classes():
    account_cls = get_contract_class('openzeppelin/account/Account.cairo')
    v1_cls = get_contract_class('tests/mocks/upgrades_v1_mock.cairo')
    v2_cls = get_contract_class('tests/mocks/upgrades_v2_mock.cairo')
    proxy_cls = get_contract_class('openzeppelin/upgrades/Proxy.cairo')

    return account_cls, v1_cls, v2_cls, proxy_cls


@pytest.fixture(scope='module')
async def proxy_init(contract_classes):
    account_cls, v1_cls, v2_cls, proxy_cls = contract_classes
    starknet = await Starknet.empty()
    account1 = await starknet.deploy(
        contract_class=account_cls,
        constructor_calldata=[signer.public_key]
    )
    account2 = await starknet.deploy(
        contract_class=account_cls,
        constructor_calldata=[signer.public_key]
    )
    v1_decl = await starknet.declare(
        contract_class=v1_cls,
    )
    v2_decl = await starknet.declare(
        contract_class=v2_cls,
    )
    proxy = await starknet.deploy(
        contract_class=proxy_cls,
        constructor_calldata=[v1_decl.class_hash]
    )
    return (
        starknet.state,
        account1,
        account2,
        v1_decl,
        v2_decl,
        proxy
    )


@pytest.fixture
def proxy_factory(contract_classes, proxy_init):
    account_cls, _, _, proxy_cls = contract_classes
    state, account1, account2, v1_decl, v2_decl, proxy = proxy_init
    _state = state.copy()
    account1 = cached_contract(_state, account_cls, account1)
    account2 = cached_contract(_state, account_cls, account2)
    proxy = cached_contract(_state, proxy_cls, proxy)

    return account1, account2, proxy, v1_decl, v2_decl


@pytest.fixture
async def after_upgrade(proxy_factory):
    admin, other, proxy, v1_decl, v2_decl = proxy_factory

    # initialize, set value, and upgrade to v2
    await signer.send_transactions(
        admin,
        [
            (proxy.contract_address, 'initializer', [admin.contract_address]),
            (proxy.contract_address, 'setValue1', [VALUE_1]),
            (proxy.contract_address, 'upgrade', [v2_decl.class_hash])
        ]
    )

    return admin, other, proxy, v1_decl, v2_decl


@pytest.mark.asyncio
async def test_initializer(proxy_factory):
    admin, _, proxy, *_ = proxy_factory

    await signer.send_transaction(
        admin, proxy.contract_address, 'initializer', [
            admin.contract_address
        ]
    )


@pytest.mark.asyncio
async def test_initializer_already_initialized(proxy_factory):
    admin, _, proxy, *_ = proxy_factory

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
    admin, _, proxy, _, v2_decl = proxy_factory

    # initialize and set value
    await signer.send_transactions(
        admin,
        [
            (proxy.contract_address, 'initializer', [admin.contract_address]),
            (proxy.contract_address, 'setValue1', [VALUE_1]),
        ]
    )

    # check value
    execution_info = await signer.send_transaction(
        admin, proxy.contract_address, 'getValue1', []
    )
    assert execution_info.result.response == [VALUE_1]

    # upgrade
    await signer.send_transaction(
        admin, proxy.contract_address, 'upgrade', [
            v2_decl.class_hash
        ]
    )

    # check value
    execution_info = await signer.send_transaction(
        admin, proxy.contract_address, 'getValue1', []
    )
    assert execution_info.result.response == [VALUE_1]


@pytest.mark.asyncio
async def test_upgrade_event(proxy_factory):
    admin, _, proxy, _, v2_decl = proxy_factory

    # initialize implementation
    await signer.send_transaction(
        admin, proxy.contract_address, 'initializer', [
            admin.contract_address
        ]
    )

    # upgrade
    tx_exec_info = await signer.send_transaction(
        admin, proxy.contract_address, 'upgrade', [
            v2_decl.class_hash
        ]
    )

    # check event
    assert_event_emitted(
        tx_exec_info,
        from_address=proxy.contract_address,
        name='Upgraded',
        data=[
            v2_decl.class_hash          # new class hash
        ]
    )


@pytest.mark.asyncio
async def test_upgrade_from_non_admin(proxy_factory):
    admin, non_admin, proxy, _, v2_decl = proxy_factory

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
                v2_decl.class_hash
            ]
        ),
        reverted_with="Proxy: caller is not admin"
    )


@pytest.mark.asyncio
async def test_implementation_v2(after_upgrade):
    admin, _, proxy, _, v2_decl = after_upgrade

    execution_info = await signer.send_transactions(
        admin,
        [
            (proxy.contract_address, 'getImplementationHash', []),
            (proxy.contract_address, 'getAdmin', []),
            (proxy.contract_address, 'getValue1', [])
        ]
    )

    expected = [
        v2_decl.class_hash,             # getImplementationHash
        admin.contract_address,         # getAdmin
        VALUE_1                         # getValue1
    ]

    assert execution_info.result.response == expected

#
# v2 functions
#

@pytest.mark.asyncio
async def test_set_admin(after_upgrade):
    admin, new_admin, proxy, *_ = after_upgrade

    # change admin
    await signer.send_transaction(
        admin, proxy.contract_address, 'setAdmin', [
            new_admin.contract_address
        ]
    )

    # check admin
    execution_info = await signer.send_transaction(
        admin, proxy.contract_address, 'getAdmin', []
    )
    assert execution_info.result.response == [new_admin.contract_address]


@pytest.mark.asyncio
async def test_set_admin_from_non_admin(after_upgrade):
    _, non_admin, proxy, *_ = after_upgrade

    # should revert
    await assert_revert(signer.send_transaction(
        non_admin, proxy.contract_address, 'setAdmin', [non_admin.contract_address]),
        reverted_with="Proxy: caller is not admin"
    )


@pytest.mark.asyncio
async def test_v2_functions_pre_and_post_upgrade(proxy_factory):
    admin, new_admin, proxy, _, v2_decl = proxy_factory

    # initialize
    await signer.send_transaction(
        admin, proxy.contract_address, 'initializer', [
            admin.contract_address
        ]
    )

    # check getValue2 doesn't exist
    await assert_revert_entry_point(
        signer.send_transaction(
            admin, proxy.contract_address, 'getValue2', []
        ), 
        invalid_selector='getValue2'
    )

    # check setValue2 doesn't exist in v1
    await assert_revert_entry_point(
        signer.send_transaction(
            admin, proxy.contract_address, 'setValue2', [VALUE_2]
        ),
        invalid_selector='setValue2'
    )

    # check getAdmin doesn't exist in v1
    await assert_revert_entry_point(
        signer.send_transaction(
            admin, proxy.contract_address, 'getAdmin', []
        ),
        invalid_selector='getAdmin'
    )

    # check setAdmin doesn't exist in v1
    await assert_revert_entry_point(
        signer.send_transaction(
            admin, proxy.contract_address, 'setAdmin', [new_admin.contract_address]
        ),
        invalid_selector='setAdmin'
    )

    # upgrade
    await signer.send_transaction(
        admin, proxy.contract_address, 'upgrade', [
            v2_decl.class_hash
        ]
    )

    # set value 2 and admin
    await signer.send_transactions(
        admin,
        [
            (proxy.contract_address, 'setValue2', [VALUE_2]),
            (proxy.contract_address, 'setAdmin', [new_admin.contract_address])
        ]
    )

    # check value 2 and admin
    execution_info = await signer.send_transactions(
        admin,
        [
            (proxy.contract_address, 'getValue2', []),
            (proxy.contract_address, 'getAdmin', [])
        ]
    )

    expected = [
        VALUE_2,                        # getValue2
        new_admin.contract_address      # getAdmin
    ]
    assert execution_info.result.response == expected
