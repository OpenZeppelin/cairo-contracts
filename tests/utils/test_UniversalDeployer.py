import pytest
from starkware.starknet.core.os.contract_address.contract_address import calculate_contract_address_from_hash
from starkware.crypto.signature.fast_pedersen_hash import pedersen_hash
from starkware.starknet.core.os.class_hash import compute_class_hash

from signers import MockSigner
from utils import (
    State,
    Account,
    get_contract_class,
    assert_event_emitted,
    cached_contract,
    str_to_felt,
    IACCOUNT_ID,
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
@pytest.mark.parametrize('unique', [TRUE, FALSE])
async def test_deployment(deployer_factory, unique):
    account, deployer = deployer_factory
    salt = 1234567875432  # random value
    calldata = [signer.public_key]
    class_hash = compute_class_hash(
        contract_class=Account.get_class, hash_func=pedersen_hash)

    # deploy contract
    params = [class_hash, salt, unique, len(calldata), *calldata]
    deploy_exec_info = await signer.send_transaction(account, deployer.contract_address, 'deployContract', params)
    deployed_address = deploy_exec_info.call_info.retdata[1]

    # check address
    if unique:
        prefix = account.contract_address
        deployer_address = deployer.contract_address
    else:
        prefix = str_to_felt('UniversalDeployerContract')
        deployer_address = 0

    actual_salt = pedersen_hash(prefix, salt)
    expected_address = calculate_contract_address_from_hash(
        salt=actual_salt,
        class_hash=class_hash,
        constructor_calldata=calldata,
        deployer_address=deployer_address
    )

    assert deployed_address == expected_address

    # check deployment
    tx_exec_info = await signer.send_transaction(account, deployed_address, 'supportsInterface', [IACCOUNT_ID])
    is_account = tx_exec_info.call_info.retdata[1]
    assert is_account == TRUE

    assert_event_emitted(
        deploy_exec_info,
        from_address=deployer.contract_address,
        name='ContractDeployed',
        data=[
            deployed_address,          # contractAddress
            account.contract_address,  # deployer
            class_hash,                # classHash
            actual_salt,               # salt
        ]
    )
