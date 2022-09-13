import pytest
from utils import (
    MAX_UINT256, assert_revert, add_uint, sub_uint,
    mul_uint, div_rem_uint, to_uint,
    get_contract_class, State
)


@pytest.fixture(scope='module')
async def safemath_mock():
    starknet = await State.init()
    safemath = await starknet.deploy(
        contract_class=get_contract_class("SafeMathMock")
    )

    return safemath


@pytest.mark.asyncio
async def test_add(safemath_mock):
    safemath = safemath_mock

    a = to_uint(56789)
    b = to_uint(1234)
    c = add_uint(a, b)

    execution_info = await safemath.uint256_add(a, b).execute()
    assert execution_info.result == (c,)


@pytest.mark.asyncio
async def test_add_overflow(safemath_mock):
    safemath = safemath_mock

    a = MAX_UINT256
    b = to_uint(1)

    await assert_revert(
        safemath.uint256_add(a, b).execute(),
        reverted_with="SafeUint256: addition overflow"
    )


@pytest.mark.asyncio
async def test_sub_lt(safemath_mock):
    safemath = safemath_mock

    a = to_uint(56789)
    b = to_uint(1234)
    c = sub_uint(a, b)

    execution_info = await safemath.uint256_sub_lt(a, b).execute()
    assert execution_info.result == (c,)


@pytest.mark.asyncio
async def test_sub_lt_equal(safemath_mock):
    safemath = safemath_mock

    a = MAX_UINT256
    b = MAX_UINT256

    await assert_revert(
        safemath.uint256_sub_lt(a, b).execute(),
        reverted_with="SafeUint256: subtraction overflow or the difference equals zero"
    )


@pytest.mark.asyncio
async def test_sub_lt_overflow(safemath_mock):
    safemath = safemath_mock

    a = to_uint(1234)
    b = to_uint(56789)

    await assert_revert(
        safemath.uint256_sub_lt(a, b).execute(),
        reverted_with="SafeUint256: subtraction overflow or the difference equals zero"
    )


@pytest.mark.asyncio
async def test_sub_le(safemath_mock):
    safemath = safemath_mock

    a = to_uint(56789)
    b = to_uint(1234)
    c = sub_uint(a, b)

    execution_info = await safemath.uint256_sub_le(a, b).execute()
    assert execution_info.result == (c,)


@pytest.mark.asyncio
async def test_sub_le_equal(safemath_mock):
    safemath = safemath_mock

    a = MAX_UINT256
    b = MAX_UINT256
    c = sub_uint(a, b)

    execution_info = await safemath.uint256_sub_le(a, b).execute()
    assert execution_info.result == (c,)


@pytest.mark.asyncio
async def test_sub_le_overflow(safemath_mock):
    safemath = safemath_mock

    a = to_uint(1234)
    b = to_uint(56789)

    await assert_revert(
        safemath.uint256_sub_le(a, b).execute(),
        reverted_with="SafeUint256: subtraction overflow"
    )
    await assert_revert(safemath.uint256_sub_le(a, b).execute())


@pytest.mark.asyncio
async def test_mul(safemath_mock):
    safemath = safemath_mock

    a = to_uint(1234)
    b = to_uint(56789)
    c = mul_uint(a, b)

    execution_info = await safemath.uint256_mul(a, b).execute()
    assert execution_info.result == (c,)


@pytest.mark.asyncio
async def test_mul_zero(safemath_mock):
    safemath = safemath_mock

    a = to_uint(0)
    b = to_uint(56789)
    c = to_uint(0)

    execution_info = await safemath.uint256_mul(a, b).execute()
    assert execution_info.result == (c,)

    execution_info = await safemath.uint256_mul(b, a).execute()
    assert execution_info.result == (c,)


@pytest.mark.asyncio
async def test_mul_overflow(safemath_mock):
    safemath = safemath_mock

    a = MAX_UINT256
    b = to_uint(2)

    await assert_revert(
        safemath.uint256_mul(a, b).execute(),
        reverted_with="SafeUint256: multiplication overflow"
    )


@pytest.mark.asyncio
async def test_div(safemath_mock):
    safemath = safemath_mock

    a = to_uint(56789)
    b = to_uint(56789)
    (c, r) = div_rem_uint(a, b)

    execution_info = await safemath.uint256_div(a, b).execute()
    assert execution_info.result == (c, r)


@pytest.mark.asyncio
async def test_div_zero_dividend(safemath_mock):
    safemath = safemath_mock

    a = to_uint(0)
    b = to_uint(56789)
    (c, r) = div_rem_uint(a, b)

    execution_info = await safemath.uint256_div(a, b).execute()
    assert execution_info.result == (c, r)


@pytest.mark.asyncio
async def test_div_zero_divisor(safemath_mock):
    safemath = safemath_mock

    a = to_uint(56789)
    b = to_uint(0)

    await assert_revert(
        safemath.uint256_div(a, b).execute(),
        reverted_with="SafeUint256: divisor cannot be zero"
    )


@pytest.mark.asyncio
async def test_div_uneven_division(safemath_mock):
    safemath = safemath_mock

    a = to_uint(7000)
    b = to_uint(5678)
    (c, r) = div_rem_uint(a, b)

    execution_info = await safemath.uint256_div(a, b).execute()
    assert execution_info.result == (c, r)
