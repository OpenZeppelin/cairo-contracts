import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils import (
    MAX_UINT256, assert_revert, add_uint, sub_uint,
    mul_uint, div_rem_uint, to_uint
)


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


@pytest.mark.asyncio
async def test_mul(safemath_mock):
    safemath = safemath_mock

    a = to_uint(1234)
    b = to_uint(56789)
    c = mul_uint(a, b)

    execution_info = await safemath.test_mul(a, b).invoke()
    assert execution_info.result == (c,)


@pytest.mark.asyncio
async def test_mul_zero(safemath_mock):
    safemath = safemath_mock

    a = to_uint(0)
    b = to_uint(56789)
    c = to_uint(0)

    execution_info = await safemath.test_mul(a, b).invoke()
    assert execution_info.result == (c,)

    execution_info = await safemath.test_mul(b, a).invoke()
    assert execution_info.result == (c,)


@pytest.mark.asyncio
async def test_mul_overflow(safemath_mock):
    safemath = safemath_mock

    a = MAX_UINT256
    b = to_uint(2)

    await assert_revert(
        safemath.test_mul(a, b).invoke(),
        reverted_with="Safemath: multiplication overflow"
    )


@pytest.mark.asyncio
async def test_div(safemath_mock):
    safemath = safemath_mock

    a = to_uint(56789)
    b = to_uint(56789)
    (c, r) = div_rem_uint(a, b)

    execution_info = await safemath.test_div(a, b).invoke()
    assert execution_info.result == (c, r)


@pytest.mark.asyncio
async def test_div_zero_dividend(safemath_mock):
    safemath = safemath_mock

    a = to_uint(0)
    b = to_uint(56789)
    (c, r) = div_rem_uint(a, b)

    execution_info = await safemath.test_div(a, b).invoke()
    assert execution_info.result == (c, r)


@pytest.mark.asyncio
async def test_div_zero_divisor(safemath_mock):
    safemath = safemath_mock

    a = to_uint(56789)
    b = to_uint(0)

    await assert_revert(
        safemath.test_div(a, b).invoke(),
        reverted_with="Safemath: divisor cannot be zero"
    )


@pytest.mark.asyncio
async def test_div_uneven_division(safemath_mock):
    safemath = safemath_mock

    a = to_uint(7000)
    b = to_uint(5678)
    (c, r) = div_rem_uint(a, b)

    execution_info = await safemath.test_div(a, b).invoke()
    assert execution_info.result == (c, r)
