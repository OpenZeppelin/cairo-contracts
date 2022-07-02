import pytest
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils import assert_revert, get_contract_class, cached_contract, TRUE, FALSE
from signers import MockEthSigner

private_key = b'\x01' * 32
signer = MockEthSigner(b'\x01' * 32)
other = MockEthSigner(b'\x02' * 32)

IACCOUNT_ID = 0xf10dbd44


@pytest.fixture(scope='module')
def contract_defs():
    account_cls = get_contract_class('openzeppelin/account/EthAccount.cairo')
    init_cls = get_contract_class("tests/mocks/Initializable.cairo")
    attacker_cls = get_contract_class("tests/mocks/account_reentrancy.cairo")

    return account_cls, init_cls, attacker_cls


@pytest.fixture(scope='module')
async def account_init(contract_defs):
    account_cls, init_cls, attacker_cls = contract_defs
    starknet = await Starknet.empty()

    account1 = await starknet.deploy(
        contract_class=account_cls,
        constructor_calldata=[signer.eth_address]
    )
    account2 = await starknet.deploy(
        contract_class=account_cls,
        constructor_calldata=[signer.eth_address]
    )
    initializable1 = await starknet.deploy(
        contract_class=init_cls,
        constructor_calldata=[],
    )
    initializable2 = await starknet.deploy(
        contract_class=init_cls,
        constructor_calldata=[],
    )
    attacker = await starknet.deploy(
        contract_class=attacker_cls,
        constructor_calldata=[],
    )

    return starknet.state, account1, account2, initializable1, initializable2, attacker


@pytest.fixture
def account_factory(contract_defs, account_init):
    account_cls, init_cls, attacker_cls = contract_defs
    state, account1, account2, initializable1, initializable2, attacker = account_init
    _state = state.copy()
    account1 = cached_contract(_state, account_cls, account1)
    account2 = cached_contract(_state, account_cls, account2)
    initializable1 = cached_contract(_state, init_cls, initializable1)
    initializable2 = cached_contract(_state, init_cls, initializable2)
    attacker = cached_contract(_state, attacker_cls, attacker)

    return account1, account2, initializable1, initializable2, attacker


@pytest.mark.asyncio
async def test_constructor(account_factory):
    account, *_ = account_factory

    execution_info = await account.get_eth_address().call()
    assert execution_info.result == (signer.eth_address,)

    execution_info = await account.supportsInterface(IACCOUNT_ID).call()
    assert execution_info.result == (TRUE,)


@pytest.mark.asyncio
async def test_execute(account_factory):
    account, _, initializable, *_ = account_factory

    execution_info = await initializable.initialized().call()
    assert execution_info.result == (FALSE,)

    _, hash, signature = await signer.send_transactions(account, [(initializable.contract_address, 'initialize', [])])

    validity_info, *_ = await signer.send_transactions(account, [(account.contract_address, 'is_valid_signature', [hash, len(signature), *signature])])
    assert validity_info.result.response[0] == TRUE

    execution_info = await initializable.initialized().call()
    assert execution_info.result == (TRUE,)

    # should revert if signature is not correct
    await assert_revert(
        signer.send_transactions(account, [(account.contract_address, 'is_valid_signature', [hash-1, len(signature), *signature])]),
        reverted_with="Invalid signature"
    )


@pytest.mark.asyncio
async def test_multicall(account_factory):
    account, _, initializable_1, initializable_2, _ = account_factory

    execution_info = await initializable_1.initialized().call()
    assert execution_info.result == (FALSE,)
    execution_info = await initializable_2.initialized().call()
    assert execution_info.result == (FALSE,)

    await signer.send_transactions(
        account,
        [
            (initializable_1.contract_address, 'initialize', []),
            (initializable_2.contract_address, 'initialize', [])
        ]
    )

    execution_info = await initializable_1.initialized().call()
    assert execution_info.result == (TRUE,)
    execution_info = await initializable_2.initialized().call()
    assert execution_info.result == (TRUE,)


@pytest.mark.asyncio
async def test_return_value(account_factory):
    account, _, initializable, *_ = account_factory

    # initialize, set `initialized = 1`
    await signer.send_transactions(account, [(initializable.contract_address, 'initialize', [])])

    read_info, *_ = await signer.send_transactions(account, [(initializable.contract_address, 'initialized', [])])
    call_info = await initializable.initialized().call()
    (call_result, ) = call_info.result
    assert read_info.result.response == [call_result]  # 1


@ pytest.mark.asyncio
async def test_nonce(account_factory):
    account, _, initializable, *_ = account_factory
    
    # bump nonce 
    _, hash, signature = await signer.send_transactions(account, [(initializable.contract_address, 'initialized', [])])

    execution_info = await account.get_nonce().call()
    current_nonce = execution_info.result.res

    # lower nonce
    await assert_revert(
        signer.send_transactions(account, [(initializable.contract_address, 'initialize', [])], current_nonce - 1),
        reverted_with="Account: nonce is invalid"
    )

    # higher nonce
    await assert_revert(
        signer.send_transactions(account, [(initializable.contract_address, 'initialize', [])], current_nonce + 1),
        reverted_with="Account: nonce is invalid"
    )

    # right nonce
    await signer.send_transactions(account, [(initializable.contract_address, 'initialize', [])], current_nonce)

    execution_info = await initializable.initialized().call()
    assert execution_info.result == (TRUE,)


@pytest.mark.asyncio
async def test_eth_address_setter(account_factory):
    account, *_ = account_factory

    execution_info = await account.get_eth_address().call()
    assert execution_info.result == (signer.eth_address,)

    # set new pubkey
    await signer.send_transactions(account, [(account.contract_address, 'set_eth_address', [other.eth_address])])

    execution_info = await account.get_eth_address().call()
    assert execution_info.result == (other.eth_address,)


@pytest.mark.asyncio
async def test_eth_address_setter_different_account(account_factory):
    account, bad_account, *_ = account_factory

    # set new pubkey
    await assert_revert(
        signer.send_transactions(
            bad_account,
            [(account.contract_address, 'set_eth_address', [other.eth_address])]
        ),
        reverted_with="Account: caller is not this account"
    )


@pytest.mark.asyncio
async def test_account_takeover_with_reentrant_call(account_factory):
    account, _, _, _, attacker = account_factory

    await assert_revert(
        signer.send_transaction(account, attacker.contract_address, 'account_takeover', []),
        reverted_with="Account: no reentrant call"
    )
    
    execution_info = await account.get_eth_address().call()
    assert execution_info.result == (signer.eth_address,)
