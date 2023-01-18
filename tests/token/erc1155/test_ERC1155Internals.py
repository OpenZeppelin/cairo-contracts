import pytest
from signers import MockSigner
from nile.utils import TRUE, FALSE
from utils import State, Account, get_contract_class, cached_contract

from ERC1155BaseSuite import TOKEN_ID, NEW_URI, DEFAULT_URI

signer = MockSigner(123456789987654321)


#
# Fixtures
#


@pytest.fixture(scope='module')
def contract_classes():
    account_cls = Account.get_class
    old_account_cls = get_contract_class('OldAccountMock')
    erc1155_cls = get_contract_class('ERC1155Mock')
    return account_cls, old_account_cls, erc1155_cls


@pytest.fixture(scope='module')
async def erc1155_init(contract_classes):
    _, old_account_cls, erc1155_cls = contract_classes
    starknet = await State.init()
    account = await Account.deploy(signer.public_key)
    old_account = await starknet.deploy(
        contract_class=old_account_cls,
        constructor_calldata=[]
    )
    erc1155 = await starknet.deploy(
        contract_class=erc1155_cls,
        constructor_calldata=[DEFAULT_URI, account.contract_address]
    )
    return (
        starknet.state,
        account,
        old_account,
        erc1155,
    )


@pytest.fixture
def contract_factory(contract_classes, erc1155_init):
    account_cls, old_account_cls, erc1155_cls = contract_classes
    state, account, old_account, erc1155 = erc1155_init
    _state = state.copy()
    account = cached_contract(_state, account_cls, account)
    old_account = cached_contract(_state, old_account_cls, old_account)
    erc1155 = cached_contract(_state, erc1155_cls, erc1155)
    return erc1155, account, old_account


class TestERC1155Internals():
    #
    # Set URI
    #


    @pytest.mark.asyncio
    async def test_set_uri(self, contract_factory):
        erc1155, owner, _ = contract_factory

        await signer.send_transaction(
            owner, erc1155.contract_address, 'setURI',
            [NEW_URI]
        )

        execution_info = await erc1155.uri(TOKEN_ID).execute()
        assert execution_info.result.uri == NEW_URI

    #
    # _is_account
    #


    @pytest.mark.asyncio
    async def test_is_account(self, contract_factory):
        erc1155, account, old_account = contract_factory

        execution_info = await erc1155.is_account(erc1155.contract_address).execute()
        assert execution_info.result.is_account == FALSE

        accounts = [account, old_account]
        for _account in accounts:
            execution_info = await erc1155.is_account(_account.contract_address).execute()
            assert execution_info.result.is_account == TRUE
