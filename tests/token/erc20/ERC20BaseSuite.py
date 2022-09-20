import pytest
from signers import MockSigner
from utils import (
    to_uint, add_uint, sub_uint, str_to_felt, MAX_UINT256, ZERO_ADDRESS,
    INVALID_UINT256, TRUE, assert_revert, assert_event_emitted, assert_events_emitted,
    contract_path, State
)


signer = MockSigner(123456789987654321)

# testing vars
NAME = str_to_felt("Token")
SYMBOL = str_to_felt("TKN")
DECIMALS = 18
RECIPIENT = 123
INIT_SUPPLY = to_uint(1000)
AMOUNT = to_uint(200)
UINT_ONE = to_uint(1)
UINT_ZERO = to_uint(0)



class ERC20Base:
    #
    # Constructor
    #

    @pytest.mark.asyncio
    async def test_constructor(self, contract_factory):
        erc20, account, _ = contract_factory

        # balanceOf recipient
        execution_info = await erc20.balanceOf(account.contract_address).execute()
        assert execution_info.result.balance == INIT_SUPPLY

        # totalSupply
        execution_info = await erc20.totalSupply().execute()
        assert execution_info.result.totalSupply == INIT_SUPPLY


    @pytest.mark.asyncio
    async def test_constructor_exceed_max_decimals(self, contract_factory):
        _, account, _ = contract_factory

        bad_decimals = 2**8 + 1

        starknet = await State.init()
        await assert_revert(
            starknet.deploy(
                contract_path("openzeppelin/token/erc20/presets/ERC20.cairo"),
                constructor_calldata=[
                    NAME,
                    SYMBOL,
                    bad_decimals,
                    *INIT_SUPPLY,
                    account.contract_address
                ]),
            reverted_with="ERC20: decimals exceed 2^8"
        )


    @pytest.mark.asyncio
    async def test_name(self, contract_factory):
        erc20, _, _ = contract_factory
        execution_info = await erc20.name().execute()
        assert execution_info.result.name == NAME


    @pytest.mark.asyncio
    async def test_symbol(self, contract_factory):
        erc20, _, _ = contract_factory
        execution_info = await erc20.symbol().execute()
        assert execution_info.result.symbol == SYMBOL


    @pytest.mark.asyncio
    async def test_decimals(self, contract_factory):
        erc20, _, _ = contract_factory
        execution_info = await erc20.decimals().execute()
        assert execution_info.result.decimals == DECIMALS


    #
    # approve
    #


    @pytest.mark.asyncio
    async def test_approve(self, contract_factory):
        erc20, account, spender = contract_factory

        # check spender's allowance starts at zero

        execution_info = await erc20.allowance(account.contract_address, spender.contract_address).execute()
        assert execution_info.result.remaining == UINT_ZERO

        # set approval
        return_bool = await signer.send_transaction(
            account, erc20.contract_address, 'approve', [
                spender.contract_address,
                *AMOUNT
            ]
        )
        assert return_bool.call_info.retdata[1] == TRUE

        # check spender's allowance
        execution_info = await erc20.allowance(account.contract_address, spender.contract_address).execute()
        assert execution_info.result.remaining == AMOUNT



    @pytest.mark.asyncio
    async def test_approve_emits_event(self, contract_factory):
        erc20, account, spender = contract_factory

        tx_exec_info = await signer.send_transaction(
            account, erc20.contract_address, 'approve', [
                spender.contract_address,
                *AMOUNT
            ])

        assert_event_emitted(
            tx_exec_info,
            from_address=erc20.contract_address,
            name='Approval',
            data=[
                account.contract_address,
                spender.contract_address,
                *AMOUNT
            ]
        )


    @pytest.mark.asyncio
    async def test_approve_from_zero_address(self, contract_factory):
        erc20, _, spender = contract_factory

        # Without using an account abstraction, the caller address
        # (get_caller_address) is zero
        await assert_revert(
            erc20.approve(spender.contract_address, AMOUNT).execute(),
            reverted_with="ERC20: cannot approve from the zero address"
        )


    @pytest.mark.asyncio
    async def test_approve_to_zero_address(self, contract_factory):
        erc20, account, _ = contract_factory

        await assert_revert(signer.send_transaction(
            account, erc20.contract_address, 'approve', [
                ZERO_ADDRESS,
                *UINT_ONE
            ]),
            reverted_with="ERC20: cannot approve to the zero address"
        )


    @pytest.mark.asyncio
    async def test_approve_invalid_uint256(self, contract_factory):
        erc20, account, spender = contract_factory

        await assert_revert(
            signer.send_transaction(
                account, erc20.contract_address, 'approve', [
                    spender.contract_address,
                    *INVALID_UINT256
                ]),
            reverted_with="ERC20: amount is not a valid Uint256"
        )


    #
    # transfer
    #


    @pytest.mark.asyncio
    async def test_transfer(self, contract_factory):
        erc20, account, _ = contract_factory

        # check original totalSupply
        execution_info = await erc20.balanceOf(account.contract_address).execute()
        assert execution_info.result.balance == INIT_SUPPLY

        # check recipient original balance
        execution_info = await erc20.balanceOf(RECIPIENT).execute()
        assert execution_info.result.balance == UINT_ZERO

        # transfer
        return_bool = await signer.send_transaction(
            account, erc20.contract_address, 'transfer', [
                RECIPIENT,
                *AMOUNT
            ]
        )
        assert return_bool.call_info.retdata[1] == TRUE

        # check account balance
        execution_info = await erc20.balanceOf(account.contract_address).execute()
        assert execution_info.result.balance == sub_uint(INIT_SUPPLY, AMOUNT)

        # check recipient balance
        execution_info = await erc20.balanceOf(RECIPIENT).execute()
        assert execution_info.result.balance == AMOUNT

        # check totalSupply
        execution_info = await erc20.totalSupply().execute()
        assert execution_info.result.totalSupply == INIT_SUPPLY


    @pytest.mark.asyncio
    async def test_transfer_emits_event(self, contract_factory):
        erc20, account, _ = contract_factory

        tx_exec_info = await signer.send_transaction(
            account, erc20.contract_address, 'transfer', [
                RECIPIENT,
                *AMOUNT
            ])

        assert_event_emitted(
            tx_exec_info,
            from_address=erc20.contract_address,
            name='Transfer',
            data=[
                account.contract_address,
                RECIPIENT,
                *AMOUNT
            ]
        )


    @pytest.mark.asyncio
    async def test_transfer_not_enough_balance(self, contract_factory):
        erc20, account, _ = contract_factory

        await assert_revert(signer.send_transaction(
            account, erc20.contract_address, 'transfer', [
                RECIPIENT,
                *add_uint(INIT_SUPPLY, UINT_ONE)
            ]),
            reverted_with="ERC20: transfer amount exceeds balance"
        )


    @pytest.mark.asyncio
    async def test_transfer_to_zero_address(self, contract_factory):
        erc20, account, _ = contract_factory

        await assert_revert(signer.send_transaction(
            account, erc20.contract_address, 'transfer', [
                ZERO_ADDRESS,
                *UINT_ONE
            ]),
            reverted_with="ERC20: cannot transfer to the zero address"
        )


    @pytest.mark.asyncio
    async def test_transfer_from_zero_address(self, contract_factory):
        erc20, _, _ = contract_factory

        # Without using an account abstraction, the caller address
        # (get_caller_address) is zero
        await assert_revert(
            erc20.transfer(RECIPIENT, UINT_ONE).execute(),
            reverted_with="ERC20: cannot transfer from the zero address"
        )


    @pytest.mark.asyncio
    async def test_transfer_invalid_uint256(self, contract_factory):
        erc20, account, _ = contract_factory

        await assert_revert(signer.send_transaction(
            account, erc20.contract_address, 'transfer', [
                RECIPIENT,
                *INVALID_UINT256
            ]),
            reverted_with="ERC20: amount is not a valid Uint256"
        )


    #
    # transferFrom
    #


    @pytest.mark.asyncio
    async def test_transferFrom(self, contract_factory):
        erc20, account, spender = contract_factory

        # approve
        await signer.send_transaction(
            account, erc20.contract_address, 'approve', [
                spender.contract_address,
                *AMOUNT
            ]
        )
        # transferFrom
        return_bool = await signer.send_transaction(
            spender, erc20.contract_address, 'transferFrom', [
                account.contract_address,
                RECIPIENT,
                *AMOUNT
            ]
        )
        assert return_bool.call_info.retdata[1] == TRUE

        # check account balance
        execution_info = await erc20.balanceOf(account.contract_address).execute()
        assert execution_info.result.balance == sub_uint(INIT_SUPPLY, AMOUNT)

        # check recipient balance
        execution_info = await erc20.balanceOf(RECIPIENT).execute()
        assert execution_info.result.balance == AMOUNT

        # check spender allowance after tx
        execution_info = await erc20.allowance(account.contract_address, spender.contract_address).execute()
        assert execution_info.result.remaining == UINT_ZERO


    @pytest.mark.asyncio
    async def test_transferFrom_emits_event(self, contract_factory):
        erc20, account, spender = contract_factory

        # approve
        await signer.send_transaction(
            account, erc20.contract_address, 'approve', [
                spender.contract_address,
                *AMOUNT
            ])

        # transferFrom
        tx_exec_info = await signer.send_transaction(
            spender, erc20.contract_address, 'transferFrom', [
                account.contract_address,
                RECIPIENT,
                *AMOUNT
            ])

        # check events
        assert_events_emitted(
            tx_exec_info,
            [
                [0, erc20.contract_address, 'Approval', [
                    account.contract_address, spender.contract_address, *UINT_ZERO]],
                [1, erc20.contract_address, 'Transfer', [
                        account.contract_address, RECIPIENT, *AMOUNT]]
            ]
        )


    async def test_transferFrom_doesnt_consume_infinite_allowance(self, contract_factory):
        erc20, account, spender = contract_factory

        # approve
        await signer.send_transaction(account, erc20.contract_address, 'approve', [spender.contract_address, *MAX_UINT256])

        # check approval
        execution_info_1 = await erc20.allowance(account.contract_address, spender.contract_address).call()
        assert execution_info_1.result.remaining == MAX_UINT256

        # transferFrom
        await signer.send_transaction(
            spender, erc20.contract_address, 'transferFrom', [
                account.contract_address,
                RECIPIENT,
                *AMOUNT
            ])

        # re-check approval
        execution_info_2 = await erc20.allowance(account.contract_address, spender.contract_address).call()
        assert execution_info_2.result.remaining == MAX_UINT256


    @pytest.mark.asyncio
    async def test_transferFrom_greater_than_allowance(self, contract_factory):
        erc20, account, spender = contract_factory
        # we use the same signer to control the main and the spender accounts
        # this is ok since they're still two different accounts

        await signer.send_transaction(
            account, erc20.contract_address, 'approve', [
                spender.contract_address,
                *AMOUNT
            ]
        )

        fail_amount = add_uint(AMOUNT, UINT_ONE)

        # increasing the transfer amount above allowance
        await assert_revert(signer.send_transaction(
            spender, erc20.contract_address, 'transferFrom', [
                account.contract_address,
                RECIPIENT,
                *fail_amount
            ]),
            reverted_with="ERC20: insufficient allowance"
        )


    @pytest.mark.asyncio
    async def test_transferFrom_from_zero_address(self, contract_factory):
        erc20, _, spender = contract_factory

        await assert_revert(signer.send_transaction(
            spender, erc20.contract_address, 'transferFrom', [
                ZERO_ADDRESS,
                RECIPIENT,
                *AMOUNT
            ]),
            reverted_with="ERC20: insufficient allowance"
        )


    @pytest.mark.asyncio
    async def test_transferFrom_to_zero_address(self, contract_factory):
        erc20, account, spender = contract_factory

        await signer.send_transaction(
            account, erc20.contract_address, 'approve', [
                spender.contract_address,
                *UINT_ONE
            ]
        )

        await assert_revert(signer.send_transaction(
            spender, erc20.contract_address, 'transferFrom', [
                account.contract_address,
                ZERO_ADDRESS,
                *UINT_ONE
            ]),
            reverted_with="ERC20: cannot transfer to the zero address"
        )


    #
    # increaseAllowance
    #


    @pytest.mark.asyncio
    async def test_increaseAllowance(self, contract_factory):
        erc20, account, spender = contract_factory

        execution_info = await erc20.allowance(account.contract_address, spender.contract_address).execute()
        assert execution_info.result.remaining == UINT_ZERO

        # set approve
        await signer.send_transaction(
            account, erc20.contract_address, 'approve', [
                spender.contract_address,
                *AMOUNT
            ]
        )

        # check allowance
        execution_info = await erc20.allowance(account.contract_address, spender.contract_address).execute()
        assert execution_info.result.remaining == AMOUNT

        # increase allowance
        return_bool = await signer.send_transaction(
            account, erc20.contract_address, 'increaseAllowance', [
                spender.contract_address,
                *AMOUNT
            ]
        )
        assert return_bool.call_info.retdata[1] == TRUE

        # check spender's allowance increased
        execution_info = await erc20.allowance(account.contract_address, spender.contract_address).execute()
        assert execution_info.result.remaining == add_uint(AMOUNT, AMOUNT)


    @pytest.mark.asyncio
    async def test_increaseAllowance_emits_event(self, contract_factory):
        erc20, account, spender = contract_factory

        # set approve
        await signer.send_transaction(
            account, erc20.contract_address, 'approve', [
                spender.contract_address,
                *AMOUNT
            ])

        # increase allowance
        tx_exec_info = await signer.send_transaction(
            account, erc20.contract_address, 'increaseAllowance', [
                spender.contract_address,
                *AMOUNT
            ])

        new_allowance = add_uint(AMOUNT, AMOUNT)

        assert_event_emitted(
            tx_exec_info,
            from_address=erc20.contract_address,
            name='Approval',
            data=[
                account.contract_address,
                spender.contract_address,
                *new_allowance
            ]
        )


    @pytest.mark.asyncio
    async def test_increaseAllowance_overflow(self, contract_factory):
        erc20, account, spender = contract_factory

        # approve max
        await signer.send_transaction(
            account, erc20.contract_address, 'approve', [
                spender.contract_address,
                *MAX_UINT256
            ]
        )

        # overflow_amount adds (1, 0) to (2**128 - 1, 2**128 - 1)
        await assert_revert(signer.send_transaction(
            account, erc20.contract_address, 'increaseAllowance', [
                spender.contract_address,
                *UINT_ONE
            ]),
            reverted_with="ERC20: allowance overflow"
        )


    @pytest.mark.asyncio
    async def test_increaseAllowance_to_zero_address(self, contract_factory):
        erc20, account, spender = contract_factory

        await signer.send_transaction(
            account, erc20.contract_address, 'approve', [
                spender.contract_address,
                *AMOUNT
            ]
        )

        await assert_revert(signer.send_transaction(
            account, erc20.contract_address, 'increaseAllowance', [
                ZERO_ADDRESS,
                *AMOUNT
            ])
        )


    @pytest.mark.asyncio
    async def test_increaseAllowance_from_zero_address(self, contract_factory):
        erc20, account, spender = contract_factory

        await signer.send_transaction(
            account, erc20.contract_address, 'approve', [
                spender.contract_address,
                *AMOUNT
            ]
        )

        await assert_revert(
            erc20.increaseAllowance(RECIPIENT, AMOUNT).execute()
        )


    #
    # decreaseAllowance
    #


    @pytest.mark.asyncio
    async def test_decreaseAllowance(self, contract_factory):
        erc20, account, spender = contract_factory

        execution_info = await erc20.allowance(account.contract_address, spender.contract_address).execute()
        assert execution_info.result.remaining == UINT_ZERO

        # set approve
        await signer.send_transaction(
            account, erc20.contract_address, 'approve', [
                spender.contract_address,
                *AMOUNT
            ]
        )

        execution_info = await erc20.allowance(account.contract_address, spender.contract_address).execute()
        assert execution_info.result.remaining == AMOUNT

        # decrease allowance
        return_bool = await signer.send_transaction(
            account, erc20.contract_address, 'decreaseAllowance', [
                spender.contract_address,
                *UINT_ONE
            ]
        )
        assert return_bool.call_info.retdata[1] == TRUE

        new_allowance = sub_uint(AMOUNT, UINT_ONE)

        execution_info = await erc20.allowance(account.contract_address, spender.contract_address).execute()
        assert execution_info.result.remaining == new_allowance


    @pytest.mark.asyncio
    async def test_decreaseAllowance_emits_event(self, contract_factory):
        erc20, account, spender = contract_factory

        # set approve
        await signer.send_transaction(
            account, erc20.contract_address, 'approve', [
                spender.contract_address,
                *INIT_SUPPLY
            ])

        # decrease allowance
        tx_exec_info = await signer.send_transaction(
            account, erc20.contract_address, 'decreaseAllowance', [
                spender.contract_address,
                *AMOUNT
            ])

        new_allowance = sub_uint(INIT_SUPPLY, AMOUNT)

        assert_event_emitted(
            tx_exec_info,
            from_address=erc20.contract_address,
            name='Approval',
            data=[
                account.contract_address,
                spender.contract_address,
                *new_allowance
            ]
        )


    @pytest.mark.asyncio
    async def test_decreaseAllowance_overflow(self, contract_factory):
        erc20, account, spender = contract_factory

        await signer.send_transaction(
            account, erc20.contract_address, 'approve', [
                spender.contract_address,
                *AMOUNT
            ]
        )

        execution_info = await erc20.allowance(account.contract_address, spender.contract_address).execute()
        assert execution_info.result.remaining == AMOUNT

        allowance_plus_one = add_uint(AMOUNT, UINT_ONE)

        # increasing the decreased allowance amount by more than the spender's allowance
        await assert_revert(signer.send_transaction(
            account, erc20.contract_address, 'decreaseAllowance', [
                spender.contract_address,
                *allowance_plus_one
            ]),
            reverted_with="ERC20: allowance below zero"
        )


    @pytest.mark.asyncio
    async def test_decreaseAllowance_to_zero_address(self, contract_factory):
        erc20, account, spender = contract_factory

        await signer.send_transaction(
            account, erc20.contract_address, 'approve', [
                spender.contract_address,
                *AMOUNT
            ]
        )

        await assert_revert(signer.send_transaction(
            account, erc20.contract_address, 'decreaseAllowance', [
                ZERO_ADDRESS,
                *AMOUNT
            ])
        )


    @pytest.mark.asyncio
    async def test_decreaseAllowance_from_zero_address(self, contract_factory):
        erc20, account, spender = contract_factory

        await signer.send_transaction(
            account, erc20.contract_address, 'approve', [
                spender.contract_address,
                *AMOUNT
            ]
        )

        await assert_revert(
            erc20.decreaseAllowance(RECIPIENT, AMOUNT).execute()
        )


    @pytest.mark.asyncio
    async def test_decreaseAllowance_invalid_uint256(self, contract_factory):
        erc20, account, spender = contract_factory

        await assert_revert(
            signer.send_transaction(
                account, erc20.contract_address, 'decreaseAllowance', [
                    spender.contract_address,
                    *INVALID_UINT256
                ]),
            reverted_with="ERC20: subtracted_value is not a valid Uint256"
        )
