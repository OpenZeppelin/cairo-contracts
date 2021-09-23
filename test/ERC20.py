import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils import deploy, Signer, build_transaction

signer = Signer(123456789987654321)
L1_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
async def erc20_factory():
    starknet = await Starknet.empty()
    account = await deploy(starknet, "contracts/Account.cairo")
    erc20 = await deploy(starknet, "contracts/token/ERC20.cairo")
    await account.initialize(signer.public_key, L1_ADDRESS).invoke()
    initialize = build_transaction(
        signer, account, erc20.contract_address, 'initialize', [], 0)
    await initialize.invoke()
    return starknet, erc20, account


@pytest.mark.asyncio
async def test_initializer(erc20_factory):
    starknet, erc20, account = erc20_factory
    assert await erc20.balance_of(account.contract_address).call() == (1000,)
    assert await erc20.get_total_supply().call() == (1000,)


@pytest.mark.asyncio
async def test_transfer(erc20_factory):
    starknet, erc20, account = erc20_factory
    recipient = 123
    amount = 100
    assert await erc20.balance_of(account.contract_address).call() == (1000,)
    assert await erc20.balance_of(recipient).call() == (0,)
    transfer = build_transaction(
        signer, account, erc20.contract_address, 'transfer', [recipient, amount], 1)
    await transfer.invoke()
    assert await erc20.balance_of(account.contract_address).call() == (900,)
    assert await erc20.balance_of(recipient).call() == (100,)
