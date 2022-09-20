import pytest
from signers import MockSigner
from utils import (
    TRUE, FALSE, assert_revert, get_contract_class,
    cached_contract, State, Account
)
from ERC20BaseSuite import ERC20Base, NAME, SYMBOL, DECIMALS, INIT_SUPPLY, AMOUNT
from access.OwnableBaseSuite import OwnableBase


signer = MockSigner(123456789987654321)


@pytest.fixture(scope='module')
def contract_classes():
    account_cls = Account.get_class
    erc20_cls = get_contract_class('ERC20Pausable')

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
def contract_factory(contract_classes, erc20_init):
    account_cls, erc20_cls = contract_classes
    state, account1, account2, erc20 = erc20_init
    _state = state.copy()
    account1 = cached_contract(_state, account_cls, account1)
    account2 = cached_contract(_state, account_cls, account2)
    erc20 = cached_contract(_state, erc20_cls, erc20)

    return erc20, account1, account2


class TestPausable(ERC20Base, OwnableBase):
    #
    # pause
    #

    @pytest.mark.asyncio
    async def test_constructor(self, contract_factory):
        erc20, _, _ = contract_factory

        execution_info = await erc20.paused().execute()
        assert execution_info.result.paused == FALSE


    @pytest.mark.asyncio
    async def test_pause(self, contract_factory):
        erc20, owner, other = contract_factory

        await signer.send_transaction(owner, erc20.contract_address, 'pause', [])

        execution_info = await erc20.paused().execute()
        assert execution_info.result.paused == TRUE

        await assert_revert(signer.send_transaction(
            owner,
            erc20.contract_address,
            'transfer',
            [other.contract_address, *AMOUNT]
        ),
            reverted_with="Pausable: paused"
        )

        await assert_revert(signer.send_transaction(
            owner,
            erc20.contract_address,
            'transferFrom',
            [other.contract_address, other.contract_address, *AMOUNT]
        ),
            reverted_with="Pausable: paused"
        )

        await assert_revert(signer.send_transaction(
            owner,
            erc20.contract_address,
            'approve',
            [other.contract_address, *AMOUNT]
        ),
            reverted_with="Pausable: paused"
        )

        await assert_revert(signer.send_transaction(
            owner,
            erc20.contract_address,
            'increaseAllowance',
            [other.contract_address, *AMOUNT]
        ),
            reverted_with="Pausable: paused"
        )

        await assert_revert(signer.send_transaction(
            owner,
            erc20.contract_address,
            'decreaseAllowance',
            [other.contract_address, *AMOUNT]
        ),
            reverted_with="Pausable: paused"
        )


    @pytest.mark.asyncio
    async def test_unpause(self, contract_factory):
        erc20, owner, other = contract_factory

        await signer.send_transaction(owner, erc20.contract_address, 'pause', [])
        await signer.send_transaction(owner, erc20.contract_address, 'unpause', [])

        execution_info = await erc20.paused().execute()
        assert execution_info.result.paused == FALSE

        success = await signer.send_transaction(
            owner,
            erc20.contract_address,
            'transfer',
            [other.contract_address, *AMOUNT]
        )
        assert success.call_info.retdata[1] == TRUE

        success = await signer.send_transaction(
            owner,
            erc20.contract_address,
            'approve',
            [other.contract_address, *AMOUNT]
        )
        assert success.call_info.retdata[1] == TRUE

        success = await signer.send_transaction(
            other,
            erc20.contract_address,
            'transferFrom',
            [owner.contract_address, other.contract_address, *AMOUNT]
        )
        assert success.call_info.retdata[1] == TRUE

        success = await signer.send_transaction(
            owner,
            erc20.contract_address,
            'increaseAllowance',
            [other.contract_address, *AMOUNT]
        )
        assert success.call_info.retdata[1] == TRUE

        success = await signer.send_transaction(
            owner,
            erc20.contract_address,
            'decreaseAllowance',
            [other.contract_address, *AMOUNT]
        )
        assert success.call_info.retdata[1] == TRUE


    @pytest.mark.asyncio
    async def test_only_owner(self, contract_factory):
        erc20, _, other = contract_factory

        await assert_revert(
            signer.send_transaction(
                other, erc20.contract_address, 'pause', []
            ),
            reverted_with="Ownable: caller is not the owner"
        )

        await assert_revert(
            signer.send_transaction(
                other, erc20.contract_address, 'unpause', []
            ),
            reverted_with="Ownable: caller is not the owner"
        )
