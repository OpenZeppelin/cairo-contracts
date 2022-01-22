import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils import uint, MAX_UINT256, assert_revert, add_uint, sub_uint


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
async def uint256_checked_factory():
    starknet = await Starknet.empty()
    uint256_checked = await starknet.deploy(
        "contracts/utils/Uint256_Checked.cairo"
    )

    return uint256_checked


@pytest.mark.asyncio
async def test_add(uint256_checked_factory):
    uint256_checked = uint256_checked_factory

    a = (5678, 9)
    b = (123, 4)
    c = add_uint(a, b)

    execution_info = await uint256_checked.test_add(a, b).invoke()
    assert execution_info.result == (c,)


@pytest.mark.asyncio
async def test_add_overflow(uint256_checked_factory):
    uint256_checked = uint256_checked_factory

    a = MAX_UINT256
    b = uint(1)

    await assert_revert(uint256_checked.test_add(a, b).invoke())


@pytest.mark.asyncio
async def test_sub_lt(uint256_checked_factory):
    uint256_checked = uint256_checked_factory

    a = (5678, 9)
    b = (123, 4)
    c = sub_uint(a, b)

    execution_info = await uint256_checked.test_sub_lt(a, b).invoke()
    assert execution_info.result == (c,)


@pytest.mark.asyncio
async def test_sub_lt_overflow(uint256_checked_factory):
    uint256_checked = uint256_checked_factory

    a = (123, 4)
    b = (5678, 9)

    await assert_revert(uint256_checked.test_sub_lt(a, b).invoke())


@pytest.mark.asyncio
async def test_sub_le(uint256_checked_factory):
    uint256_checked = uint256_checked_factory

    a = (5678, 9)
    b = (123, 4)
    c = sub_uint(a, b)

    execution_info = await uint256_checked.test_sub_lt(a, b).invoke()
    assert execution_info.result == (c,)


@pytest.mark.asyncio
async def test_sub_le_equal(uint256_checked_factory):
    uint256_checked = uint256_checked_factory

    a = MAX_UINT256
    b = MAX_UINT256
    c = sub_uint(a, b)

    execution_info = await uint256_checked.test_sub_lt(a, b).invoke()
    assert execution_info.result == (c,)


@pytest.mark.asyncio
async def test_sub_le_overflow(uint256_checked_factory):
    uint256_checked = uint256_checked_factory

    a = (123, 4)
    b = (5678, 9)

    await assert_revert(uint256_checked.test_sub_le(a, b).invoke())
