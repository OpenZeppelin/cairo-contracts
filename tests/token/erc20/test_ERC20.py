import pytest
from starkware.starknet.testing.starknet import Starknet
from utils import (
    Signer, uint, str_to_felt, MAX_UINT256, INVALID_UINT256, ZERO_ADDRESS,
    assert_event_emitted, assert_revert, sub_uint, add_uint, contract_path
)


signer = Signer(123456789987654321)


@pytest.fixture(scope='module')
async def erc20_factory():
    starknet = await Starknet.empty()
    account = await starknet.deploy(
        contract_path("openzeppelin/account/Account.cairo"),
        constructor_calldata=[signer.public_key]
    )

    erc20 = await starknet.deploy(
        contract_path("openzeppelin/token/erc20/ERC20.cairo"),
        constructor_calldata=[
            str_to_felt("Token"),      # name
            str_to_felt("TKN"),        # symbol
            18,                        # decimals
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
async def test_constructor_invalid_decimals(erc20_factory):
    starknet, _, account = erc20_factory
    invalid_decimals = 2**8 + 1

    await assert_revert(starknet.deploy(
        contract_path("openzeppelin/token/erc20/ERC20.cairo"),
        constructor_calldata=[
            str_to_felt("Token"),
            str_to_felt("TKN"),
            invalid_decimals,
            *uint(1000),
            account.contract_address
        ]),
        reverted_with="ERC20: decimals exceed 2^8"
    )


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
async def test_decimals(erc20_factory):
    _, erc20, _ = erc20_factory
    execution_info = await erc20.decimals().call()
    assert execution_info.result.decimals == 18


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
async def test_transfer_emits_event(erc20_factory):
    _, erc20, account = erc20_factory
    recipient = 123
    amount = uint(100)

    tx_exec_info = await signer.send_transaction(
        account, erc20.contract_address, 'transfer', [
            recipient,
            *amount
        ])

    assert_event_emitted(
        tx_exec_info,
        from_address=erc20.contract_address,
        name='Transfer',
        data=[
            account.contract_address,
            recipient,
            *amount
        ]
    )


@pytest.mark.asyncio
async def test_insufficient_sender_funds(erc20_factory):
    _, erc20, account = erc20_factory
    recipient = 123
    execution_info = await erc20.balanceOf(account.contract_address).call()
    balance = execution_info.result.balance

    await assert_revert(signer.send_transaction(
        account, erc20.contract_address, 'transfer', [
            recipient,
            *uint(balance[0] + 1)
        ]),
        reverted_with="ERC20: transfer amount exceeds balance"
    )


@pytest.mark.asyncio
async def test_transfer_invalid_uint256(erc20_factory):
    _, erc20, account = erc20_factory
    recipient = 123

    await assert_revert(signer.send_transaction(
        account, erc20.contract_address, 'transfer', [
            recipient,
            *INVALID_UINT256
        ]),
        reverted_with="ERC20: amount is not a valid Uint256"
    )


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
async def test_approve_emits_event(erc20_factory):
    _, erc20, account = erc20_factory
    spender = 123
    amount = uint(345)

    tx_exec_info = await signer.send_transaction(
        account, erc20.contract_address, 'approve', [
            spender,
            *amount
        ])

    assert_event_emitted(
        tx_exec_info,
        from_address=erc20.contract_address,
        name='Approval',
        data=[
            account.contract_address,
            spender,
            *amount
        ]
    )


@pytest.mark.asyncio
async def test_approve_invalid_uint256(erc20_factory):
    _, erc20, account = erc20_factory
    spender = 123

    await assert_revert(
        signer.send_transaction(
            account, erc20.contract_address, 'approve', [
                spender,
                *INVALID_UINT256
            ]),
        reverted_with="ERC20: amount is not a valid Uint256"
    )


@pytest.mark.asyncio
async def test_transferFrom(erc20_factory):
    starknet, erc20, account = erc20_factory
    spender = await starknet.deploy(
        contract_path("openzeppelin/account/Account.cairo"),
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
async def test_transferFrom_emits_event(erc20_factory):
    starknet, erc20, account = erc20_factory
    spender = await starknet.deploy(
        contract_path("openzeppelin/account/Account.cairo"),
        constructor_calldata=[signer.public_key]
    )
    amount = uint(345)
    recipient = 987

    # approve
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender.contract_address, *amount])
    # transferFrom
    tx_exec_info = await signer.send_transaction(
        spender, erc20.contract_address, 'transferFrom', [
            account.contract_address,
            recipient,
            *amount
        ])

    assert_event_emitted(
        tx_exec_info,
        from_address=erc20.contract_address,
        name='Transfer',
        data=[
            account.contract_address,
            recipient,
            *amount
        ]
    )


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
async def test_increaseAllowance_emits_event(erc20_factory):
    _, erc20, account = erc20_factory
    # new spender, starting from zero
    spender = 234
    amount = uint(345)

    # set approve
    await signer.send_transaction(
        account, erc20.contract_address, 'approve', [
            spender, *amount
        ])

    # increase allowance
    tx_exec_info = await signer.send_transaction(
        account, erc20.contract_address, 'increaseAllowance', [
            spender,
            *amount
        ])

    assert_event_emitted(
        tx_exec_info,
        from_address=erc20.contract_address,
        name='Approval',
        data=[
            account.contract_address,
            spender,
            *add_uint(amount, amount)
        ]
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
async def test_decreaseAllowance_emits_event(erc20_factory):
    _, erc20, account = erc20_factory
    # new spender, starting from zero
    spender = 321
    init_amount = uint(345)
    subtract_amount = uint(100)

    # set approve
    await signer.send_transaction(
        account, erc20.contract_address, 'approve', [
            spender,
            *init_amount
        ])

    # decrease allowance
    tx_exec_info = await signer.send_transaction(
        account, erc20.contract_address, 'decreaseAllowance', [
            spender,
            *subtract_amount
        ])

    assert_event_emitted(
        tx_exec_info,
        from_address=erc20.contract_address,
        name='Approval',
        data=[
            account.contract_address,
            spender,
            *sub_uint(init_amount, subtract_amount)
        ]
    )


@pytest.mark.asyncio
async def test_decreaseAllowance_emits_event(erc20_factory):
    _, erc20, account = erc20_factory

    spender = 321

    await assert_revert(
        signer.send_transaction(
            account, erc20.contract_address, 'decreaseAllowance', [
                spender,
                *INVALID_UINT256
            ]),
        reverted_with="ERC20: subtracted_value is not a valid Uint256"
    )


@pytest.mark.asyncio
async def test_decreaseAllowance_overflow(erc20_factory):
    _, erc20, account = erc20_factory
    # new spender, starting from zero
    spender = 987
    init_amount = uint(345)
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender, *init_amount])

    execution_info = await erc20.allowance(account.contract_address, spender).call()
    assert execution_info.result.remaining == init_amount

    # increasing the decreased allowance amount by more than the user's allowance
    await assert_revert(signer.send_transaction(
        account, erc20.contract_address, 'decreaseAllowance', [
            spender,
            *uint(init_amount[0] + 1)
        ]),
        reverted_with="ERC20: allowance below zero"
    )


