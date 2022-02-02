%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import (
    Uint256, uint256_check, uint256_add, uint256_sub, uint256_mul, 
    uint256_unsigned_div_rem, uint256_le, uint256_lt, uint256_eq
)
from contracts.utils.constants import TRUE, FALSE

# Adds two integers. 
# Reverts if the sum overflows.
func uint256_checked_add{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (a: Uint256, b: Uint256) -> (c: Uint256):
    uint256_check(a)
    uint256_check(b)
    let (c: Uint256, is_overflow) = uint256_add(a, b)
    assert is_overflow = FALSE
    return (c)
end

# Subtracts two integers.
# Reverts if minuend (`b`) is greater than subtrahend (`a`).
func uint256_checked_sub_le{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (a: Uint256, b: Uint256) -> (c: Uint256):
    alloc_locals
    uint256_check(a)
    uint256_check(b)
    let (is_le) = uint256_le(b, a)
    assert_not_zero(is_le)
    let (c: Uint256) = uint256_sub(a, b)
    return (c)
end

# Subtracts two integers.
# Reverts if minuend (`b`) is greater than or equal to subtrahend (`a`).
func uint256_checked_sub_lt{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (a: Uint256, b: Uint256) -> (c: Uint256):
    alloc_locals
    uint256_check(a)
    uint256_check(b)

    let (is_lt) = uint256_lt(b, a)
    assert_not_zero(is_lt)
    let (c: Uint256) = uint256_sub(a, b)
    return (c)
end

# Multiplies two integers.
# Reverts if product is greater than 2^256.
func uint256_checked_mul{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (a: Uint256, b: Uint256) -> (c: Uint256):
    alloc_locals
    uint256_check(a)
    uint256_check(b)
    let (is_zero) = uint256_eq(a, Uint256(0, 0))
    if is_zero == TRUE:
        return (a)
    end

    let (c: Uint256, overflow: Uint256) = uint256_mul(a, b)
    assert overflow = Uint256(0, 0)

    let (div_check: Uint256, rem: Uint256) = uint256_unsigned_div_rem(c, a)
    let (is_eq) = uint256_eq(div_check, b)
    assert_not_zero(is_eq)

    return (c)
end

# Integer division of two numbers. Returns uint256 quotient and remainder.
func uint256_checked_div_rem{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (a: Uint256, b: Uint256) -> (c: Uint256, rem: Uint256):
    alloc_locals
    uint256_check(a)
    uint256_check(b)
    # checks b != (0, 0)
    let (is_zero) = uint256_eq(b, Uint256(0, 0))
    assert is_zero = FALSE

    let (c: Uint256, rem: Uint256) = uint256_unsigned_div_rem(a, b)
    let (mul_bc: Uint256) = uint256_checked_mul(b, c)
    let (add_rem: Uint256) = uint256_checked_add(mul_bc, rem)

    let (is_eq) = uint256_eq(add_rem, a)
    assert_not_zero(is_eq)

    return (c, rem)
end
