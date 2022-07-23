import pytest
from starkware.starknet.testing.starknet import Starknet
from utils import contract_path, TRUE, FALSE


@pytest.fixture
async def enumerableset_mock():
    starknet = await Starknet.empty()

    enumerableset = await starknet.deploy(
        contract_path("tests/mocks/enumerableset_mock.cairo")
    )

    return enumerableset


@pytest.fixture
async def enumerableset_added(enumerableset_mock):
    enumerableset = enumerableset_mock

    for i in range(1,5):
        await enumerableset.add(i).invoke()

    return enumerableset


@pytest.mark.asyncio
async def test_add(enumerableset_mock):
    enumerableset = enumerableset_mock
    
    success = await enumerableset.add(1).invoke()
    assert success.result.success == TRUE

    executed_info = await enumerableset.contains(1).call()
    assert executed_info.result == (TRUE,)


@pytest.mark.asyncio
async def test_remove(enumerableset_added):
    enumerableset = enumerableset_added

    success = await enumerableset.remove(1).invoke()
    assert success.result.success == TRUE

    executed_info = await enumerableset.contains(1).call()
    assert executed_info.result == (FALSE,)


@pytest.mark.asyncio
@pytest.mark.parametrize('value, result', [
    [1, TRUE],
    [2, TRUE],
    [3, TRUE],
    [4, TRUE],
    [5, FALSE],
])
async def test_contains(enumerableset_added, value, result):
    enumerableset = enumerableset_added
    executed_info = await enumerableset.contains(value).call()
    assert executed_info.result == (result,)


@pytest.mark.asyncio
async def test_remove_not_present(enumerableset_mock):
    enumerableset = enumerableset_mock

    success = await enumerableset.remove(1).invoke()
    assert success.result.success == FALSE

    executed_info = await enumerableset.contains(1).call()
    assert executed_info.result == (FALSE,)


@pytest.mark.asyncio
async def test_dupe_add(enumerableset_added):
    enumerableset = enumerableset_added

    success = await enumerableset.add(1).invoke()
    assert success.result.success == FALSE


@pytest.mark.asyncio
@pytest.mark.parametrize('value, result', [
    [1, TRUE],
    [2, TRUE],
    [3, FALSE],
    [4, TRUE],
    [5, FALSE],
])
async def test_add_three_remove_one(enumerableset_added, value, result):
    enumerableset = enumerableset_added

    success = await enumerableset.remove(3).invoke()
    assert success.result.success == TRUE

    executed_info = await enumerableset.contains(value).call()
    assert executed_info.result == (result,)


@pytest.mark.asyncio
async def test_values(enumerableset_added):
    enumerableset = enumerableset_added

    executed_info = await enumerableset.values().call()

    values = executed_info.result.res

    for i in range(1,5):
        assert i in values

    assert 5 not in values


@pytest.mark.asyncio
async def test_values_after_remove(enumerableset_added):
    enumerableset = enumerableset_added

    success = await enumerableset.remove(2).invoke()
    assert success.result.success == TRUE

    executed_info = await enumerableset.values().call()

    values = executed_info.result.res

    assert 1 in values
    assert 2 not in values
    assert 3 in values
    assert 4 in values
