import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils import (
    Signer, to_uint, sub_uint, str_to_felt, assert_revert,
    get_contract_def, cached_contract, assert_event_emitted
)

signer = Signer(123456789987654321)

USER = 999
INIT_SUPPLY = to_uint(1000)
AMOUNT = to_uint(250)
NAME = str_to_felt('Upgradeable Token')
SYMBOL = str_to_felt('UTKN')
DECIMALS = 18


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


# random value
VALUE = 123
VALUE_2 = 987


signer = Signer(123456789987654321)


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
def contract_defs():
    account_def = get_contract_def('openzeppelin/account/Account.cairo')
    token_def = get_contract_def(
        'openzeppelin/token/erc20/ERC20_Upgradeable.cairo')
    proxy_def = get_contract_def('openzeppelin/upgrades/Proxy.cairo')

    return account_def, token_def, proxy_def


@pytest.fixture(scope='module')
async def token_init(contract_defs):
    account_def, token_def, proxy_def = contract_defs
    starknet = await Starknet.empty()
    account1 = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )
    account2 = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )
    token_v1 = await starknet.deploy(
        contract_def=token_def,
        constructor_calldata=[]
    )
    token_v2 = await starknet.deploy(
        contract_def=token_def,
        constructor_calldata=[]
    )
    proxy = await starknet.deploy(
        contract_def=proxy_def,
        constructor_calldata=[token_v1.contract_address]
    )
    return (
        starknet.state,
        account1,
        account2,
        token_v1,
        token_v2,
        proxy
    )


@pytest.fixture
def token_factory(contract_defs, token_init):
    account_def, token_def, proxy_def = contract_defs
    state, account1, account2, token_v1, token_v2, proxy = token_init
    _state = state.copy()
    account1 = cached_contract(_state, account_def, account1)
    account2 = cached_contract(_state, account_def, account2)
    token_v1 = cached_contract(_state, token_def, token_v1)
    token_v2 = cached_contract(_state, token_def, token_v2)
    proxy = cached_contract(_state, proxy_def, proxy)

    return account1, account2, token_v1, token_v2, proxy


@pytest.fixture
async def after_initializer(token_factory):
    admin, other, token_v1, token_v2, proxy = token_factory

    # initialize
    await signer.send_transaction(
        admin, proxy.contract_address, 'initializer', [
            NAME,
            SYMBOL,
            DECIMALS,
            *INIT_SUPPLY,
            admin.contract_address,
            admin.contract_address
        ]
    )

    return admin, other, token_v1, token_v2, proxy


@pytest.mark.asyncio
async def test_constructor(token_factory):
    admin, _, _, _, proxy = token_factory

    await signer.send_transaction(
        admin, proxy.contract_address, 'initializer', [
            NAME,
            SYMBOL,
            DECIMALS,
            *INIT_SUPPLY,
            admin.contract_address,
            admin.contract_address
        ])

    # check name
    execution_info = await signer.send_transaction(
        admin, proxy.contract_address, 'name', [])
    assert execution_info.result.response == [NAME]

    # check symbol
    execution_info = await signer.send_transaction(
        admin, proxy.contract_address, 'symbol', []
    )
    assert execution_info.result.response == [SYMBOL]

    # check decimals
    execution_info = await signer.send_transaction(
        admin, proxy.contract_address, 'decimals', []
    )
    assert execution_info.result.response == [DECIMALS]

    # check total supply
    execution_info = await signer.send_transaction(
        admin, proxy.contract_address, 'totalSupply', []
    )
    assert execution_info.result.response == [*INIT_SUPPLY]


@pytest.mark.asyncio
async def test_upgrade(after_initializer):
    admin, _, _, token_v2, proxy = after_initializer

    # transfer
    await signer.send_transaction(
        admin, proxy.contract_address, 'transfer', [
            USER,
            *AMOUNT
        ]
    )

    # upgrade
    await signer.send_transaction(
        admin, proxy.contract_address, 'upgrade', [
            token_v2.contract_address
        ]
    )

    # check admin balance
    execution_info = await signer.send_transaction(
        admin, proxy.contract_address, 'balanceOf', [
            admin.contract_address
        ]
    )
    assert execution_info.result.response == [*sub_uint(INIT_SUPPLY, AMOUNT)]

    # check USER balance
    execution_info = await signer.send_transaction(
        admin, proxy.contract_address, 'balanceOf', [
            USER
        ]
    )
    assert execution_info.result.response == [*AMOUNT]

    # check total supply
    execution_info = await signer.send_transaction(
        admin, proxy.contract_address, 'totalSupply', []
    )
    assert execution_info.result.response == [*INIT_SUPPLY]


@pytest.mark.asyncio
async def test_upgrade_from_nonadmin(after_initializer):
    admin, non_admin, _, token_v2, proxy = after_initializer

    # should revert
    await assert_revert(
        signer.send_transaction(
            non_admin, proxy.contract_address, 'upgrade', [
                token_v2.contract_address
            ]
        )
    )

    # should upgrade from admin
    await signer.send_transaction(
        admin, proxy.contract_address, 'upgrade', [
            token_v2.contract_address
        ]
    )
