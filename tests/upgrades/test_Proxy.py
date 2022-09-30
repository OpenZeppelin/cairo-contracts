import pytest
from signers import MockSigner
from utils import (
    assert_revert,
    get_contract_class,
    cached_contract,
    assert_event_emitted,
    assert_revert_entry_point,
    get_selector_from_name,
    State,
    Account
)

# random value
VALUE = 123

signer = MockSigner(123456789987654321)

class TestProxy:
    @pytest.fixture(scope='module')
    def contract_classes(self):
        account_cls = Account.get_class
        implementation_cls = get_contract_class('ProxiableImplementation')
        proxy_cls = get_contract_class('Proxy')

        return account_cls, implementation_cls, proxy_cls


    @pytest.fixture(scope='module')
    async def proxy_init(self, contract_classes):
        account_cls, implementation_cls, proxy_cls = contract_classes
        starknet = await State.init()
        account1 = await Account.deploy(signer.public_key)
        account2 = await Account.deploy(signer.public_key)
        implementation_decl = await starknet.declare(
            contract_class=implementation_cls
        )
        selector = get_selector_from_name('initializer')
        params = [
            account1.contract_address   # admin account
        ]
        proxy = await starknet.deploy(
            contract_class=proxy_cls,
            constructor_calldata=[
                implementation_decl.class_hash,
                selector,
                len(params),
                *params
            ]
        )
        return (
            starknet.state,
            account1,
            account2,
            proxy
        )


    @pytest.fixture
    def proxy_factory(self, contract_classes, proxy_init):
        account_cls, _, proxy_cls = contract_classes
        state, account1, account2, proxy = proxy_init
        _state = state.copy()
        admin = cached_contract(_state, account_cls, account1)
        other = cached_contract(_state, account_cls, account2)
        proxy = cached_contract(_state, proxy_cls, proxy)

        return admin, other, proxy


    #
    # initializer
    #

    @pytest.mark.asyncio
    async def test_initializer(self, proxy_factory):
        admin, _, proxy = proxy_factory

        # check admin is set
        execution_info = await signer.send_transaction(
            admin, proxy.contract_address, 'getAdmin', []
        )
        assert execution_info.call_info.retdata[1] == admin.contract_address


    @pytest.mark.asyncio
    async def test_initializer_after_initialized(self, proxy_factory):
        admin, _, proxy = proxy_factory

        await assert_revert(signer.send_transaction(
            admin, proxy.contract_address, 'initializer', [admin.contract_address]),
            reverted_with="Proxy: contract already initialized"
        )

    #
    # set_admin
    #

    @pytest.mark.asyncio
    async def test_set_admin(self, proxy_factory):
        admin, _, proxy = proxy_factory

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
        assert execution_info.call_info.retdata[1] == VALUE


    @pytest.mark.asyncio
    async def test_set_admin_from_unauthorized(self, proxy_factory):
        _, non_admin, proxy = proxy_factory

        # set admin
        await assert_revert(signer.send_transaction(
            non_admin, proxy.contract_address, 'setAdmin', [VALUE]),
            reverted_with="Proxy: caller is not admin"
        )

    #
    # fallback function
    #

    @pytest.mark.asyncio
    async def test_default_fallback(self, proxy_factory):
        admin, _, proxy = proxy_factory

        # set value through proxy
        await signer.send_transaction(
            admin, proxy.contract_address, 'setValue', [VALUE]
        )

        # get value through proxy
        execution_info = await signer.send_transaction(
            admin, proxy.contract_address, 'getValue', []
        )
        assert execution_info.call_info.retdata[1] == VALUE


    @pytest.mark.asyncio
    async def test_fallback_when_selector_does_not_exist(self, proxy_factory):
        admin, _, proxy = proxy_factory

        # should fail with entry point error
        await assert_revert_entry_point(
            signer.send_transaction(
                admin, proxy.contract_address, 'invalid_selector', []
            ),
            invalid_selector='invalid_selector'
        )
