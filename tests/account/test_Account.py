import pytest
from signers import MockSigner, get_raw_invoke
from utils import assert_revert, get_contract_class, cached_contract, TRUE, State, Account


signer = MockSigner(123456789987654321)
other = MockSigner(987654321123456789)

IACCOUNT_ID = 0xa66bd575


@pytest.fixture(scope='module')
def contract_classes():
    account_cls = Account.get_class
    init_cls = get_contract_class("Initializable")
    attacker_cls = get_contract_class("AccountReentrancy")

    return account_cls, init_cls, attacker_cls


@pytest.fixture(scope='module')
async def account_init(contract_classes):
    account_cls, init_cls, attacker_cls = contract_classes
    starknet = await State.init()
    account1 = await Account.deploy(signer.public_key)
    account2 = await Account.deploy(signer.public_key)

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
def account_factory(contract_classes, account_init):
    account_cls, init_cls, attacker_cls = contract_classes
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

    execution_info = await account.getPublicKey().call()
    assert execution_info.result == (signer.public_key,)

    execution_info = await account.supportsInterface(IACCOUNT_ID).call()
    assert execution_info.result == (TRUE,)


@pytest.mark.asyncio
async def test_execute(account_factory):
    account, _, initializable, *_ = account_factory

    execution_info = await initializable.initialized().call()
    assert execution_info.result == (0,)

    await signer.send_transactions(account, [(initializable.contract_address, 'initialize', [])])

    execution_info = await initializable.initialized().call()
    assert execution_info.result == (1,)


@pytest.mark.asyncio
async def test_multicall(account_factory):
    account, _, initializable_1, initializable_2, _ = account_factory

    execution_info = await initializable_1.initialized().call()
    assert execution_info.result == (0,)
    execution_info = await initializable_2.initialized().call()
    assert execution_info.result == (0,)

    await signer.send_transactions(
        account,
        [
            (initializable_1.contract_address, 'initialize', []),
            (initializable_2.contract_address, 'initialize', [])
        ]
    )

    execution_info = await initializable_1.initialized().call()
    assert execution_info.result == (1,)
    execution_info = await initializable_2.initialized().call()
    assert execution_info.result == (1,)


@pytest.mark.asyncio
async def test_return_value(account_factory):
    account, _, initializable, *_ = account_factory

    # initialize, set `initialized = 1`
    await signer.send_transactions(account, [(initializable.contract_address, 'initialize', [])])

    read_info = await signer.send_transactions(account, [(initializable.contract_address, 'initialized', [])])
    call_info = await initializable.initialized().call()
    (call_result, ) = call_info.result
    assert read_info.call_info.retdata[1] == call_result #1


@ pytest.mark.asyncio
async def test_nonce(account_factory):
    account, _, initializable, *_ = account_factory

    # bump nonce
    await signer.send_transactions(account, [(initializable.contract_address, 'initialized', [])])

    # get nonce
    hex_args = [(hex(initializable.contract_address), 'initialized', [])]
    raw_invocation = get_raw_invoke(account, hex_args)
    current_nonce = await raw_invocation.state.state.get_nonce_at(account.contract_address)

    # lower nonce
    await assert_revert(
        signer.send_transactions(
            account, [(initializable.contract_address, 'initialize', [])], nonce=current_nonce - 1),
        reverted_with="Invalid transaction nonce. Expected: {}, got: {}.".format(
            current_nonce, current_nonce - 1
        )
    )

    # higher nonce
    await assert_revert(
        signer.send_transactions(account, [(initializable.contract_address, 'initialize', [])], nonce=current_nonce + 1),
        reverted_with="Invalid transaction nonce. Expected: {}, got: {}.".format(
            current_nonce, current_nonce + 1
        )
    )

    # right nonce
    await signer.send_transactions(account, [(initializable.contract_address, 'initialize', [])], nonce=current_nonce)

    execution_info = await initializable.initialized().call()
    assert execution_info.result == (1,)


@pytest.mark.asyncio
async def test_public_key_setter(account_factory):
    account, *_ = account_factory

    execution_info = await account.getPublicKey().call()
    assert execution_info.result == (signer.public_key,)

    # set new pubkey
    await signer.send_transactions(account, [(account.contract_address, 'setPublicKey', [other.public_key])])

    execution_info = await account.getPublicKey().call()
    assert execution_info.result == (other.public_key,)


@pytest.mark.asyncio
async def test_public_key_setter_different_account(account_factory):
    account, bad_account, *_ = account_factory

    # set new pubkey
    await assert_revert(
        signer.send_transactions(
            bad_account,
            [(account.contract_address, 'setPublicKey', [other.public_key])]
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

    execution_info = await account.getPublicKey().call()
    assert execution_info.result == (signer.public_key,)


async def test_interface():
    assert get_contract_class("IAccount")
