import pytest
from starkware.starknet.testing.starknet import Starknet
from utils import (
    MockSigner, TRUE, FALSE, to_uint, str_to_felt, assert_revert, 
    get_contract_def, cached_contract
)

signer = MockSigner(123456789987654321)

# testing vars
INIT_SUPPLY = to_uint(1000)
AMOUNT = to_uint(200)
NAME = str_to_felt("Pausable Token")
SYMBOL = str_to_felt("PTKN")
DECIMALS = 18


@pytest.fixture(scope='module')
def contract_defs():
    account_def = get_contract_def('openzeppelin/account/Account.cairo')
    erc20_def = get_contract_def(
        'openzeppelin/token/erc20/ERC20_Pausable.cairo')

    return account_def, erc20_def


@pytest.fixture(scope='module')
async def erc20_init(contract_defs):
    account_def, erc20_def = contract_defs
    starknet = await Starknet.empty()
    account1 = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )
    account2 = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )
    erc20 = await starknet.deploy(
        contract_def=erc20_def,
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
        account2,
        erc20
    )


@pytest.fixture
def token_factory(contract_defs, erc20_init):
    account_def, erc20_def = contract_defs
    state, account1, account2, erc20 = erc20_init
    _state = state.copy()
    account1 = cached_contract(_state, account_def, account1)
    account2 = cached_contract(_state, account_def, account2)
    erc20 = cached_contract(_state, erc20_def, erc20)

    return erc20, account1, account2


@pytest.mark.asyncio
async def test_constructor(token_factory):
    token, owner, _ = token_factory

    execution_info = await token.name().invoke()
    assert execution_info.result == (NAME,)

    execution_info = await token.symbol().invoke()
    assert execution_info.result == (SYMBOL,)

    execution_info = await token.decimals().invoke()
    assert execution_info.result.decimals == DECIMALS

    execution_info = await token.balanceOf(owner.contract_address).invoke()
    assert execution_info.result.balance == INIT_SUPPLY

    execution_info = await token.paused().invoke()
    assert execution_info.result.paused == FALSE


@pytest.mark.asyncio
async def test_pause(token_factory):
    token, owner, other = token_factory

    await signer.send_transaction(owner, token.contract_address, 'pause', [])

    execution_info = await token.paused().invoke()
    assert execution_info.result.paused == TRUE

    await assert_revert(signer.send_transaction(
        owner,
        token.contract_address,
        'transfer',
        [other.contract_address, *AMOUNT]
    ),
        reverted_with="Pausable: paused"
    )

    await assert_revert(signer.send_transaction(
        owner,
        token.contract_address,
        'transferFrom',
        [other.contract_address, other.contract_address, *AMOUNT]
    ),
        reverted_with="Pausable: paused"
    )

    await assert_revert(signer.send_transaction(
        owner,
        token.contract_address,
        'approve',
        [other.contract_address, *AMOUNT]
    ),
        reverted_with="Pausable: paused"
    )

    await assert_revert(signer.send_transaction(
        owner,
        token.contract_address,
        'increaseAllowance',
        [other.contract_address, *AMOUNT]
    ),
        reverted_with="Pausable: paused"
    )

    await assert_revert(signer.send_transaction(
        owner,
        token.contract_address,
        'decreaseAllowance',
        [other.contract_address, *AMOUNT]
    ),
        reverted_with="Pausable: paused"
    )


@pytest.mark.asyncio
async def test_unpause(token_factory):
    token, owner, other = token_factory

    await signer.send_transaction(owner, token.contract_address, 'pause', [])
    await signer.send_transaction(owner, token.contract_address, 'unpause', [])

    execution_info = await token.paused().invoke()
    assert execution_info.result.paused == FALSE

    success = await signer.send_transaction(
        owner,
        token.contract_address,
        'transfer',
        [other.contract_address, *AMOUNT]
    )
    assert success.result.response == [TRUE]

    success = await signer.send_transaction(
        owner,
        token.contract_address,
        'approve',
        [other.contract_address, *AMOUNT]
    )
    assert success.result.response == [TRUE]

    success = await signer.send_transaction(
        other,
        token.contract_address,
        'transferFrom',
        [owner.contract_address, other.contract_address, *AMOUNT]
    )
    assert success.result.response == [TRUE]

    success = await signer.send_transaction(
        owner,
        token.contract_address,
        'increaseAllowance',
        [other.contract_address, *AMOUNT]
    )
    assert success.result.response == [TRUE]

    success = await signer.send_transaction(
        owner,
        token.contract_address,
        'decreaseAllowance',
        [other.contract_address, *AMOUNT]
    )
    assert success.result.response == [TRUE]


@pytest.mark.asyncio
async def test_only_owner(token_factory):
    token, _, other = token_factory

    await assert_revert(
        signer.send_transaction(
            other, token.contract_address, 'pause', []
        ),
        reverted_with="Ownable: caller is not the owner"
    )

    await assert_revert(
        signer.send_transaction(
            other, token.contract_address, 'unpause', []
        ),
        reverted_with="Ownable: caller is not the owner"
    )
