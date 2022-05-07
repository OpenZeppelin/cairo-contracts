import pytest
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException
from starkware.starknet.definitions.error_codes import StarknetErrorCode
from utils import assert_revert, contract_path, TRUE, FALSE

@pytest.fixture
async def enumerablemap_mock():
    starknet = await Starknet.empty()
    enumerablemap = await starknet.deploy(
        contract_path("tests/mocks/enumerablemap_mock.cairo")
    )

    return enumerablemap


@pytest.mark.asyncio
async def test_set(enumerablemap_mock):
    enumerablemap = enumerablemap_mock

    success = await enumerablemap.set(6, 8).invoke()
    assert success.result.success == TRUE

    executed_info = await enumerablemap.contains(6).call()
    assert executed_info.result == (TRUE,)


@pytest.mark.asyncio
async def test_remove(enumerablemap_mock):
    enumerablemap = enumerablemap_mock

    success = await enumerablemap.set(6, 8).invoke()
    assert success.result.success == TRUE

    executed_info = await enumerablemap.length().call()
    assert executed_info.result == (1,)

    success = await enumerablemap.remove(6).invoke()
    assert success.result.success == TRUE

    executed_info = await enumerablemap.length().call()
    assert executed_info.result == (0,)

    executed_info = await enumerablemap.contains(6).call()
    assert executed_info.result == (FALSE,)


@pytest.mark.asyncio
async def test_remove_fail(enumerablemap_mock):
    enumerablemap = enumerablemap_mock

    executed_info = await enumerablemap.contains(6).call()
    assert executed_info.result == (FALSE,)

    success = await enumerablemap.remove(6).invoke()
    assert success.result.success == FALSE

    executed_info = await enumerablemap.contains(6).call()
    assert executed_info.result == (FALSE,)


@pytest.mark.asyncio
async def test_update(enumerablemap_mock):
    enumerablemap = enumerablemap_mock

    success = await enumerablemap.set(6, 8).invoke()
    assert success.result.success == TRUE
    
    executed_info = await enumerablemap.get(6).call()
    assert executed_info.result == (TRUE, 8,)

    success = await enumerablemap.set(6, 19).invoke()
    assert success.result.success == FALSE

    executed_info = await enumerablemap.get(6).call()
    assert executed_info.result == (TRUE, 19,)

    executed_info = await enumerablemap.length().call()
    assert executed_info.result == (1,)


@pytest.mark.asyncio
async def test_two_sets(enumerablemap_mock):
    enumerablemap = enumerablemap_mock

    success = await enumerablemap.set(6, 8).invoke()
    assert success.result.success == TRUE

    success = await enumerablemap.set(8, 19).invoke()
    assert success.result.success == TRUE

    executed_info = await enumerablemap.get(6).call()
    assert executed_info.result == (TRUE, 8,)

    executed_info = await enumerablemap.get(8).call()
    assert executed_info.result == (TRUE, 19,)

    executed_info = await enumerablemap.length().call()
    assert executed_info.result == (2,)


@pytest.mark.asyncio
async def test_get(enumerablemap_mock):
    enumerablemap = enumerablemap_mock

    await assert_revert(
        enumerablemap.get(1).call(),
        reverted_with="EnumerableMap: nonexistent key"
    )

    success = await enumerablemap.set(1, 3).invoke()
    assert success.result.success == TRUE

    executed_info = await enumerablemap.get(1).call()
    assert executed_info.result == (TRUE, 3,)


@pytest.mark.asyncio
async def test_try_get(enumerablemap_mock):
    enumerablemap = enumerablemap_mock

    executed_info = await enumerablemap.tryGet(11).call()
    assert executed_info.result == (FALSE, 0,)

    success = await enumerablemap.set(11, 19).invoke()
    assert success.result.success == TRUE

    executed_info = await enumerablemap.tryGet(11).call()
    assert executed_info.result == (TRUE, 19,)
