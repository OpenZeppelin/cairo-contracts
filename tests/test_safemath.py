import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils import MAX_UINT256, assert_revert, add_uint, sub_uint, to_uint


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
async def safemath_mock():
    starknet = await Starknet.empty()
    safemath = await starknet.deploy(
        "tests/mocks/safemath_mock.cairo"
    )

    return safemath


@pytest.mark.asyncio
async def test_add(safemath_mock):
    safemath = safemath_mock

    a = to_uint(56789)
    b = to_uint(1234)
    c = add_uint(a, b)

    execution_info = await safemath.test_add(a, b).invoke()
    assert execution_info.result == (c,)


@pytest.mark.asyncio
async def test_add_overflow(safemath_mock):
    safemath = safemath_mock

    a = MAX_UINT256
    b = to_uint(1)

    await assert_revert(safemath.test_add(a, b).invoke())


@pytest.mark.asyncio
async def test_sub_lt(safemath_mock):
    safemath = safemath_mock

    a = to_uint(56789)
    b = to_uint(1234)
    c = sub_uint(a, b)

    execution_info = await safemath.test_sub_lt(a, b).invoke()
    assert execution_info.result == (c,)


@pytest.mark.asyncio
async def test_sub_lt_equal(safemath_mock):
    safemath = safemath_mock

    a = MAX_UINT256
    b = MAX_UINT256

    await assert_revert(safemath.test_sub_lt(a, b).invoke())


@pytest.mark.asyncio
async def test_sub_lt_overflow(safemath_mock):
    safemath = safemath_mock

    a = to_uint(1234)
    b = to_uint(56789)

    await assert_revert(safemath.test_sub_lt(a, b).invoke())


@pytest.mark.asyncio
async def test_sub_le(safemath_mock):
    safemath = safemath_mock

    a = to_uint(56789)
    b = to_uint(1234)
    c = sub_uint(a, b)

    execution_info = await safemath.test_sub_le(a, b).invoke()
    assert execution_info.result == (c,)


@pytest.mark.asyncio
async def test_sub_le_equal(safemath_mock):
    safemath = safemath_mock

    a = MAX_UINT256
    b = MAX_UINT256
    c = sub_uint(a, b)

    execution_info = await safemath.test_sub_le(a, b).invoke()
    assert execution_info.result == (c,)


@pytest.mark.asyncio
async def test_sub_le_overflow(safemath_mock):
    safemath = safemath_mock

    a = to_uint(1234)
    b = to_uint(56789)

    await assert_revert(safemath.test_sub_le(a, b).invoke())
