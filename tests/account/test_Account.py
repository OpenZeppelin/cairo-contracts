import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils import Signer, assert_revert, contract_path

signer = Signer(123456789987654321)
other = Signer(987654321123456789)

IACCOUNT_ID = 0xf10dbd44
TRUE = 1


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
async def account_factory():
    starknet = await Starknet.empty()
    account = await starknet.deploy(
        contract_path("openzeppelin/account/Account.cairo"),
        constructor_calldata=[signer.public_key]
    )
    bad_account = await starknet.deploy(
        contract_path("openzeppelin/account/Account.cairo"),
        constructor_calldata=[signer.public_key],
    )

    return starknet, account, bad_account


@pytest.mark.asyncio
async def test_constructor(account_factory):
    _, account, _ = account_factory

    execution_info = await account.get_public_key().call()
    assert execution_info.result == (signer.public_key,)

    execution_info = await account.supportsInterface(IACCOUNT_ID).call()
    assert execution_info.result == (TRUE,)


@pytest.mark.asyncio
async def test_execute(account_factory):
    starknet, account, _ = account_factory
    initializable = await starknet.deploy(
        contract_path("openzeppelin/security/initializable.cairo")
    )

    execution_info = await initializable.initialized().call()
    assert execution_info.result == (0,)

    await signer.send_transactions(account, [(initializable.contract_address, 'initialize', [])])

    execution_info = await initializable.initialized().call()
    assert execution_info.result == (1,)


@pytest.mark.asyncio
async def test_multicall(account_factory):
    starknet, account, _ = account_factory
    initializable_1 = await starknet.deploy(
        contract_path("openzeppelin/security/initializable.cairo")
    )
    initializable_2 = await starknet.deploy(
        contract_path("openzeppelin/security/initializable.cairo")
    )

    execution_info = await initializable_1.initialized().call()
    assert execution_info.result == (0,)
    execution_info = await initializable_2.initialized().call()
    assert execution_info.result == (0,)

    await signer.send_transactions(
        account,
        [
            (initializable_1.contract_address, 'initialize', []),
            (initializable_2.contract_address, 'initialize', [])
        ]
    )

    execution_info = await initializable_1.initialized().call()
    assert execution_info.result == (1,)
    execution_info = await initializable_2.initialized().call()
    assert execution_info.result == (1,)


@pytest.mark.asyncio
async def test_return_value(account_factory):
    starknet, account, _ = account_factory
    initializable = await starknet.deploy(
        contract_path("openzeppelin/security/initializable.cairo")
    )

    # initialize, set `initialized = 1`
    await signer.send_transactions(account, [(initializable.contract_address, 'initialize', [])])

    read_info = await signer.send_transactions(account, [(initializable.contract_address, 'initialized', [])])
    call_info = await initializable.initialized().call()
    (call_result, ) = call_info.result
    assert read_info.result.response == [call_result]  # 1


@ pytest.mark.asyncio
async def test_nonce(account_factory):
    starknet, account, _ = account_factory
    initializable = await starknet.deploy(
        contract_path("openzeppelin/security/initializable.cairo")
    )
    execution_info = await account.get_nonce().call()
    current_nonce = execution_info.result.res

    # lower nonce
    try:
        await signer.send_transactions(account, [(initializable.contract_address, 'initialize', [])], current_nonce - 1)
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

    # higher nonce
    try:
        await signer.send_transactions(account, [(initializable.contract_address, 'initialize', [])], current_nonce + 1)
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED
    # right nonce
    await signer.send_transactions(account, [(initializable.contract_address, 'initialize', [])], current_nonce)

    execution_info = await initializable.initialized().call()
    assert execution_info.result == (1,)


@pytest.mark.asyncio
async def test_public_key_setter(account_factory):
    _, account, _ = account_factory

    execution_info = await account.get_public_key().call()
    assert execution_info.result == (signer.public_key,)

    # set new pubkey
    await signer.send_transactions(account, [(account.contract_address, 'set_public_key', [other.public_key])])

    execution_info = await account.get_public_key().call()
    assert execution_info.result == (other.public_key,)


@pytest.mark.asyncio
async def test_public_key_setter_different_account(account_factory):
    _, account, bad_account = account_factory

    # set new pubkey
    await assert_revert(
        signer.send_transactions(
            bad_account,
            [(account.contract_address, 'set_public_key', [other.public_key])]
        ),
        reverted_with="Account: caller is not this account"
    )
