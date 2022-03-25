import pytest
import asyncio
from starkware.starknet.public.abi import get_selector_from_name
from starkware.starknet.testing.starknet import Starknet
from utils import (
    Signer, to_uint, str_to_felt, ZERO_ADDRESS, INVALID_UINT256,
    assert_event_emitted, assert_revert, sub_uint, add_uint,
    contract_path
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
        contract_path("tests/mocks/ERC20_Burnable_mock.cairo"),
        constructor_calldata=[
            str_to_felt("Token"),      # name
            str_to_felt("TKN"),        # symbol
            18,                        # decimals
            *to_uint(1000),            # initial_supply
            account.contract_address   # recipient
        ]
    )
    return starknet, erc20, account


@pytest.mark.asyncio
async def test_burn(erc20_factory):
    _, erc20, account = erc20_factory
    amount = to_uint(100)

    execution_info = await erc20.balanceOf(account.contract_address).invoke()
    init_balance = execution_info.result.balance

    await signer.send_transaction(
        account, erc20.contract_address, 'burn', [
            *amount
        ])

    execution_info = await erc20.balanceOf(account.contract_address).invoke()
    new_balance = execution_info.result.balance

    assert sub_uint(init_balance, amount) == new_balance


@pytest.mark.asyncio
async def test_burn_emits_event(erc20_factory):
    _, erc20, account = erc20_factory
    amount = to_uint(100)

    tx_exec_info = await signer.send_transaction(
        account, erc20.contract_address, 'burn', [
            *amount
        ])

    assert_event_emitted(
        tx_exec_info,
        from_address=erc20.contract_address,
        name='Transfer',
        data=[
            account.contract_address,
            ZERO_ADDRESS,
            *amount
        ]
    )


@pytest.mark.asyncio
async def test_burn_not_enough_balance(erc20_factory):
    _, erc20, account = erc20_factory

    execution_info = await erc20.balanceOf(account.contract_address).invoke()
    amount = execution_info.result.balance

    await assert_revert(signer.send_transaction(
        account, erc20.contract_address, 'burn', [
            *add_uint(amount, to_uint(1))
        ]),
        reverted_with="ERC20: burn amount exceeds balance"
    )


@pytest.mark.asyncio
async def test_burn_from_zero_address(erc20_factory):
    _, erc20, _ = erc20_factory
    amount = to_uint(1)

    await assert_revert(
        erc20.burn(amount).invoke(),
        reverted_with="ERC20: cannot burn from the zero address"
    )


@pytest.mark.asyncio
async def test_burn_invalid_uint256(erc20_factory):
    _, erc20, _ = erc20_factory

    await assert_revert(
        erc20.burn(INVALID_UINT256).invoke(),
        reverted_with="ERC20: amount is not a valid Uint256"
    )
