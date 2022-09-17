import pytest
from signers import MockSigner
from utils import  get_contract_class, assert_revert, cached_contract, State, Account
from OwnableBaseSuite import OwnableBase


signer = MockSigner(123456789987654321)

@pytest.fixture(scope='module')
def contract_classes():
    return (
        Account.get_class,
        get_contract_class('Ownable')
    )


@pytest.fixture(scope='module')
async def ownable_init(contract_classes):
    account_cls, ownable_cls = contract_classes
    starknet = await State.init()
    owner = await Account.deploy(signer.public_key)
    ownable = await starknet.deploy(
        contract_class=ownable_cls,
        constructor_calldata=[owner.contract_address]
    )
    not_owner = await Account.deploy(signer.public_key)
    return starknet.state, ownable, owner, not_owner


@pytest.fixture
def contract_factory(contract_classes, ownable_init):
    account_cls, ownable_cls = contract_classes
    state, ownable, owner, not_owner = ownable_init
    _state = state.copy()
    owner = cached_contract(_state, account_cls, owner)
    ownable = cached_contract(_state, ownable_cls, ownable)
    not_owner = cached_contract(_state, account_cls, not_owner)
    return ownable, owner, not_owner


class TestOwnable(OwnableBase):
    @pytest.mark.asyncio
    async def test_contract_without_owner(self, contract_factory):
        ownable, owner, _ = contract_factory
        await signer.send_transaction(owner, ownable.contract_address, 'renounceOwnership', [])

        # Protected function should not be called from zero address
        await assert_revert(
            ownable.protected_function().execute(),
            reverted_with="Ownable: caller is the zero address"
        )


    @pytest.mark.asyncio
    async def test_contract_caller_not_owner(self, contract_factory):
        ownable, owner, not_owner = contract_factory

        # Protected function should only be called from owner
        await assert_revert(
            signer.send_transaction(not_owner, ownable.contract_address, 'protected_function', []),
            reverted_with="Ownable: caller is not the owner"
        )
