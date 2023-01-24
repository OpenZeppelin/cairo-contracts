import pytest

from signers import MockSigner
from utils import (
    State,
    Account,
    get_contract_class,
    cached_contract,
    FALSE,
    TRUE,
)

signer = MockSigner(123456789987654321)


@pytest.fixture(scope='module')
def contract_classes():
    account_cls = Account.get_class
    deployer_cls = get_contract_class('UniversalDeployer')

    return account_cls, deployer_cls


@pytest.fixture(scope='module')
async def deployer_init(contract_classes):
    _, deployer_cls = contract_classes
    starknet = await State.init()
    account = await Account.deploy(signer.public_key)
    deployer = await starknet.deploy(contract_class=deployer_cls)
    return (
        starknet.state,
        account,
        deployer
    )


@pytest.fixture
def deployer_factory(contract_classes, deployer_init):
    account_cls, deployer_cls = contract_classes
    state, account, deployer = deployer_init
    _state = state.copy()
    _account = cached_contract(_state, account_cls, account)
    deployer = cached_contract(_state, deployer_cls, deployer)

    return _account, deployer


@pytest.mark.asyncio
async def test_signer_declare_class(deployer_factory):
    account, deployer = deployer_factory
    salt = 1234567875432  # random value
    unique = 0
    calldata = []

    # declare contract class
    class_hash, _ = await signer.declare_class(account, "Initializable")

    # deploy contract
    params = [class_hash, salt, unique, len(calldata), *calldata]
    deploy_exec_info = await signer.send_transaction(account, deployer.contract_address, 'deployContract', params)
    deployed_address = deploy_exec_info.call_info.retdata[1]

    # test deployment
    tx_exec_info = await signer.send_transaction(account, deployed_address, 'initialized', [])
    is_initialized = tx_exec_info.call_info.retdata[1]
    assert is_initialized == FALSE

    await signer.send_transaction(account, deployed_address, 'initialize', [])

    tx_exec_info = await signer.send_transaction(account, deployed_address, 'initialized', [])
    is_initialized = tx_exec_info.call_info.retdata[1]
    assert is_initialized == TRUE
