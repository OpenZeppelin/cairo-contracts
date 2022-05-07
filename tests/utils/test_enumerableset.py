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


@pytest.mark.asyncio
async def test_add(enumerableset_mock):
    enumerableset = enumerableset_mock
    
    executed_info = await enumerableset.length().call()
    assert executed_info.result == (0,)
    
    success = await enumerableset.add(1).invoke()
    assert success.result.success == TRUE

    executed_info = await enumerableset.contains(1).call()
    assert executed_info.result == (TRUE,)

    executed_info = await enumerableset.length().call()
    assert executed_info.result == (1,)


@pytest.mark.asyncio
async def test_remove(enumerableset_mock):
    enumerableset = enumerableset_mock
    success = await enumerableset.add(1).invoke()
    assert success.result.success == TRUE

    success = await enumerableset.remove(1).invoke()
    assert success.result.success == TRUE

    executed_info = await enumerableset.length().call()
    assert executed_info.result == (0,)


@pytest.mark.asyncio
async def test_remove_not_present(enumerableset_mock):
    enumerableset = enumerableset_mock

    success = await enumerableset.remove(1).invoke()
    assert success.result.success == FALSE

    executed_info = await enumerableset.contains(1).call()
    assert executed_info.result == (FALSE,)


@pytest.mark.asyncio
async def test_dupe_add(enumerableset_mock):
    enumerableset = enumerableset_mock

    success = await enumerableset.add(1).invoke()
    assert success.result.success == TRUE

    success = await enumerableset.add(1).invoke()
    assert success.result.success == FALSE

    executed_info = await enumerableset.contains(1).call()
    assert executed_info.result == (TRUE,)

    executed_info = await enumerableset.length().call()
    assert executed_info.result == (1,)


@pytest.mark.asyncio
async def test_multi_add(enumerableset_mock):
    enumerableset = enumerableset_mock
    
    for i in [1,3,2]:
        success = await enumerableset.add(i).invoke()
        assert success.result.success == TRUE

    for i in [3,2,1]:
        executed_info = await enumerableset.contains(i).call()
        assert executed_info.result == (TRUE,)

    executed_info = await enumerableset.length().call()
    assert executed_info.result == (3,)


@pytest.mark.asyncio
async def test_add_three_remove_one(enumerableset_mock):
    enumerableset = enumerableset_mock

    for i in [1,3,2]:
        success = await enumerableset.add(i).invoke()
        assert success.result.success == TRUE

    success = await enumerableset.remove(3).invoke()
    assert success.result.success == TRUE

    executed_info = await enumerableset.contains(3).call()
    assert executed_info.result == (FALSE,)

    executed_info = await enumerableset.contains(2).call()
    assert executed_info.result == (TRUE,)

    executed_info = await enumerableset.contains(1).call()
    assert executed_info.result == (TRUE,)

    executed_info = await enumerableset.length().call()
    assert executed_info.result == (2,)


@pytest.mark.asyncio
async def test_values(enumerableset_mock):
    enumerableset = enumerableset_mock

    for i in [1,3,2]:
        success = await enumerableset.add(i).invoke()
        assert success.result.success == TRUE

    executed_info = await enumerableset.values().call()

    values = executed_info.result.res

    for i in range(1,4):
        assert i in values

    assert 4 not in values


@pytest.mark.asyncio
async def test_values_after_remove(enumerableset_mock):
    enumerableset = enumerableset_mock
    
    for i in [1,3,2,4]:
        success = await enumerableset.add(i).invoke()
        assert success.result.success == TRUE

    success = await enumerableset.remove(2).invoke()
    assert success.result.success == TRUE

    executed_info = await enumerableset.values().call()

    values = executed_info.result.res

    assert 1 in values
    assert 2 not in values
    assert 3 in values
    assert 4 in values
