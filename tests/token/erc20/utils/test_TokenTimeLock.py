import pytest
from starkware.starknet.testing.starknet import Starknet
from utils import (
    Signer, to_uint, add_uint, sub_uint, str_to_felt, MAX_UINT256, ZERO_ADDRESS, INVALID_UINT256,
    TRUE, get_contract_def, cached_contract, assert_revert, assert_event_emitted, contract_path
)

signer = Signer(123456789987654321)

# testing vars
RECIPIENT = 123
INIT_SUPPLY = to_uint(1000)
AMOUNT = to_uint(200)
UINT_ONE = to_uint(1)
UINT_ZERO = to_uint(0)
NAME = str_to_felt("Token")
SYMBOL = str_to_felt("TKN")
DECIMALS = 18
RELEASE_TIME = 1682600695

@pytest.fixture(scope='module')
def contract_defs():
    account_def = get_contract_def('openzeppelin/account/Account.cairo')
    erc20_def = get_contract_def(
        'openzeppelin/token/erc20/ERC20.cairo')
    token_time_lock_def = get_contract_def(
        'openzeppelin/token/erc20/utils/TokenTimeLock.cairo')

    return account_def, erc20_def, token_time_lock_def


@pytest.fixture(scope='module')
async def token_time_lock_init(contract_defs):
    account_def, erc20_def, token_time_lock_def = contract_defs
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
        ]
    )
    token_time_lock = await starknet.deploy(
        contract_def=token_time_lock_def,
        constructor_calldata=[
            erc20.contract_address,
            account2.contract_address,
            RELEASE_TIME
        ]
    )
    return (
        starknet.state,
        account1,
        account2,
        erc20,
        token_time_lock
    )


@pytest.fixture
def token_time_lock_factory(contract_defs, token_time_lock_init):
    account_def, erc20_def, token_time_lock_def = contract_defs
    state, account1, account2, erc20, token_time_lock = token_time_lock_init
    _state = state.copy()
    account1 = cached_contract(_state, account_def, account1)
    account2 = cached_contract(_state, account_def, account2)
    erc20 = cached_contract(_state, erc20_def, erc20)
    token_time_lock = cached_contract(_state, token_time_lock_def, token_time_lock)
    return erc20, account1, account2, token_time_lock


#
# Constructor
#

@pytest.mark.asyncio
async def test_constructor_invalid_token_address(token_time_lock_factory):
    _, account, _, _ = token_time_lock_factory

    bad_token_address = 0

    starknet = await Starknet.empty()
    await assert_revert(
        starknet.deploy(
            contract_path("openzeppelin/token/erc20/utils/TokenTimeLock.cairo"),
            constructor_calldata=[
                bad_token_address,
                account.contract_address,
                RELEASE_TIME
            ]),
        reverted_with="TokenTimeLock: token and beneficiary cannot be set to 0"
    )

@pytest.mark.asyncio
async def test_constructor_invalid_beneficiary(token_time_lock_factory):
    erc20, _, _, _ = token_time_lock_factory

    bad_beneficiary = 0

    starknet = await Starknet.empty()
    await assert_revert(
        starknet.deploy(
            contract_path("openzeppelin/token/erc20/utils/TokenTimeLock.cairo"),
            constructor_calldata=[
                erc20.contract_address,
                bad_beneficiary,
                RELEASE_TIME
            ]),
        reverted_with="TokenTimeLock: token and beneficiary cannot be set to 0"
    )

@pytest.mark.asyncio
async def test_constructor_invalid_release_time(token_time_lock_factory):
    erc20, account, _, _ = token_time_lock_factory

    bad_release_time = 0

    starknet = await Starknet.empty()
    await assert_revert(
        starknet.deploy(
            contract_path("openzeppelin/token/erc20/utils/TokenTimeLock.cairo"),
            constructor_calldata=[
                erc20.contract_address,
                account.contract_address,
                bad_release_time
            ]),
        reverted_with="TokenTimeLock: release time is before current time"
    )