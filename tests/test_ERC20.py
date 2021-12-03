import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils.Signer import Signer

signer = Signer(123456789987654321)

MAX_AMOUNT = (2**128 - 1, 2**128 - 1)


def uint(a):
    return(a, 0)


def str_to_felt(text):
    b_text = bytes(text, 'UTF-8')
    return int.from_bytes(b_text, "big")


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

    erc20 = await starknet.deploy(
        "contracts/token/ERC20.cairo",
        constructor_calldata=[
            str_to_felt("Token"),      # name
            str_to_felt("TKN"),        # symbol
            *uint(1000),               # initial_supply
            account.contract_address   # recipient
        ]
    )
    return starknet, erc20, account


@pytest.mark.asyncio
async def test_constructor(erc20_factory):
    _, erc20, account = erc20_factory
    execution_info = await erc20.balanceOf(account.contract_address).call()
    assert execution_info.result.balance == uint(1000)

    execution_info = await erc20.totalSupply().call()
    assert execution_info.result.totalSupply == uint(1000)


@pytest.mark.asyncio
async def test_name(erc20_factory):
    _, erc20, _ = erc20_factory
    execution_info = await erc20.name().call()
    assert execution_info.result == (str_to_felt("Token"),)


@pytest.mark.asyncio
async def test_symbol(erc20_factory):
    _, erc20, _ = erc20_factory
    execution_info = await erc20.symbol().call()
    assert execution_info.result == (str_to_felt("TKN"),)


@pytest.mark.asyncio
async def test_transfer(erc20_factory):
    _, erc20, account = erc20_factory
    recipient = 123
    amount = uint(100)
    execution_info = await erc20.totalSupply().call()
    previous_supply = execution_info.result.totalSupply

    execution_info = await erc20.balanceOf(account.contract_address).call()
    assert execution_info.result.balance == uint(1000)

    execution_info = await erc20.balanceOf(recipient).call()
    assert execution_info.result.balance == uint(0)

    # transfer
    return_bool = await signer.send_transaction(account, erc20.contract_address, 'transfer', [recipient, *amount])
    # check return value equals true ('1')
    assert return_bool.result.response == [1]

    execution_info = await erc20.balanceOf(account.contract_address).call()
    assert execution_info.result.balance == uint(900)

    execution_info = await erc20.balanceOf(recipient).call()
    assert execution_info.result.balance == uint(100)

    execution_info = await erc20.totalSupply().call()
    assert execution_info.result.totalSupply == previous_supply


@pytest.mark.asyncio
async def test_insufficient_sender_funds(erc20_factory):
    _, erc20, account = erc20_factory
    recipient = 123
    execution_info = await erc20.balanceOf(account.contract_address).call()
    balance = execution_info.result.balance

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
    assert execution_info.result.remaining == uint(0)

    # set approval
    return_bool = await signer.send_transaction(account, erc20.contract_address, 'approve', [spender, *amount])
    # check return value equals true ('1')
    assert return_bool.result.response == [1]

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result.remaining == amount


@pytest.mark.asyncio
async def test_transferFrom(erc20_factory):
    starknet, erc20, account = erc20_factory
    spender = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )
    # we use the same signer to control the main and the spender accounts
    # this is ok since they're still two different accounts
    amount = uint(345)
    recipient = 987
    execution_info = await erc20.balanceOf(account.contract_address).call()
    previous_balance = execution_info.result.balance

    # approve
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender.contract_address, *amount])
    # transferFrom
    return_bool = await signer.send_transaction(
        spender, erc20.contract_address, 'transferFrom', [
            account.contract_address, recipient, *amount])
    # check return value equals true ('1')
    assert return_bool.result.response == [1]

    execution_info = await erc20.balanceOf(account.contract_address).call()
    assert execution_info.result.balance == (
        uint(previous_balance[0] - amount[0])
    )

    execution_info = await erc20.balanceOf(recipient).call()
    assert execution_info.result.balance == amount

    execution_info = await erc20.allowance(account.contract_address, spender.contract_address).call()
    assert execution_info.result.remaining == uint(0)