@pytest.mark.asyncio
async def test_transfer_funds_greater_than_allowance(erc20_factory):
    starknet, erc20, account = erc20_factory
    spender = await starknet.deploy(
        contract_path("openzeppelin/account/Account.cairo"),
        constructor_calldata=[signer.public_key]
    )
    # we use the same signer to control the main and the spender accounts
    # this is ok since they're still two different accounts
    recipient = 222
    allowance = uint(111)
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender.contract_address, *allowance])

    # increasing the transfer amount above allowance
    await assert_revert(signer.send_transaction(
        spender, erc20.contract_address, 'transferFrom', [
            account.contract_address,
            recipient,
            *uint(allowance[0] + 1)
        ]),
        reverted_with="ERC20: transfer amount exceeds allowance"
    )


@pytest.mark.asyncio
async def test_increaseAllowance_overflow(erc20_factory):
    _, erc20, account = erc20_factory
    # new spender, starting from zero
    spender = 234
    amount = MAX_UINT256
    # overflow_amount adds (1, 0) to (2**128 - 1, 2**128 - 1)
    overflow_amount = uint(1)
    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender, *amount])

    await assert_revert(signer.send_transaction(
        account, erc20.contract_address, 'increaseAllowance', [
            spender, *overflow_amount
        ]),
        reverted_with="ERC20: allowance overflow"
    )


@pytest.mark.asyncio
async def test_transfer_to_zero_address(erc20_factory):
    _, erc20, account = erc20_factory
    amount = uint(1)

    await assert_revert(signer.send_transaction(
        account, erc20.contract_address, 'transfer', [
            ZERO_ADDRESS, *amount
        ]),
        reverted_with="ERC20: cannot transfer to the zero address"
    )


@pytest.mark.asyncio
async def test_transferFrom_zero_address(erc20_factory):
    _, erc20, _ = erc20_factory
    recipient = 123
    amount = uint(1)

    # Without using an account abstraction, the caller address
    # (get_caller_address) is zero
    await assert_revert(
        erc20.transfer(recipient, amount).invoke(),
        reverted_with="ERC20: cannot transfer from the zero address"
    )


@pytest.mark.asyncio
async def test_transferFrom_func_to_zero_address(erc20_factory):
    starknet, erc20, account = erc20_factory
    spender = await starknet.deploy(
        contract_path("openzeppelin/account/Account.cairo"),
        constructor_calldata=[signer.public_key]
    )
    # we use the same signer to control the main and the spender accounts
    # this is ok since they're still two different accounts
    amount = uint(1)

    await signer.send_transaction(account, erc20.contract_address, 'approve', [spender.contract_address, *amount])

    await assert_revert(signer.send_transaction(
        spender, erc20.contract_address, 'transferFrom', [
            account.contract_address,
            ZERO_ADDRESS,
            *amount
        ]),
        reverted_with="ERC20: cannot transfer to the zero address"
    )


@pytest.mark.asyncio
async def test_transferFrom_func_from_zero_address(erc20_factory):
    starknet, erc20, _ = erc20_factory
    spender = await starknet.deploy(
        contract_path("openzeppelin/account/Account.cairo"),
        constructor_calldata=[signer.public_key]
    )
    # we use the same signer to control the main and the spender accounts
    # this is ok since they're still two different accounts
    recipient = 123
    amount = uint(1)

    await assert_revert(signer.send_transaction(
        spender, erc20.contract_address, 'transferFrom', [
            ZERO_ADDRESS,
            recipient,
            *amount
        ]),
        reverted_with="ERC20: transfer amount exceeds allowance"
    )


@pytest.mark.asyncio
async def test_approve_zero_address_spender(erc20_factory):
    _, erc20, account = erc20_factory
    amount = uint(1)
    await assert_revert(signer.send_transaction(
        account, erc20.contract_address, 'approve', [
            ZERO_ADDRESS,
            *amount
        ]),
        reverted_with="ERC20: cannot approve to the zero address"
    )


@pytest.mark.asyncio
async def test_approve_zero_address_caller(erc20_factory):
    _, erc20, _ = erc20_factory
    spender = 123
    amount = uint(345)

    # Without using an account abstraction, the caller address
    # (get_caller_address) is zero
    await assert_revert(
        erc20.approve(spender, amount).invoke(),
        reverted_with="ERC20: zero address cannot approve"
    )
