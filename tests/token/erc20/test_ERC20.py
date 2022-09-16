import pytest
from signers import MockSigner
from utils import (
    to_uint, add_uint, sub_uint, str_to_felt, MAX_UINT256, ZERO_ADDRESS,
    INVALID_UINT256, TRUE, get_contract_class, cached_contract, assert_revert,
    assert_event_emitted, assert_events_emitted, contract_path, State, Account
)
from ERC20BaseSuite import ERC20Base, NAME, SYMBOL, DECIMALS, INIT_SUPPLY


signer = MockSigner(123456789987654321)


@pytest.fixture(scope='module')
def contract_classes():
    account_cls = Account.get_class
    erc20_cls = get_contract_class('ERC20')

    return account_cls, erc20_cls


@pytest.fixture(scope='module')
async def erc20_init(contract_classes):
    account_cls, erc20_cls = contract_classes
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


class TestERC20(ERC20Base):
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
