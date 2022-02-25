from starkware.starknet.testing.starknet import Starknet, StarknetContract
from starkware.starknet.compiler.compile import compile_starknet_files
import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils import Signer, to_uint, sub_uint, str_to_felt, assert_revert, assert_event_emitted

signer = Signer(123456789987654321)

USER = 999
INIT_SUPPLY = to_uint(1000)
AMOUNT = to_uint(250)
NAME = str_to_felt('Upgradeable Token')
SYMBOL = str_to_felt('UTKN')


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


# contract paths
account_path = 'contracts/Account.cairo'
proxy_path = 'contracts/proxy/Proxy.cairo'
token_path = 'contracts/token/ERC20_Upgradeable.cairo'

# random value
VALUE = 123
VALUE_2 = 987


signer = Signer(123456789987654321)


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
def contract_defs():
    account_def = compile_starknet_files(
        files=[account_path],
        debug_info=True
    )
    token_def = compile_starknet_files(
        files=[token_path],
        debug_info=True
    )
    proxy_def = compile_starknet_files(
        files=[proxy_path],
        debug_info=True
    )
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
    account1 = StarknetContract(
        state=_state,
        abi=account_def.abi,
        contract_address=account1.contract_address,
        deploy_execution_info=account1.deploy_execution_info
    )
    account2 = StarknetContract(
        state=_state,
        abi=account_def.abi,
        contract_address=account2.contract_address,
        deploy_execution_info=account2.deploy_execution_info
    )
    token_v1 = StarknetContract(
        state=_state,
        abi=token_def.abi,
        contract_address=token_v1.contract_address,
        deploy_execution_info=token_v1.deploy_execution_info
    )
    token_v2 = StarknetContract(
        state=_state,
        abi=token_def.abi,
        contract_address=token_v2.contract_address,
        deploy_execution_info=token_v2.deploy_execution_info
    )
    proxy = StarknetContract(
        state=_state,
        abi=proxy_def.abi,
        contract_address=proxy.contract_address,
        deploy_execution_info=proxy.deploy_execution_info
    )
    return account1, account2, token_v1, token_v2, proxy


@pytest.fixture
async def after_initializer(token_factory):
    admin, other, token_v1, token_v2, proxy = token_factory

    # initialize
    await signer.send_transaction(
        admin, proxy.contract_address, 'initializer', [
            NAME,
            SYMBOL,
            *INIT_SUPPLY,
            admin.contract_address,
            admin.contract_address
        ]
    )

    return admin, other, token_v1, token_v2, proxy


@pytest.mark.asyncio
async def test_initializer(token_factory):
    admin, _, _, _, proxy = token_factory

    await signer.send_transaction(
        admin, proxy.contract_address, 'initializer', [
            NAME,
            SYMBOL,
            *INIT_SUPPLY,
            admin.contract_address,
            admin.contract_address
        ]
    )

    # check name
    execution_info = await signer.send_transaction(
        admin, proxy.contract_address, 'name', []
    )
    assert execution_info.result.response == [NAME]

    # check symbol
    execution_info = await signer.send_transaction(
        admin, proxy.contract_address, 'symbol', []
    )
    assert execution_info.result.response == [SYMBOL]

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