@pytest.mark.asyncio
async def test_increaseAllowance(erc20_factory):
    _, erc20, account = erc20_factory
    # new spender, starting from zero
    spender = 234
    amount = uint(345)

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result.remaining == uint(0)

    # set approve
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender, *amount])

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result.remaining == amount

    # increase allowance
    return_bool = await signer.send_transaction(account, erc20.contract_address, 'increaseAllowance', [spender, *amount])
    # check return value equals true ('1')
    assert return_bool.result.response == [1]

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result.remaining == (
        uint(amount[0] * 2)
    )


@pytest.mark.asyncio
async def test_decreaseAllowance(erc20_factory):
    _, erc20, account = erc20_factory
    # new spender, starting from zero
    spender = 321
    init_amount = uint(345)
    subtract_amount = uint(100)

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result.remaining == uint(0)

    # set approve
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender, *init_amount])

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result.remaining == init_amount

    # decrease allowance
    return_bool = await signer.send_transaction(account, erc20.contract_address, 'decreaseAllowance', [spender, *subtract_amount])
    # check return value equals true ('1')
    assert return_bool.result.response == [1]

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result.remaining == (
        uint(init_amount[0] - subtract_amount[0])
    )


@pytest.mark.asyncio
async def test_decreaseAllowance_underflow(erc20_factory):
    _, erc20, account = erc20_factory
    # new spender, starting from zero
    spender = 987
    init_amount = uint(345)
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender, *init_amount])

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result.remaining == init_amount

    try:
        # increasing the decreased allowance amount by more than the user's allowance
        await signer.send_transaction(account, erc20.contract_address, 'decreaseAllowance', [
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
    recipient = 222
    allowance = uint(111)
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender.contract_address, *allowance])

    try:
        # increasing the transfer amount above allowance
        await signer.send_transaction(spender, erc20.contract_address, 'transferFrom', [
            account.contract_address,
            recipient,
            *uint(allowance[0] + 1)
        ])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_increaseAllowance_overflow(erc20_factory):
    _, erc20, account = erc20_factory
    # new spender, starting from zero
    spender = 234
    amount = (MAX_AMOUNT)
    # overflow_amount adds (1, 0) to (2**128 - 1, 2**128 - 1)
    overflow_amount = uint(1)
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender, *amount])

    try:
        # overflow check will revert the transaction
        await signer.send_transaction(account, erc20.contract_address, 'increaseAllowance', [spender, *overflow_amount])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_transfer_to_zero_address(erc20_factory):
    _, erc20, account = erc20_factory
    recipient = 0
    amount = uint(1)

    try:
        await signer.send_transaction(account, erc20.contract_address, 'transfer', [recipient, *amount])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_transferFrom_zero_address(erc20_factory):
    _, erc20, _ = erc20_factory
    recipient = 123
    amount = uint(1)

    # Without using an account abstraction, the caller address
    # (get_caller_address) is zero
    try:
        await erc20.transfer(recipient, amount).invoke()
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_transferFrom_func_to_zero_address(erc20_factory):
    starknet, erc20, account = erc20_factory
    spender = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )
    # we use the same signer to control the main and the spender accounts
    # this is ok since they're still two different accounts
    amount = uint(1)
    zero_address = 0

    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender.contract_address, *amount])

    try:
        await signer.send_transaction(
            spender, erc20.contract_address, 'transferFrom',
            [
                account.contract_address,
                zero_address,
                *amount
            ])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_transferFrom_func_from_zero_address(erc20_factory):
    starknet, erc20, account = erc20_factory
    spender = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )
    # we use the same signer to control the main and the spender accounts
    # this is ok since they're still two different accounts
    zero_address = 0
    recipient = 123
    amount = uint(1)

    try:
        await signer.send_transaction(
            spender, erc20.contract_address, 'transferFrom',
            [
                zero_address,
                recipient,
                *amount
            ])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_approve_zero_address_spender(erc20_factory):
    _, erc20, account = erc20_factory
    spender = 0
    amount = uint(1)

    try:
        await signer.send_transaction(account, erc20.contract_address, 'approve', [spender, *amount])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_approve_zero_address_caller(erc20_factory):
    _, erc20, _ = erc20_factory
    spender = 123
    amount = uint(345)

    # Without using an account abstraction, the caller address
    # (get_caller_address) is zero
    try:
        await erc20.approve(spender, amount).invoke()
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED
