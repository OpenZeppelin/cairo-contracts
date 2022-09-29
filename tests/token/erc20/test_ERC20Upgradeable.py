import pytest
from signers import MockSigner
from utils import (
    to_uint, sub_uint, str_to_felt, assert_revert, TRUE,
    get_contract_class, cached_contract, State, Account,
    get_selector_from_name
)


signer = MockSigner(123456789987654321)

USER = 999
INIT_SUPPLY = to_uint(1000)
AMOUNT = to_uint(250)
NAME = str_to_felt('Upgradeable Token')
SYMBOL = str_to_felt('UTKN')
DECIMALS = 18


class TestERC20Upgradeable:
    @pytest.fixture(scope='module')
    def contract_classes(self):
        account_cls = Account.get_class
        token_cls = get_contract_class('ERC20Upgradeable')
        proxy_cls = get_contract_class('Proxy')

        return account_cls, token_cls, proxy_cls


    @pytest.fixture(scope='module')
    async def token_init(self, contract_classes):
        account_cls, token_cls, proxy_cls = contract_classes
        starknet = await State.init()
        account1 = await Account.deploy(signer.public_key)
        account2 = await Account.deploy(signer.public_key)
        token_v1 = await starknet.declare(
            contract_class=token_cls,
        )
        token_v2 = await starknet.declare(
            contract_class=token_cls,
        )
        selector = get_selector_from_name('initializer')
        params = [
            NAME,                       # name
            SYMBOL,                     # symbol
            DECIMALS,                   # decimals
            *INIT_SUPPLY,               # initial supply
            account1.contract_address,  # recipient
            account1.contract_address   # admin
        ]
        proxy = await starknet.deploy(
            contract_class=proxy_cls,
            constructor_calldata=[
                token_v1.class_hash,
                selector, 
                len(params), 
                *params
            ]
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
    def token_factory(self, contract_classes, token_init):
        account_cls, _, proxy_cls = contract_classes
        state, account1, account2, token_v1, token_v2, proxy = token_init
        _state = state.copy()
        account1 = cached_contract(_state, account_cls, account1)
        account2 = cached_contract(_state, account_cls, account2)
        proxy = cached_contract(_state, proxy_cls, proxy)

        return account1, account2, proxy, token_v1, token_v2


    @pytest.mark.asyncio
    async def test_constructor(self, token_factory):
        admin, _, proxy, *_ = token_factory

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
        expected = [5, NAME, SYMBOL, DECIMALS, *INIT_SUPPLY]
        assert execution_info.call_info.retdata == expected


    @pytest.mark.asyncio
    async def test_upgrade(self, token_factory):
        admin, _, proxy, _, token_v2 = token_factory

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
            6,                                      # number of return values
            *sub_uint(INIT_SUPPLY, AMOUNT),         # balanceOf admin
            *AMOUNT,                                # balanceOf USER
            *INIT_SUPPLY                            # totalSupply
        ]

        assert execution_info.call_info.retdata == expected


    @pytest.mark.asyncio
    async def test_upgrade_from_nonadmin(self, token_factory):
        admin, non_admin, proxy, _, token_v2 = token_factory

        # should revert
        await assert_revert(signer.send_transaction(
            non_admin, proxy.contract_address, 'upgrade', [token_v2.class_hash]),
            reverted_with="Proxy: caller is not admin"
        )

        # should upgrade from admin
        await signer.send_transaction(
            admin, proxy.contract_address, 'upgrade', [token_v2.class_hash]
        )


    @pytest.mark.asyncio
    async def test_upgrade_transferFrom(self, token_factory):
        admin, non_admin, proxy, _, _ = token_factory

        # approve
        await signer.send_transaction(
            admin, proxy.contract_address, 'approve', [
                non_admin.contract_address,
                *AMOUNT
            ]
        )

        # transferFrom
        return_bool = await signer.send_transaction(
            non_admin, proxy.contract_address, 'transferFrom', [
                admin.contract_address,
                non_admin.contract_address,
                *AMOUNT
            ]
        )
        assert return_bool.call_info.retdata[1] == TRUE

        # should fail
        await assert_revert(signer.send_transaction(
            non_admin, proxy.contract_address, 'transferFrom', [
                admin.contract_address,
                non_admin.contract_address,
                *AMOUNT
                ]
            )
        )
