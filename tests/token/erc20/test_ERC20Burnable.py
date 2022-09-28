import pytest
from signers import MockSigner
from utils import (
    add_uint, sub_uint, ZERO_ADDRESS, INVALID_UINT256,
    get_contract_class, cached_contract, assert_revert, assert_event_emitted,
    assert_events_emitted, State, Account
)
from ERC20BaseSuite import (
    ERC20Base, NAME, SYMBOL, DECIMALS, INIT_SUPPLY, AMOUNT, UINT_ONE, UINT_ZERO
)


signer = MockSigner(123456789987654321)


@pytest.fixture(scope='module')
def contract_classes():
    account_cls = Account.get_class
    erc20_cls = get_contract_class('ERC20Burnable')

    return account_cls, erc20_cls


@pytest.fixture(scope='module')
async def erc20_init(contract_classes):
    _, erc20_cls = contract_classes
    starknet = await State.init()
    account1 = await Account.deploy(signer.public_key)
    account2 = await Account.deploy(signer.public_key)
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
        account2,
        erc20
    )


@pytest.fixture
def contract_factory(contract_classes, erc20_init):
    account_cls, erc20_cls = contract_classes
    state, account1, account2, erc20 = erc20_init
    _state = state.copy()
    account1 = cached_contract(_state, account_cls, account1)
    account2 = cached_contract(_state, account_cls, account2)
    erc20 = cached_contract(_state, erc20_cls, erc20)

    return erc20, account1, account2


class TestERC20Burnable(ERC20Base):
    #
    # burn
    #

    @pytest.mark.asyncio
    async def test_burn(self, contract_factory):
        erc20, account, _ = contract_factory

        await signer.send_transaction(
            account, erc20.contract_address, 'burn', [
                *AMOUNT
            ])

        new_balance = sub_uint(INIT_SUPPLY, AMOUNT)

        execution_info = await erc20.balanceOf(account.contract_address).execute()
        assert execution_info.result.balance == new_balance


    @pytest.mark.asyncio
    async def test_burn_emits_event(self, contract_factory):
        erc20, account, _ = contract_factory

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
    async def test_burn_not_enough_balance(self, contract_factory):
        erc20, account, _ = contract_factory

        balance_plus_one = add_uint(INIT_SUPPLY, UINT_ONE)

        await assert_revert(signer.send_transaction(
            account, erc20.contract_address, 'burn', [
                *balance_plus_one
            ]),
            reverted_with="ERC20: burn amount exceeds balance"
        )


    @pytest.mark.asyncio
    async def test_burn_from_zero_address(self, contract_factory):
        erc20, _, _ = contract_factory

        await assert_revert(
            erc20.burn(UINT_ONE).execute(),
            reverted_with="ERC20: cannot burn from the zero address"
        )


    @pytest.mark.asyncio
    async def test_burn_invalid_uint256(self, contract_factory):
        erc20, _, _ = contract_factory

        await assert_revert(
            erc20.burn(INVALID_UINT256).execute(),
            reverted_with="ERC20: amount is not a valid Uint256"
        )


    @pytest.mark.asyncio
    async def test_burn_from(self, contract_factory):
        erc20, account1, account2 = contract_factory

        await signer.send_transaction(
            account1, erc20.contract_address, 'increaseAllowance', [
                account2.contract_address,
                *AMOUNT
            ])

        await signer.send_transaction(
            account2, erc20.contract_address, 'burnFrom', [
                account1.contract_address,
                *AMOUNT
            ])

        new_balance = sub_uint(INIT_SUPPLY, AMOUNT)

        execution_info = await erc20.balanceOf(account1.contract_address).execute()
        assert execution_info.result.balance == new_balance


    @pytest.mark.asyncio
    async def test_burn_from_emits_event(self, contract_factory):
        erc20, account1, account2 = contract_factory

        await signer.send_transaction(
            account1, erc20.contract_address, 'increaseAllowance', [
                account2.contract_address,
                *AMOUNT
            ])

        tx_exec_info = await signer.send_transaction(
            account2, erc20.contract_address, 'burnFrom', [
                account1.contract_address,
                *AMOUNT
            ])

        # events
        assert_events_emitted(
            tx_exec_info,
            [
                [0, erc20.contract_address, 'Approval', [
                    account1.contract_address, account2.contract_address, *UINT_ZERO]],
                [1, erc20.contract_address, 'Transfer', [
                    account1.contract_address, ZERO_ADDRESS, *AMOUNT]]
            ]
        )


    @pytest.mark.asyncio
    async def test_burn_from_over_allowance(self, contract_factory):
        erc20, account1, account2 = contract_factory

        await signer.send_transaction(
            account1, erc20.contract_address, 'increaseAllowance', [
                account2.contract_address,
                *AMOUNT
            ])

        await assert_revert(signer.send_transaction(
            account2, erc20.contract_address, 'burnFrom', [
                account1.contract_address,
                *INIT_SUPPLY
            ]),
            reverted_with="ERC20: insufficient allowance"
        )


    @pytest.mark.asyncio
    async def test_burn_from_no_allowance(self, contract_factory):
        erc20, account1, account2 = contract_factory

        await assert_revert(signer.send_transaction(
            account2, erc20.contract_address, 'burnFrom', [
                account1.contract_address,
                *AMOUNT
            ]),
            reverted_with="ERC20: insufficient allowance"
        )
