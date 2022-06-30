import pytest
from starkware.starknet.testing.starknet import Starknet
from signers import MockSigner
from utils import (
    to_uint, sub_uint, str_to_felt, assert_revert,
    get_contract_class, cached_contract
)



signer = MockSigner(123456789987654321)

USER = 999
INIT_SUPPLY = to_uint(1000)
AMOUNT = to_uint(250)
NAME = str_to_felt('Upgradeable Token')
SYMBOL = str_to_felt('UTKN')
DECIMALS = 18


@pytest.fixture(scope='module')
def contract_classes():
    account_cls = get_contract_class('openzeppelin/account/Account.cairo')
    token_cls = get_contract_class(
        'openzeppelin/token/erc20/ERC20_Upgradeable.cairo')
    proxy_cls = get_contract_class('openzeppelin/upgrades/Proxy.cairo')

    return account_cls, token_cls, proxy_cls


@pytest.fixture(scope='module')
async def token_init(contract_classes):
    account_cls, token_cls, proxy_cls = contract_classes
    starknet = await Starknet.empty()
    account1 = await starknet.deploy(
        contract_class=account_cls,
        constructor_calldata=[signer.public_key]
    )
    account2 = await starknet.deploy(
        contract_class=account_cls,
        constructor_calldata=[signer.public_key]
    )
    token_v1 = await starknet.declare(
        contract_class=token_cls,
    )
    token_v2 = await starknet.declare(
        contract_class=token_cls,
    )
    proxy = await starknet.deploy(
        contract_class=proxy_cls,
        constructor_calldata=[token_v1.class_hash]
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
def token_factory(contract_classes, token_init):
    account_cls, _, proxy_cls = contract_classes
    state, account1, account2, token_v1, token_v2, proxy = token_init
    _state = state.copy()
    account1 = cached_contract(_state, account_cls, account1)
    account2 = cached_contract(_state, account_cls, account2)
    proxy = cached_contract(_state, proxy_cls, proxy)

    return account1, account2, proxy, token_v1, token_v2


@pytest.fixture
async def after_initializer(token_factory):
    admin, other, proxy, token_v1, token_v2 = token_factory

    # initialize
    await signer.send_transaction(
        admin, proxy.contract_address, 'initializer', [
            NAME,                       # name
            SYMBOL,                     # symbol
            DECIMALS,                   # decimals
            *INIT_SUPPLY,               # initial supply
            admin.contract_address,     # recipient
            admin.contract_address      # admin
        ]
    )

    return admin, other, proxy, token_v1, token_v2


@pytest.mark.asyncio
async def test_constructor(token_factory):
    admin, _, proxy, *_ = token_factory

    await signer.send_transaction(
        admin, proxy.contract_address, 'initializer', [
            NAME,                       # name
            SYMBOL,                     # symbol
            DECIMALS,                   # decimals
            *INIT_SUPPLY,               # initial supply
            admin.contract_address,     # recipient
            admin.contract_address      # admin
        ])

    execution_info = await signer.send_transactions(
        admin,
        [
            (proxy.contract_address, 'name', []),
            (proxy.contract_address, 'symbol', []),
            (proxy.contract_address, 'decimals', []),
            (proxy.contract_address, 'totalSupply', [])
        ]
    )

    # check values
    expected = [NAME, SYMBOL, DECIMALS, *INIT_SUPPLY]
    assert execution_info.result.response == expected


@pytest.mark.asyncio
async def test_upgrade(after_initializer):
    admin, _, proxy, _, token_v2 = after_initializer

    # transfer
    await signer.send_transaction(
        admin, proxy.contract_address, 'transfer', [USER, *AMOUNT]
    )

    # upgrade
    await signer.send_transaction(
        admin, proxy.contract_address, 'upgrade', [token_v2.class_hash]
    )

    # fetch values
    execution_info = await signer.send_transactions(
        admin,
        [
            (proxy.contract_address, 'balanceOf', [admin.contract_address]),
            (proxy.contract_address, 'balanceOf', [USER]),
            (proxy.contract_address, 'totalSupply', [])
        ]
    )

    expected = [
        *sub_uint(INIT_SUPPLY, AMOUNT),         # balanceOf admin
        *AMOUNT,                                # balanceOf USER
        *INIT_SUPPLY                            # totalSupply
    ]

    assert execution_info.result.response == expected


@pytest.mark.asyncio
async def test_upgrade_from_nonadmin(after_initializer):
    admin, non_admin, proxy, _, token_v2 = after_initializer

    # should revert
    await assert_revert(signer.send_transaction(
        non_admin, proxy.contract_address, 'upgrade', [token_v2.class_hash]),
        reverted_with="Proxy: caller is not admin"
    )

    # should upgrade from admin
    await signer.send_transaction(
        admin, proxy.contract_address, 'upgrade', [token_v2.class_hash]
    )
