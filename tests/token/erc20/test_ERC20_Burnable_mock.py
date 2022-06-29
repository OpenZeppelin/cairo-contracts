import pytest
from starkware.starknet.testing.starknet import Starknet
from signers import MockSigner
from utils import (
    to_uint, add_uint, sub_uint, str_to_felt, ZERO_ADDRESS, INVALID_UINT256,
    get_contract_class, cached_contract, assert_revert, assert_event_emitted
)


signer = MockSigner(123456789987654321)

# testing vars
INIT_SUPPLY = to_uint(1000)
AMOUNT = to_uint(200)
UINT_ONE = to_uint(1)
NAME = str_to_felt("Mintable Token")
SYMBOL = str_to_felt("MTKN")
DECIMALS = 18


@pytest.fixture(scope='module')
def contract_classes():
    account_cls = get_contract_class('openzeppelin/account/Account.cairo')
    erc20_cls = get_contract_class(
        'tests/mocks/ERC20_Burnable_mock.cairo')

    return account_cls, erc20_cls


@pytest.fixture(scope='module')
async def erc20_init(contract_classes):
    account_cls, erc20_cls = contract_classes
    starknet = await Starknet.empty()
    account1 = await starknet.deploy(
        contract_class=account_cls,
        constructor_calldata=[signer.public_key]
    )
    erc20 = await starknet.deploy(
        contract_class=erc20_cls,
        constructor_calldata=[
            NAME,
            SYMBOL,
            DECIMALS,
            *INIT_SUPPLY,
            account1.contract_address,        # recipient
        ]
    )
    return (
        starknet.state,
        account1,
        erc20
    )


@pytest.fixture
def erc20_factory(contract_classes, erc20_init):
    account_cls, erc20_cls = contract_classes
    state, account1, erc20 = erc20_init
    _state = state.copy()
    account1 = cached_contract(_state, account_cls, account1)
    erc20 = cached_contract(_state, erc20_cls, erc20)

    return erc20, account1


@pytest.mark.asyncio
async def test_burn(erc20_factory):
    erc20, account = erc20_factory

    await signer.send_transaction(
        account, erc20.contract_address, 'burn', [
            *AMOUNT
        ])

    new_balance = sub_uint(INIT_SUPPLY, AMOUNT)

    execution_info = await erc20.balanceOf(account.contract_address).invoke()
    assert execution_info.result.balance == new_balance


@pytest.mark.asyncio
async def test_burn_emits_event(erc20_factory):
    erc20, account = erc20_factory

    tx_exec_info = await signer.send_transaction(
        account, erc20.contract_address, 'burn', [
            *AMOUNT
        ])

    assert_event_emitted(
        tx_exec_info,
        from_address=erc20.contract_address,
        name='Transfer',
        data=[
            account.contract_address,
            ZERO_ADDRESS,
            *AMOUNT
        ]
    )


@pytest.mark.asyncio
async def test_burn_not_enough_balance(erc20_factory):
    erc20, account = erc20_factory

    balance_plus_one = add_uint(INIT_SUPPLY, UINT_ONE)

    await assert_revert(signer.send_transaction(
        account, erc20.contract_address, 'burn', [
            *balance_plus_one
        ]),
        reverted_with="ERC20: burn amount exceeds balance"
    )


@pytest.mark.asyncio
async def test_burn_from_zero_address(erc20_factory):
    erc20, _ = erc20_factory

    await assert_revert(
        erc20.burn(UINT_ONE).invoke(),
        reverted_with="ERC20: cannot burn from the zero address"
    )


@pytest.mark.asyncio
async def test_burn_invalid_uint256(erc20_factory):
    erc20, _ = erc20_factory

    await assert_revert(
        erc20.burn(INVALID_UINT256).invoke(),
        reverted_with="ERC20: amount is not a valid Uint256"
    )
