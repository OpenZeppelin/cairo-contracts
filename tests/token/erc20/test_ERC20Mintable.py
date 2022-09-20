import pytest
from signers import MockSigner
from utils import (
    add_uint, sub_uint, MAX_UINT256, ZERO_ADDRESS, INVALID_UINT256,
    get_contract_class, cached_contract, assert_revert, assert_event_emitted,
    State, Account
)
from ERC20BaseSuite import ERC20Base, NAME, SYMBOL, DECIMALS, INIT_SUPPLY, UINT_ONE
from access.OwnableBaseSuite import OwnableBase


signer = MockSigner(123456789987654321)


@pytest.fixture(scope='module')
def contract_classes():
    account_cls = Account.get_class
    erc20_cls = get_contract_class('ERC20Mintable')

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
        erc20,
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


class TestERC20Mintable(ERC20Base, OwnableBase):
    #
    # mint
    #

    @pytest.mark.asyncio
    async def test_mint(self, contract_factory):
        erc20, account, _ = contract_factory

        await signer.send_transaction(
            account, erc20.contract_address, 'mint', [
                account.contract_address,
                *UINT_ONE
            ])

        # check new supply
        execution_info = await erc20.totalSupply().execute()
        new_supply = execution_info.result.totalSupply
        assert new_supply == add_uint(INIT_SUPPLY, UINT_ONE)


    @pytest.mark.asyncio
    async def test_mint_emits_event(self, contract_factory):
        erc20, account, _ = contract_factory

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
    async def test_mint_to_zero_address(self, contract_factory):
        erc20, account, _ = contract_factory

        await assert_revert(signer.send_transaction(
            account,
            erc20.contract_address,
            'mint',
            [ZERO_ADDRESS, *UINT_ONE]
        ),
            reverted_with="ERC20: cannot mint to the zero address"
        )


    @pytest.mark.asyncio
    async def test_mint_overflow(self, contract_factory):
        erc20, account, recipient = contract_factory
        # pass_amount subtracts the already minted supply from MAX_UINT256 in order for
        # the minted supply to equal MAX_UINT256
        # (2**128 - 1, 2**128 - 1)
        pass_amount = sub_uint(MAX_UINT256, INIT_SUPPLY)

        await signer.send_transaction(
            account, erc20.contract_address, 'mint', [
                recipient.contract_address,
                *pass_amount
            ])

        # totalSupply is MAX_UINT256 therefore adding (1, 0) should fail
        await assert_revert(
            signer.send_transaction(
                account, erc20.contract_address, 'mint', [
                    recipient.contract_address,
                    *UINT_ONE
                ]),
            reverted_with="ERC20: mint overflow"
        )


    @pytest.mark.asyncio
    async def test_mint_invalid_uint256(self, contract_factory):
        erc20, account, recipient = contract_factory

        await assert_revert(signer.send_transaction(
            account,
            erc20.contract_address,
            'mint',
            [recipient.contract_address, *INVALID_UINT256]),
            reverted_with="ERC20: amount is not a valid Uint256"
        )
