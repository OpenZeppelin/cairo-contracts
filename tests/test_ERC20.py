import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils.Signer import Signer

signer = Signer(123456789987654321)


def uint(a):
    return(a, 0)


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
async def erc20_factory():
    starknet = await Starknet.empty()
    account = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )
    await account.initialize(account.contract_address).invoke()

    erc20 = await starknet.deploy(
        "contracts/token/ERC20.cairo",
        constructor_calldata=[account.contract_address]
    )
    return starknet, erc20, account


@pytest.mark.asyncio
async def test_constructor(erc20_factory):
    _, erc20, account = erc20_factory
    execution_info = await erc20.balance_of(account.contract_address).call()
    assert execution_info.result.res == uint(1000)

    execution_info = await erc20.get_total_supply().call()
    assert execution_info.result.res == uint(1000)


@pytest.mark.asyncio
async def test_transfer(erc20_factory):
    _, erc20, account = erc20_factory
    recipient = 123
    amount = uint(100)
    execution_info = await erc20.get_total_supply().call()
    previous_supply = execution_info.result.res

    execution_info = await erc20.balance_of(account.contract_address).call()
    assert execution_info.result.res == uint(1000)

    execution_info = await erc20.balance_of(recipient).call()
    assert execution_info.result.res == uint(0)

    await signer.send_transaction(account, erc20.contract_address, 'transfer', [recipient, *amount])

    execution_info = await erc20.balance_of(account.contract_address).call()
    assert execution_info.result.res == uint(900)

    execution_info = await erc20.balance_of(recipient).call()
    assert execution_info.result.res == uint(100)

    execution_info = await erc20.get_total_supply().call()
    assert execution_info.result.res == previous_supply


@pytest.mark.asyncio
async def test_insufficient_sender_funds(erc20_factory):
    _, erc20, account = erc20_factory
    recipient = 123
    execution_info = await erc20.balance_of(account.contract_address).call()
    balance = execution_info.result.res

    try:
        await signer.send_transaction(account, erc20.contract_address, 'transfer', [
            recipient,
            *uint(balance[0] + 1)
        ])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_approve(erc20_factory):
    _, erc20, account = erc20_factory
    spender = 123
    amount = uint(345)

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result.res == uint(0)

    # set approval
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender, *amount])

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result.res == amount


@pytest.mark.asyncio
async def test_transfer_from(erc20_factory):
    starknet, erc20, account = erc20_factory
    spender = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )
    # we use the same signer to control the main and the spender accounts
    # this is ok since they're still two different accounts
    await spender.initialize(spender.contract_address).invoke()
    amount = uint(345)
    recipient = 987
    execution_info = await erc20.balance_of(account.contract_address).call()
    previous_balance = execution_info.result.res

    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender.contract_address, *amount])
    await signer.send_transaction(spender, erc20.contract_address, 'transfer_from',
                                  [account.contract_address, recipient, *amount])

    execution_info = await erc20.balance_of(account.contract_address).call()
    assert execution_info.result.res == (
        uint(previous_balance[0] - amount[0])
    )

    execution_info = await erc20.balance_of(recipient).call()
    assert execution_info.result.res == amount

    execution_info = await erc20.allowance(account.contract_address, spender.contract_address).call()
    assert execution_info.result.res == uint(0)


@pytest.mark.asyncio
async def test_increase_allowance(erc20_factory):
    _, erc20, account = erc20_factory
    # new spender, starting from zero
    spender = 234
    amount = uint(345)

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result.res == uint(0)

    # set approve
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender, *amount])

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result.res == amount

    # increase allowance
    await signer.send_transaction(account, erc20.contract_address, 'increase_allowance', [spender, *amount])

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result.res == (
        uint(amount[0] * 2)
    )


@pytest.mark.asyncio
async def test_decrease_allowance(erc20_factory):
    _, erc20, account = erc20_factory
    # new spender, starting from zero
    spender = 321
    init_amount = uint(345)
    subtract_amount = uint(100)

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result.res == uint(0)

    # set approve
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender, *init_amount])

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result.res == init_amount

    # decrease allowance
    await signer.send_transaction(account, erc20.contract_address, 'decrease_allowance', [spender, *subtract_amount])

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result.res == (
        uint(init_amount[0] - subtract_amount[0])
    )


@pytest.mark.asyncio
async def test_decrease_allowance_below_zero(erc20_factory):
    _, erc20, account = erc20_factory
    # new spender, starting from zero
    spender = 987
    init_amount = uint(345)
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender, *init_amount])

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result.res == init_amount

    try:
        # increasing the decreased allowance amount by more than the user's allowance
        await signer.send_transaction(account, erc20.contract_address, 'decrease_allowance', [
            spender,
            *uint(init_amount[0] + 1)
        ])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_transfer_funds_greater_than_allowance(erc20_factory):
    starknet, erc20, account = erc20_factory
    spender = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )
    # we use the same signer to control the main and the spender accounts
    # this is ok since they're still two different accounts
    await spender.initialize(spender.contract_address).invoke()
    recipient = 222
    allowance = uint(111)
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender.contract_address, *allowance])

    try:
        # increasing the transfer amount above allowance
        await signer.send_transaction(spender, erc20.contract_address, 'transfer_from', [
            account.contract_address,
            recipient,
            *uint(allowance[0] + 1)
        ])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_overflow_increase_allowance(erc20_factory):
    _, erc20, account = erc20_factory
    # new spender, starting from zero
    spender = 234
    amount = uint(2**200)
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender, *amount])

    try:
        # overflow check will revert the transaction
        await signer.send_transaction(account, erc20.contract_address, 'increase_allowance', [spender, *amount])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED
