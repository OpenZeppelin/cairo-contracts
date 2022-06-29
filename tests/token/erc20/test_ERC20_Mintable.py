import pytest
from starkware.starknet.testing.starknet import Starknet
from signers import MockSigner
from utils import (
    to_uint, add_uint, sub_uint, str_to_felt, 
    MAX_UINT256, ZERO_ADDRESS, INVALID_UINT256, get_contract_class, 
    cached_contract, assert_revert, assert_event_emitted
)


signer = MockSigner(123456789987654321)

# testing vars
RECIPIENT = 123
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
        'openzeppelin/token/erc20/ERC20_Mintable.cairo')

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
            account1.contract_address         # owner
        ]
    )
    return (
        starknet.state,
        account1,
        erc20
    )


@pytest.fixture
def token_factory(contract_classes, erc20_init):
    account_cls, erc20_cls = contract_classes
    state, account1, erc20 = erc20_init
    _state = state.copy()
    account1 = cached_contract(_state, account_cls, account1)
    erc20 = cached_contract(_state, erc20_cls, erc20)

    return erc20, account1


@pytest.mark.asyncio
async def test_constructor(token_factory):
    token, owner = token_factory

    execution_info = await token.name().call()
    assert execution_info.result.name == NAME

    execution_info = await token.symbol().call()
    assert execution_info.result.symbol == SYMBOL

    execution_info = await token.decimals().call()
    assert execution_info.result.decimals == DECIMALS

    execution_info = await token.balanceOf(owner.contract_address).call()
    assert execution_info.result.balance == INIT_SUPPLY


@pytest.mark.asyncio
async def test_mint(token_factory):
    erc20, account = token_factory

    await signer.send_transaction(
        account, erc20.contract_address, 'mint', [
            account.contract_address,
            *UINT_ONE
        ])

    # check new supply
    execution_info = await erc20.totalSupply().invoke()
    new_supply = execution_info.result.totalSupply
    assert new_supply == add_uint(INIT_SUPPLY, UINT_ONE)


@pytest.mark.asyncio
async def test_mint_emits_event(token_factory):
    erc20, account = token_factory

    tx_exec_info = await signer.send_transaction(
        account, erc20.contract_address, 'mint', [
            account.contract_address,
            *UINT_ONE
        ])

    assert_event_emitted(
        tx_exec_info,
        from_address=erc20.contract_address,
        name='Transfer',
        data=[
            ZERO_ADDRESS,
            account.contract_address,
            *UINT_ONE
        ]
    )


@pytest.mark.asyncio
async def test_mint_to_zero_address(token_factory):
    erc20, account = token_factory

    await assert_revert(signer.send_transaction(
        account,
        erc20.contract_address,
        'mint',
        [ZERO_ADDRESS, *UINT_ONE]
    ),
        reverted_with="ERC20: cannot mint to the zero address"
    )


@pytest.mark.asyncio
async def test_mint_overflow(token_factory):
    erc20, account = token_factory
    # pass_amount subtracts the already minted supply from MAX_UINT256 in order for
    # the minted supply to equal MAX_UINT256
    # (2**128 - 1, 2**128 - 1)
    pass_amount = sub_uint(MAX_UINT256, INIT_SUPPLY)

    await signer.send_transaction(
        account, erc20.contract_address, 'mint', [
            RECIPIENT,
            *pass_amount
        ])

    # totalSupply is MAX_UINT256 therefore adding (1, 0) should fail
    await assert_revert(
        signer.send_transaction(
            account, erc20.contract_address, 'mint', [
                RECIPIENT,
                *UINT_ONE
            ]),
        reverted_with="ERC20: mint overflow"
    )


@pytest.mark.asyncio
async def test_mint_invalid_uint256(token_factory):
    erc20, account = token_factory

    await assert_revert(signer.send_transaction(
        account,
        erc20.contract_address,
        'mint',
        [RECIPIENT, *INVALID_UINT256]),
        reverted_with="ERC20: amount is not a valid Uint256"
    )
