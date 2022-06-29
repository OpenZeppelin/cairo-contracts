import pytest
from starkware.starknet.testing.starknet import Starknet
from signers import MockSigner
from utils import (
    assert_revert,
    get_contract_class,
    cached_contract,
    assert_event_emitted,
    assert_revert_entry_point
)

# random value
VALUE = 123

signer = MockSigner(123456789987654321)


@pytest.fixture(scope='module')
def contract_classes():
    account_cls = get_contract_class('openzeppelin/account/Account.cairo')
    implementation_cls = get_contract_class(
        'tests/mocks/proxiable_implementation.cairo'
    )
    proxy_cls = get_contract_class('openzeppelin/upgrades/Proxy.cairo')

    return account_cls, implementation_cls, proxy_cls


@pytest.fixture(scope='module')
async def proxy_init(contract_classes):
    account_cls, implementation_cls, proxy_cls = contract_classes
    starknet = await Starknet.empty()
    account1 = await starknet.deploy(
        contract_class=account_cls,
        constructor_calldata=[signer.public_key]
    )
    account2 = await starknet.deploy(
        contract_class=account_cls,
        constructor_calldata=[signer.public_key]
    )
    implementation_decl = await starknet.declare(
        contract_class=implementation_cls
    )
    proxy = await starknet.deploy(
        contract_class=proxy_cls,
        constructor_calldata=[implementation_decl.class_hash]
    )
    return (
        starknet.state,
        account1,
        account2,
        proxy
    )


@pytest.fixture
def proxy_factory(contract_classes, proxy_init):
    account_cls, _, proxy_cls = contract_classes
    state, account1, account2, proxy = proxy_init
    _state = state.copy()
    admin = cached_contract(_state, account_cls, account1)
    other = cached_contract(_state, account_cls, account2)
    proxy = cached_contract(_state, proxy_cls, proxy)

    return admin, other, proxy


@pytest.fixture
async def after_initialized(proxy_factory):
    admin, other, proxy = proxy_factory 

    # initialize proxy
    await signer.send_transaction(
        admin, proxy.contract_address, 'initializer', [admin.contract_address]
    )

    return admin, other, proxy

#
# initializer
#

@pytest.mark.asyncio
async def test_initializer(proxy_factory):
    admin, _, proxy = proxy_factory 

    await signer.send_transaction(
        admin, proxy.contract_address, 'initializer', [admin.contract_address]
    )

    # check admin is set
    execution_info = await signer.send_transaction(
        admin, proxy.contract_address, 'getAdmin', []
    )
    assert execution_info.result.response == [admin.contract_address]


@pytest.mark.asyncio
async def test_initializer_after_initialized(after_initialized):
    admin, _, proxy = after_initialized 

    await assert_revert(signer.send_transaction(
        admin, proxy.contract_address, 'initializer', [admin.contract_address]),
        reverted_with="Proxy: contract already initialized"
    )

#
# set_admin
#

@pytest.mark.asyncio
async def test_set_admin(after_initialized):
    admin, _, proxy = after_initialized 

    # set admin
    tx_exec_info = await signer.send_transaction(
        admin, proxy.contract_address, 'setAdmin', [VALUE]
    )

    # check event
    assert_event_emitted(
        tx_exec_info,
        from_address=proxy.contract_address,
        name='AdminChanged',
        data=[
            admin.contract_address,       # old admin
            VALUE                         # new admin
        ]
    )

    # check new admin
    execution_info = await signer.send_transaction(
        admin, proxy.contract_address, 'getAdmin', []
    )
    assert execution_info.result.response == [VALUE]


@pytest.mark.asyncio
async def test_set_admin_from_unauthorized(after_initialized):
    _, non_admin, proxy = after_initialized 

    # set admin
    await assert_revert(signer.send_transaction(
        non_admin, proxy.contract_address, 'setAdmin', [VALUE]),
        reverted_with="Proxy: caller is not admin"
    )

#
# fallback function
#

@pytest.mark.asyncio
async def test_default_fallback(proxy_factory):
    admin, _, proxy = proxy_factory 

    # set value through proxy
    await signer.send_transaction(
        admin, proxy.contract_address, 'setValue', [VALUE]
    )

    # get value through proxy
    execution_info = execution_info = await signer.send_transaction(
        admin, proxy.contract_address, 'getValue', []
    )
    assert execution_info.result.response == [VALUE]


@pytest.mark.asyncio
async def test_fallback_when_selector_does_not_exist(proxy_factory):
    admin, _, proxy = proxy_factory 

    # should fail with entry point error
    await assert_revert_entry_point(
        signer.send_transaction(
            admin, proxy.contract_address, 'invalid_selector', []
        ),
        invalid_selector='invalid_selector'
    )
