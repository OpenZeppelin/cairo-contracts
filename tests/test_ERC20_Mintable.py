import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils import Signer, uint, str_to_felt, MAX_UINT256, assert_revert

signer = Signer(123456789987654321)


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
async def token_factory():
    starknet = await Starknet.empty()
    owner = await starknet.deploy(
        "contracts/Account.cairo",
        constructor_calldata=[signer.public_key]
    )

    token = await starknet.deploy(
        "contracts/token/ERC20_Mintable.cairo",
        constructor_calldata=[
            str_to_felt("Mintable Token"),
            str_to_felt("MTKN"),
            *uint(1000),
            owner.contract_address,
            owner.contract_address
        ]
    )
    return starknet, token, owner


@pytest.mark.asyncio
async def test_constructor(token_factory):
    _, token, owner = token_factory

    execution_info = await token.name().call()
    assert execution_info.result == (str_to_felt("Mintable Token"),)

    execution_info = await token.symbol().call()
    assert execution_info.result == (str_to_felt("MTKN"),)

    execution_info = await token.balanceOf(owner.contract_address).call()
    assert execution_info.result.balance == uint(1000)


@pytest.mark.asyncio
async def test_mint(token_factory):
    _, erc20, account = token_factory
    amount = uint(1)

    await signer.send_transaction(account, erc20.contract_address, 'mint', [account.contract_address, *amount])

    # check new supply
    execution_info = await erc20.totalSupply().call()
    new_supply = execution_info.result.totalSupply
    assert new_supply == uint(1001)


@pytest.mark.asyncio
async def test_mint_to_zero_address(token_factory):
    _, erc20, account = token_factory
    zero_address = 0
    amount = uint(1)

    await assert_revert(signer.send_transaction(
        account,
        erc20.contract_address,
        'mint',
        [zero_address, *amount]
    ))


@pytest.mark.asyncio
async def test_mint_overflow(token_factory):
    _, erc20, account = token_factory
    recipient = 789
    # fetching the previously minted totalSupply and verifying the overflow check
    # (totalSupply >= 2**256) should fail, (totalSupply < 2**256) should pass
    execution_info = await erc20.totalSupply().call()
    previous_supply = execution_info.result.totalSupply

    # pass_amount subtracts the already minted supply from MAX_UINT256 in order for
    # the minted supply to equal MAX_UINT256
    # (2**128 - 1, 2**128 - 1)
    pass_amount = (
        MAX_UINT256[0] - previous_supply[0],  # 2**128 - 1
        MAX_UINT256[1] - previous_supply[1]   # 2**128 - 1
    )

    await signer.send_transaction(account, erc20.contract_address, 'mint', [recipient, *pass_amount])

    # fail_amount displays the edge case where any addition over MAX_SUPPLY
    # should result in a failing tx
    fail_amount = (
        pass_amount[0] + 1,  # 2**128 (will overflow)
        pass_amount[1]       # 2**128 - 1
    )

    await assert_revert(signer.send_transaction(
        account,
        erc20.contract_address,
        'mint',
        [recipient, *fail_amount]
    ))
