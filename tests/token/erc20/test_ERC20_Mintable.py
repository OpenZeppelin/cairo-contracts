import pytest
from starkware.starknet.testing.starknet import Starknet
from utils import (
    Signer, uint, str_to_felt, MAX_UINT256, ZERO_ADDRESS, INVALID_UINT256,
    assert_revert, assert_event_emitted, contract_path
)

signer = Signer(123456789987654321)

# random address
RECIPIENT = 789


@pytest.fixture(scope='module')
async def token_factory():
    starknet = await Starknet.empty()
    owner = await starknet.deploy(
        contract_path("openzeppelin/account/Account.cairo"),
        constructor_calldata=[signer.public_key]
    )

    token = await starknet.deploy(
        contract_path("openzeppelin/token/erc20/ERC20_Mintable.cairo"),
        constructor_calldata=[
            str_to_felt("Mintable Token"),
            str_to_felt("MTKN"),
            18,
            *uint(1000),
            owner.contract_address,
            owner.contract_address
        ]
    )
    return starknet, token, owner


@pytest.mark.asyncio
async def test_constructor(token_factory):
    _, token, owner = token_factory

    execution_info = await token.name().invoke()
    assert execution_info.result == (str_to_felt("Mintable Token"),)

    execution_info = await token.symbol().invoke()
    assert execution_info.result == (str_to_felt("MTKN"),)

    execution_info = await token.decimals().invoke()
    assert execution_info.result.decimals == 18

    execution_info = await token.balanceOf(owner.contract_address).invoke()
    assert execution_info.result.balance == uint(1000)


@pytest.mark.asyncio
async def test_mint(token_factory):
    _, erc20, account = token_factory
    amount = uint(1)

    await signer.send_transaction(account, erc20.contract_address, 'mint', [account.contract_address, *amount])

    # check new supply
    execution_info = await erc20.totalSupply().invoke()
    new_supply = execution_info.result.totalSupply
    assert new_supply == uint(1001)


@pytest.mark.asyncio
async def test_mint_emits_event(token_factory):
    _, erc20, account = token_factory
    amount = uint(1)

    tx_exec_info = await signer.send_transaction(
        account, erc20.contract_address, 'mint', [
            account.contract_address,
            *amount
        ])

    assert_event_emitted(
        tx_exec_info,
        from_address=erc20.contract_address,
        name='Transfer',
        data=[
            ZERO_ADDRESS,
            account.contract_address,
            *amount
        ]
    )


@pytest.mark.asyncio
async def test_mint_to_zero_address(token_factory):
    _, erc20, account = token_factory
    amount = uint(1)

    await assert_revert(signer.send_transaction(
        account,
        erc20.contract_address,
        'mint',
        [ZERO_ADDRESS, *amount]),
        reverted_with="ERC20: cannot mint to the zero address"
    )


@pytest.mark.asyncio
async def test_mint_overflow(token_factory):
    _, erc20, account = token_factory
    # fetching the previously minted totalSupply and verifying the overflow check
    # (totalSupply >= 2**256) should fail, (totalSupply < 2**256) should pass
    execution_info = await erc20.totalSupply().invoke()
    previous_supply = execution_info.result.totalSupply

    # pass_amount subtracts the already minted supply from MAX_UINT256 in order for
    # the minted supply to equal MAX_UINT256
    # (2**128 - 1, 2**128 - 1)
    pass_amount = (
        MAX_UINT256[0] - previous_supply[0],  # 2**128 - 1
        MAX_UINT256[1] - previous_supply[1]   # 2**128 - 1
    )

    await signer.send_transaction(account, erc20.contract_address, 'mint', [RECIPIENT, *pass_amount])

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
        [RECIPIENT, *fail_amount]),
        reverted_with="ERC20: mint overflow"
    )


@pytest.mark.asyncio
async def test_mint_invalid_uint256(token_factory):
    _, erc20, account = token_factory

    await assert_revert(signer.send_transaction(
        account,
        erc20.contract_address,
        'mint',
        [RECIPIENT, *INVALID_UINT256]),
        reverted_with="ERC20: amount is not a valid Uint256"
    )
