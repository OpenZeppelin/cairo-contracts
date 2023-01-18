import pytest
from signers import MockSigner
from nile.utils import TRUE, FALSE
from utils import get_contract_class, cached_contract, State, Account
from ERC721BaseSuite import NAME, SYMBOL


signer = MockSigner(123456789987654321)


@pytest.fixture(scope='module')
def contract_classes():
    account_cls = Account.get_class
    old_account_cls = get_contract_class('OldAccountMock')
    erc721_cls = get_contract_class('ERC721Mock')

    return account_cls, old_account_cls, erc721_cls


@pytest.fixture(scope='module')
async def erc721_init(contract_classes):
    account_cls, old_account_cls, erc721_cls = contract_classes
    starknet = await State.init()
    account = await Account.deploy(signer.public_key)
    old_account = await starknet.deploy(
        contract_class=old_account_cls,
        constructor_calldata=[]
    )
    erc721 = await starknet.deploy(
        contract_class=erc721_cls,
        constructor_calldata=[
            NAME,
            SYMBOL
        ]
    )
    return (
        starknet.state,
        account,
        old_account,
        erc721,
    )


@pytest.fixture
def contract_factory(contract_classes, erc721_init):
    account_cls, old_account_cls, erc721_cls = contract_classes
    state, account, old_account, erc721 = erc721_init
    _state = state.copy()
    account = cached_contract(_state, account_cls, account)
    old_account = cached_contract(_state, old_account_cls, old_account)
    erc721 = cached_contract(_state, erc721_cls, erc721)

    return erc721, account, old_account


class TestERC721Internals():
    #
    # _is_account
    #

    @pytest.mark.asyncio
    async def test_is_account(self, contract_factory):
        erc721, account, old_account = contract_factory

        execution_info = await erc721.is_account(erc721.contract_address).execute()
        assert execution_info.result.is_account == FALSE

        accounts = [account, old_account]
        for _account in accounts:
            execution_info = await erc721.is_account(_account.contract_address).execute()
            assert execution_info.result.is_account == TRUE
