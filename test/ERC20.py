import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils.Signer import Signer

signer = Signer(123456789987654321)


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
async def erc20_factory():
    starknet = await Starknet.empty()
    erc20 = await starknet.deploy("contracts/token/ERC20.cairo")
    account = await starknet.deploy("contracts/Account.cairo")
    await account.initialize(signer.public_key, account.contract_address).invoke()
    await signer.send_transaction(account, erc20.contract_address, 'initialize', [])
    return starknet, erc20, account


@pytest.mark.asyncio
async def test_initializer(erc20_factory):
    _, erc20, account = erc20_factory
    execution_info = await erc20.balance_of(account.contract_address).call()
    assert execution_info.result == (1000,)

    execution_info = await erc20.get_total_supply().call()
    assert execution_info.result == (1000,)


@pytest.mark.asyncio
async def test_transfer(erc20_factory):
    _, erc20, account = erc20_factory
    recipient = 123
    amount = 100
    execution_info = await erc20.get_total_supply().call()
    previous_supply = execution_info.result

    execution_info = await erc20.balance_of(account.contract_address).call()
    assert execution_info.result == (1000,)

    execution_info = await erc20.balance_of(recipient).call()
    assert execution_info.result == (0,)

    await signer.send_transaction(account, erc20.contract_address, 'transfer', [recipient, amount])

    execution_info = await erc20.balance_of(account.contract_address).call()
    assert execution_info.result == (900,)

    execution_info = await erc20.balance_of(recipient).call()
    assert execution_info.result == (100,)

    execution_info = await erc20.get_total_supply().call()
    assert execution_info.result == previous_supply


@pytest.mark.asyncio
async def test_insufficient_sender_funds(erc20_factory):
    _, erc20, account = erc20_factory
    recipient = 123
    execution_info = await erc20.balance_of(account.contract_address).call()
    balance = execution_info.result.res

    try:
        await signer.send_transaction(account, erc20.contract_address, 'transfer', [recipient, balance + 1])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_approve(erc20_factory):
    _, erc20, account = erc20_factory
    spender = 123
    amount = 345

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result == (0,)

    # set approval
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender, amount])

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result == (amount,)


@pytest.mark.asyncio
async def test_transfer_from(erc20_factory):
    starknet, erc20, account = erc20_factory
    spender = await starknet.deploy("contracts/Account.cairo")
    # we use the same signer to control the main and the spender accounts
    # this is ok since they're still two different accounts
    await spender.initialize(signer.public_key, spender.contract_address).invoke()
    amount = 345
    recipient = 987
    execution_info = await erc20.balance_of(account.contract_address).call()
    previous_balance = execution_info.result.res

    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender.contract_address, amount])
    await signer.send_transaction(spender, erc20.contract_address, 'transfer_from',
                                  [account.contract_address, recipient, amount])

    execution_info = await erc20.balance_of(account.contract_address).call()
    assert execution_info.result == (previous_balance - amount,)

    execution_info = await erc20.balance_of(recipient).call()
    assert execution_info.result == (amount,)

    execution_info = await erc20.allowance(account.contract_address, spender.contract_address).call()
    assert execution_info.result == (0,)


@pytest.mark.asyncio
async def test_increase_allowance(erc20_factory):
    _, erc20, account = erc20_factory
    # new spender, starting from zero
    spender = 234
    amount = 345

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result == (0,)

    # set approve
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender, amount])

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result == (amount,)

    # increase allowance
    await signer.send_transaction(account, erc20.contract_address, 'increase_allowance', [spender, amount])

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result == (amount * 2,)


@pytest.mark.asyncio
async def test_decrease_allowance(erc20_factory):
    _, erc20, account = erc20_factory
    # new spender, starting from zero
    spender = 321
    init_amount = 345
    subtract_amount = 100

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result == (0,)

    # set approve
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender, init_amount])

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result == (init_amount,)

    # decrease allowance
    await signer.send_transaction(account, erc20.contract_address, 'decrease_allowance', [spender, subtract_amount])

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result == (init_amount - subtract_amount,)


@pytest.mark.asyncio
async def test_decrease_allowance_below_zero(erc20_factory):
    _, erc20, account = erc20_factory
    # new spender, starting from zero
    spender = 987
    init_amount = 345
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender, init_amount])

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result == (init_amount,)

    try:
        # increasing the decreased allowance amount by more than the user's allowance
        await signer.send_transaction(account, erc20.contract_address, 'decrease_allowance', [spender, init_amount + 1])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_transfer_funds_greater_than_allowance(erc20_factory):
    starknet, erc20, account = erc20_factory
    spender = await starknet.deploy("contracts/Account.cairo")
    # we use the same signer to control the main and the spender accounts
    # this is ok since they're still two different accounts
    await spender.initialize(signer.public_key, spender.contract_address).invoke()
    recipient = 222
    allowance = 111
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender.contract_address, allowance])

    try:
        # increasing the transfer amount above allowance
        await signer.send_transaction(spender, erc20.contract_address, 'transfer_from', [account.contract_address, recipient, allowance + 1])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_overflow_increase_allowance(erc20_factory):
    _, erc20, account = erc20_factory
    # new spender, starting from zero
    spender = 234
    amount = 2**200
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender, amount])

    try:
        # overflow check will revert the transaction
        await signer.send_transaction(account, erc20.contract_address, 'increase_allowance', [spender, amount])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED
