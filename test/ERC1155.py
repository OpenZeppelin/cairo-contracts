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
async def erc1155_factory():
    starknet = await Starknet.empty()
    account = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

    await account.initialize(account.contract_address).invoke()

    # Initialize ERC1155 contract with token_id => 1 : 1000 / 2 : 500
    erc1155 = await starknet.deploy(
        "contracts/token/ERC1155.cairo",
        constructor_calldata=[account.contract_address, 2, 1, 2, 2, 1000, 500]
    )
    return starknet, erc1155, account

@pytest.mark.asyncio
async def test_constructor(erc1155_factory):
    _, erc1155, account = erc1155_factory

    assert (await erc1155.balance_of(account.contract_address, 1).call()).result == (1000,)
    assert (await erc1155.balance_of(account.contract_address, 2).call()).result == (500,)

@pytest.mark.asyncio
async def test_balance_of_batch(erc1155_factory):
    _, erc1155, account = erc1155_factory

    accounts = [account.contract_address,account.contract_address,account.contract_address]
    token_ids = [2,1,1]

    execution_info = await erc1155.balance_of_batch(accounts, token_ids).call()
    assert execution_info.result.res == [500, 1000, 1000]
    assert len(execution_info.result.res) == len(token_ids)

# @pytest.mark.asyncio
# async def test_transfer(erc1155_factory):
#     _, erc1155, account = erc1155_factory
#     recipient = 123
#     token_id = 1
#     amount = 100

#     execution_info = await erc1155.get_total_supply(token_id).call()
#     previous_supply = execution_info.result

#     assert (await erc1155.balance_of(account.contract_address, token_id).call()).result == (1000,)
#     assert (await erc1155.balance_of(recipient, token_id).call()).result == (0,)

#     await signer.send_transaction(account, erc1155.contract_address, 'transfer', [recipient, token_id, amount])
#     assert (await erc1155.balance_of(account.contract_address, token_id).call()).result == (900,)
#     assert (await erc1155.balance_of(recipient, token_id).call()).result == (100,)

#     assert (await erc1155.get_total_supply(token_id).call()).result == previous_supply

# @pytest.mark.asyncio
# async def test_transfer_batch(erc1155_factory):
#     _, erc1155, account = erc1155_factory
#     recipient = 123
#     token_id = [1,2]

#     supply1 = await erc1155.get_total_supply(token_id[0]).call()
#     supply2 = await erc1155.get_total_supply(token_id[1]).call()
#     previous_supply = [supply1.result, supply2.result]

#     assert (await erc1155.balance_of(account.contract_address, token_id[0]).call()).result == (1000,)
#     assert (await erc1155.balance_of(recipient, token_id[0]).call()).result == (0,)

#     assert (await erc1155.balance_of(account.contract_address, token_id[1]).call()).result == (500,)
#     assert (await erc1155.balance_of(recipient, token_id[1]).call()).result == (0,)

#     await signer.send_transaction(account, erc1155.contract_address, 'transfer_batch', [recipient, 2, 1, 2, 2, 100, 50])

#     assert (await erc1155.balance_of(account.contract_address, token_id[0]).call()).result == (900,)
#     assert (await erc1155.balance_of(recipient, token_id[0]).call()).result == (100,)

#     assert (await erc1155.balance_of(account.contract_address, token_id[1]).call()).result == (450,)
#     assert (await erc1155.balance_of(recipient, token_id[1]).call()).result == (50,)

#     assert (await erc1155.get_total_supply(token_id[0]).call()).result == previous_supply[0]
#     assert (await erc1155.get_total_supply(token_id[1]).call()).result == previous_supply[1]


# @pytest.mark.asyncio
# async def test_insufficient_sender_balance(erc1155_factory):
#     _, erc1155, account = erc1155_factory
#     recipient = 123

#     try:
#         await signer.send_transaction(account, erc1155.contract_address, 'transfer_batch', [recipient, 2, 1, 2, 2, 1001, 50])
#         assert False
#     except StarkException as err:
#         _, error = err.args
#         assert error['code'] == StarknetErrorCode.TRANSACTION_FAILED


@pytest.mark.asyncio
async def test_is_approved(erc1155_factory):
    _, erc1155, account = erc1155_factory

    operator = 123
    approval = 1
    # try:
    # overflow check will revert the transaction
    await signer.send_transaction(account, erc1155.contract_address, 'set_approval_for_all', [operator, approval])
    execution_info = await erc1155.is_approved_for_all(account.contract_address, operator).call()
    assert execution_info.result.res == 1
    await signer.send_transaction(account, erc1155.contract_address, 'set_approval_for_all', [operator, 0])
    execution_info = await erc1155.is_approved_for_all(account.contract_address, operator).call()
    assert execution_info.result.res == 0
