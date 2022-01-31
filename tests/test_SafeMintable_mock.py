import pytest
import asyncio
from starkware.starknet.compiler.compile import compile_starknet_files
from starkware.starknet.testing.starknet import Starknet, StarknetContract
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils import Signer, str_to_felt, ZERO_ADDRESS, assert_revert, to_uint

signer = Signer(123456789987654321)

account_path = 'contracts/Account.cairo'
erc721_path = 'tests/mocks/ERC721_SafeMintable_mock.cairo'
erc721_holder_path = 'contracts/token/utils/ERC721_Holder.cairo'
unsupported_path = 'contracts/Initializable.cairo'

# random token id
TOKEN = to_uint(5042)
# random data (mimicking bytes in Solidity)
DATA = [0x42, 0x89, 0x55]


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
def contract_defs():
    account_def = compile_starknet_files(
        files=[account_path],
        debug_info=True
    )
    erc721_def = compile_starknet_files(
        files=[erc721_path],
        debug_info=True
    )
    erc721_holder_def = compile_starknet_files(
        files=[erc721_holder_path],
        debug_info=True
    )
    unsupported_def = compile_starknet_files(
        files=[unsupported_path],
        debug_info=True
    )
    return account_def, erc721_def, erc721_holder_def, unsupported_def


@pytest.fixture(scope='module')
async def erc721_init(contract_defs):
    account_def, erc721_def, erc721_holder_def, unsupported_def = contract_defs
    starknet = await Starknet.empty()
    account1 = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )
    account2 = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )
    erc721 = await starknet.deploy(
        contract_def=erc721_def,
        constructor_calldata=[
            str_to_felt("Non Fungible Token"),  # name
            str_to_felt("NFT"),                 # ticker
            account1.contract_address
        ]
    )
    erc721_holder = await starknet.deploy(
        contract_def=erc721_holder_def,
        constructor_calldata=[]
    )
    unsupported = await starknet.deploy(
        contract_def=unsupported_def,
        constructor_calldata=[]
    )
    return (
        starknet.state,
        account1,
        account2,
        erc721,
        erc721_holder,
        unsupported
    )


@pytest.fixture
def erc721_factory(contract_defs, erc721_init):
    account_def, erc721_def, erc721_holder_def, unsupported_def = contract_defs
    state, account1, account2, erc721, erc721_holder, unsupported = erc721_init
    _state = state.copy()
    account1 = StarknetContract(
        state=_state,
        abi=account_def.abi,
        contract_address=account1.contract_address,
        deploy_execution_info=account1.deploy_execution_info
    )
    account2 = StarknetContract(
        state=_state,
        abi=account_def.abi,
        contract_address=account2.contract_address,
        deploy_execution_info=account2.deploy_execution_info
    )
    erc721 = StarknetContract(
        state=_state,
        abi=erc721_def.abi,
        contract_address=erc721.contract_address,
        deploy_execution_info=erc721.deploy_execution_info
    )
    erc721_holder = StarknetContract(
        state=_state,
        abi=erc721_holder_def.abi,
        contract_address=erc721_holder.contract_address,
        deploy_execution_info=erc721_holder.deploy_execution_info
    )
    unsupported = StarknetContract(
        state=_state,
        abi=unsupported_def.abi,
        contract_address=unsupported.contract_address,
        deploy_execution_info=unsupported.deploy_execution_info
    )
    return erc721, account1, account2, erc721_holder, unsupported


@pytest.mark.asyncio
async def test_safeMint_to_erc721_supported_contract(erc721_factory):
    erc721, account, _, erc721_holder, _ = erc721_factory

    await signer.send_transaction(
        account, erc721.contract_address, 'safeMint', [
            erc721_holder.contract_address,
            *TOKEN,
            len(DATA),
            *DATA
        ]
    )

    # check balance
    execution_info = await erc721.balanceOf(erc721_holder.contract_address).call()
    assert execution_info.result == (to_uint(1),)

    # check owner
    execution_info = await erc721.ownerOf(TOKEN).call()
    assert execution_info.result == (erc721_holder.contract_address,)


@pytest.mark.asyncio
async def test_safeMint_to_account(erc721_factory):
    erc721, account, recipient, _, _ = erc721_factory

    await signer.send_transaction(
        account, erc721.contract_address, 'safeMint', [
            recipient.contract_address,
            *TOKEN,
            len(DATA),
            *DATA
        ]
    )

    # check balance
    execution_info = await erc721.balanceOf(recipient.contract_address).call()
    assert execution_info.result == (to_uint(1),)

    # check owner
    execution_info = await erc721.ownerOf(TOKEN).call()
    assert execution_info.result == (recipient.contract_address,)


@pytest.mark.asyncio
async def test_safeMint_to_zero_address(erc721_factory):
    erc721, account, _, _, _ = erc721_factory

    # to zero address should be rejected
    await assert_revert(signer.send_transaction(
        account, erc721.contract_address, 'safeMint', [
            ZERO_ADDRESS,
            *TOKEN,
            len(DATA),
            *DATA
        ]
    ))


@pytest.mark.asyncio
async def test_safeMint_from_zero_address(erc721_factory):
    erc721, _, _, erc721_holder, _ = erc721_factory

    # Caller address is `0` when not using an account contract
    await assert_revert(
        erc721.safeMint(
            erc721_holder.contract_address,
            TOKEN,
            DATA
        ).invoke()
    )


@pytest.mark.asyncio
async def test_safeMint_to_unsupported_contract(erc721_factory):
    erc721, account, _, _, unsupported = erc721_factory

    try:
        await signer.send_transaction(
            account, erc721.contract_address, 'safeMint', [
                unsupported.contract_address,
                *TOKEN,
                len(DATA),
                *DATA
            ]
        )
        assert False
    except StarkException as err:
        _, error = err.args
        assert error['code'] == StarknetErrorCode.ENTRY_POINT_NOT_FOUND_IN_CONTRACT
