import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils import Signer, uint, str_to_felt, MAX_UINT256, assert_revert

signer = Signer(123456789987654321)
other = Signer(123456789987654321)

@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
async def ERC1155_factory():
    starknet = await Starknet.empty()
    account = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

    operator = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[other.public_key]
    )

    erc1155 = await starknet.deploy(
        "contracts/token/ERC1155_base.cairo",
        constructor_calldata=[
            account.contract_address,   # recipient
            2,
            1,2,
            2,
            1000,5000
        ]
    )

    return starknet, erc1155, account, operator

# BalanceOf
@pytest.mark.asyncio
async def test_constructor(ERC1155_factory):
    _, erc1155, account, operator = ERC1155_factory

    assert (await erc1155.balanceOf(account.contract_address, 1).call()).result == (1000,)
    assert (await erc1155.balanceOf(account.contract_address, 2).call()).result == (5000,)

# BalanceOfBatch
@pytest.mark.asyncio
async def test_balanceOfBatch(ERC1155_factory):
    _, erc1155, account, operator = ERC1155_factory

    accounts = [account.contract_address, account.contract_address]

    tokenIds = [1,2]

    execution_info = await erc1155.balanceOfBatch(accounts, tokenIds).call()
    assert execution_info.result.res == [1000, 5000]
    assert len(execution_info.result.res) == len(tokenIds)


@pytest.mark.asyncio
async def test_is_approved_for_all(ERC1155_factory):
    _, erc1155, account, operator, = ERC1155_factory


    approval = 1
    not_boolean_approval = 15

    # test set_approval_for_all with value that is not a boolean
    try:
        await signer.send_transaction(account, erc1155.contract_address, 'set_approval_for_all', [operator, not_boolean_approval])
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

    # await signer.send_transaction(account, erc1155.contract_address, 'set_approval_for_all', [operator, approval])
    # assert(await erc1155.is_approved_for_all(account.contract_address, operator).call()).result == (1,)

    # await signer.send_transaction(account, erc1155.contract_address, 'set_approval_for_all', [operator, 0])
    # assert(await erc1155.is_approved_for_all(account.contract_address, operator).call()).result == (0,)


# @pytest.mark.asyncio
# async def test_transfer_from(erc1155_factory):
#     _, erc1155, account, operator = erc1155_factory

#     balance_1_of_other = await erc1155.balance_of(operator.contract_address, 1).call()
#     balance_1_of_from_address = await erc1155.balance_of(account.contract_address, 1).call()
#     assert balance_1_of_other.result.res == 0

#     # Test if Other transfers 1 from Account without approval
#     try:
#         await other.send_transaction(operator, erc1155.contract_address, 'safe_transfer_from', [account.contract_address, operator.contract_address, 1, 1])
#     except StarkException as err:
#         _, error = err.args
#         assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

#     # Setting approval
#     await signer.send_transaction(account, erc1155.contract_address, 'set_approval_for_all', [operator.contract_address, 1])

#     # Test Other transfers 1 from Account after approval
#     await other.send_transaction(operator, erc1155.contract_address, 'safe_transfer_from', [account.contract_address, operator.contract_address, 1, 1])

#     balance_2_of_other = await erc1155.balance_of(operator.contract_address, 1).call()
#     assert balance_2_of_other.result.res == balance_1_of_other.result.res + 1
#     balance_2_of_from_address = await erc1155.balance_of(account.contract_address, 1).call()
#     assert balance_2_of_from_address.result.res == balance_1_of_from_address.result.res - 1

#     # Test Other transfers more tokens than current balance
#     try:
#         await other.send_transaction(operator, erc1155.contract_address, 'safe_transfer_from', [account.contract_address, operator.contract_address, 1, balance_1_of_from_address.result.res])
#     except StarkException as err:
#         _, error = err.args
#         assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

#     # Unsetting approval
#     await signer.send_transaction(account, erc1155.contract_address, 'set_approval_for_all', [operator.contract_address, 0])


# @pytest.mark.asyncio
# async def test_transfer_batch_from(erc1155_factory):
#     _, erc1155, account, operator = erc1155_factory

#     balances_1 = (await erc1155.balance_of_batch([account.contract_address, account.contract_address, operator.contract_address, operator.contract_address], [1, 2, 1, 2]).call()).result.res
#     # amounts to transfer between balances
#     amount1 = 50
#     amount2 = 25

#     operations = [-amount1, -amount2, +amount1, +amount2]
#     #  TEST IF OTHER TOOK 1 FROM ACCOUNT WITHOUT APPROVAL
#     try:
#         await other.send_transaction(operator, erc1155.contract_address, 'safe_batch_transfer_from', [account.contract_address, operator.contract_address, 2, 1, 2, 2, amount1, amount2])
#     except StarkException as err:
#         _, error = err.args
#         assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

#     # SETTING APPROVAL
#     await signer.send_transaction(account, erc1155.contract_address, 'set_approval_for_all', [operator.contract_address, 1])
#     await other.send_transaction(operator, erc1155.contract_address, 'safe_batch_transfer_from', [account.contract_address, operator.contract_address, 2, 1, 2, 2, amount1, amount2])

#     balances_2 = (await erc1155.balance_of_batch([account.contract_address, account.contract_address, operator.contract_address, operator.contract_address], [1, 2, 1, 2]).call()).result.res
#     # Balance 2 = balance 1 with operations made
#     assert balances_2 == [x+y for x, y in zip(balances_1, operations)]

#     # OTHER TAKE TOO MUCH
#     try:
#         await other.send_transaction(operator, erc1155.contract_address, 'safe_batch_transfer_from', [account.contract_address, operator.contract_address, 2, 1, 2, 2, 1000, 1000])
#     except StarkException as err:
#         _, error = err.args
#         assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED

# # To test this function ensure _burn function in contract is set to @external
# @pytest.mark.asyncio
# async def test_burn(erc1155_factory):
#     _, erc1155, account, _, = erc1155_factory
#     token_id = 1
#     amount_to_burn = 10

#     # burn 10 tokens
#     balance_before = (await erc1155.balance_of(account.contract_address, token_id).call()).result.res
#     await signer.send_transaction(account, erc1155.contract_address, '_burn', [account.contract_address, token_id, amount_to_burn])
#     assert (await erc1155.balance_of(account.contract_address, token_id).call()).result.res == balance_before - amount_to_burn

#     # try burning too much tokens
#     try:
#         await signer.send_transaction(account, erc1155.contract_address, '_burn', [account.contract_address, token_id, 5000])
#     except StarkException as err:
#         _, error = err.args
#         assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


# @pytest.mark.asyncio
# async def test_burn_batch(erc1155_factory):

#     _, erc1155, account, operator = erc1155_factory

#     balances_1 = (await erc1155.balance_of_batch([account.contract_address, account.contract_address], [1, 2]).call()).result.res
#     # amounts to transfer between balances
#     amount1 = 50
#     amount2 = 25

#     operations = [-amount1, -amount2]

#     await signer.send_transaction(account, erc1155.contract_address, '_burn_batch', [account.contract_address, 2, 1, 2, 2, amount1, amount2])

#     balances_2 = (await erc1155.balance_of_batch([account.contract_address, account.contract_address], [1, 2]).call()).result.res
#     # Balance 2 = balance 1 with operations made
#     assert balances_2 == [x+y for x, y in zip(balances_1, operations)]

#     # Other burns more tokens than current balance
#     try:
#         await other.send_transaction(account, erc1155.contract_address, '_burn_batch', [account.contract_address, 2, 1, 2, 2, 1000, 1000])
#     except StarkException as err:
#         _, error = err.args
#         assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED