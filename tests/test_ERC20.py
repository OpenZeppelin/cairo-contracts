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
            str_to_felt("Token"),  # name
            str_to_felt("TKN"),  # symbol
            account.contract_address
        ]
    )
    return starknet, erc20, account


@pytest.mark.asyncio
async def test_constructor(erc20_factory):
    _, erc20, account = erc20_factory
    execution_info = await erc20.balance_of(account.contract_address).call()
    assert execution_info.result.res == uint(1000)

    execution_info = await erc20.total_supply().call()
    assert execution_info.result.res == uint(1000)


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
    execution_info = await erc20.total_supply().call()
    previous_supply = execution_info.result.res

    execution_info = await erc20.balance_of(account.contract_address).call()
    assert execution_info.result.res == uint(1000)

    execution_info = await erc20.balance_of(recipient).call()
    assert execution_info.result.res == uint(0)

    # transfer
    return_bool = await signer.send_transaction(account, erc20.contract_address, 'transfer', [recipient, *amount])
    # check return value equals true ('1')
    assert return_bool.result.response == [1]

    execution_info = await erc20.balance_of(account.contract_address).call()
    assert execution_info.result.res == uint(900)

    execution_info = await erc20.balance_of(recipient).call()
    assert execution_info.result.res == uint(100)

    execution_info = await erc20.total_supply().call()
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
    return_bool = await signer.send_transaction(account, erc20.contract_address, 'approve', [spender, *amount])
    # check return value equals true ('1')
    assert return_bool.result.response == [1]

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
    amount = uint(345)
    recipient = 987
    execution_info = await erc20.balance_of(account.contract_address).call()
    previous_balance = execution_info.result.res

    # approve
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender.contract_address, *amount])
    # transfer_from
    return_bool = await signer.send_transaction(
        spender, erc20.contract_address, 'transfer_from', [
            account.contract_address, recipient, *amount])
    # check return value equals true ('1')
    assert return_bool.result.response == [1]

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
    return_bool = await signer.send_transaction(account, erc20.contract_address, 'increase_allowance', [spender, *amount])
    # check return value equals true ('1')
    assert return_bool.result.response == [1]

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
    return_bool = await signer.send_transaction(account, erc20.contract_address, 'decrease_allowance', [spender, *subtract_amount])
    # check return value equals true ('1')
    assert return_bool.result.response == [1]

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result.res == (
        uint(init_amount[0] - subtract_amount[0])
    )


@pytest.mark.asyncio
async def test_decrease_allowance_underflow(erc20_factory):
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
async def test_increase_allowance_overflow(erc20_factory):
    _, erc20, account = erc20_factory
    # new spender, starting from zero
    spender = 234
    amount = (MAX_AMOUNT)
    # overflow_amount adds (1, 0) to (2**128 - 1, 2**128 - 1)
    overflow_amount = uint(1)
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender, *amount])

    try:
        # overflow check will revert the transaction
        await signer.send_transaction(account, erc20.contract_address, 'increase_allowance', [spender, *overflow_amount])
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
async def test_transfer_from_zero_address(erc20_factory):
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
async def test_transfer_from_func_to_zero_address(erc20_factory):
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
            spender, erc20.contract_address, 'transfer_from',
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
async def test_transfer_from_func_from_zero_address(erc20_factory):
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
            spender, erc20.contract_address, 'transfer_from',
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


@pytest.mark.asyncio
async def test_mint_to_zero_address(erc20_factory):
    _, erc20, account = erc20_factory
    zero_address = 0
    amount = uint(1)

    try:
        await signer.send_transaction(account, erc20.contract_address, 'mint', [zero_address, *amount])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_mint_overflow(erc20_factory):
    _, erc20, account = erc20_factory
    recipient = 789
    # fetching the previously minted total_supply and verifying the overflow check
    # (total_supply >= 2**256) should fail, (total_supply < 2**256) should pass
    execution_info = await erc20.total_supply().call()
    previous_supply = execution_info.result.res

    # pass_amount subtracts the already minted supply from MAX_AMOUNT in order for
    # the minted supply to equal MAX_AMOUNT
    # (2**128 - 1, 2**128 - 1)
    pass_amount = (
        MAX_AMOUNT[0] - previous_supply[0],  # 2**128 - 1
        MAX_AMOUNT[1] - previous_supply[1]  # 2**128 - 1
    )

    # fail_amount displays the edge case where any addition over MAX_SUPPLY
    # should result in a failing tx
    fail_amount = (
        pass_amount[0] + 1,  # 2**128 (will overflow)
        pass_amount[1]   # 2**128 - 1
    )

    try:
        await signer.send_transaction(account, erc20.contract_address, 'mint', [recipient, *fail_amount])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

    # should pass
    await signer.send_transaction(account, erc20.contract_address, 'mint', [recipient, *pass_amount])


@pytest.mark.asyncio
async def test_burn(erc20_factory):
    _, erc20, account = erc20_factory
    user = 789
    burn_amount = uint(500)
    execution_info = await erc20.total_supply().call()
    previous_supply = execution_info.result.res

    execution_info = await erc20.balance_of(user).call()
    previous_balance = execution_info.result.res

    await signer.send_transaction(account, erc20.contract_address, 'burn', [user, *burn_amount])

    # total supply should reflect the burned amount
    execution_info = await erc20.total_supply().call()
    assert execution_info.result.res == (
        previous_supply[0] - burn_amount[0],
        previous_supply[1] - burn_amount[1]
    )

    # user balance should reflect the burned amount
    execution_info = await erc20.balance_of(user).call()
    assert execution_info.result.res == (
        previous_balance[0] - burn_amount[0],
        previous_balance[1] - burn_amount[1]
    )


@pytest.mark.asyncio
async def test_burn_zero_address(erc20_factory):
    _, erc20, account = erc20_factory
    zero_address = 0
    burn_amount = uint(1)

    try:
        await signer.send_transaction(account, erc20.contract_address, 'burn', [zero_address, *burn_amount])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_burn_overflow(erc20_factory):
    _, erc20, account = erc20_factory
    user = 789
    execution_info = await erc20.balance_of(user).call()
    previous_balance = execution_info.result.res
    # increasing the burn amount to more than the user's balance
    # should make the tx fail
    burn_amount = (previous_balance[0] + 1, previous_balance[1])

    try:
        await signer.send_transaction(account, erc20.contract_address, 'burn', [user, *burn_amount])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED
