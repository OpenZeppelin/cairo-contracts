%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt
)

# Adds two integers. 
# Reverts if the sum overflows.
func uint256_checked_add{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (a: Uint256, b: Uint256) -> (c: Uint256):
    let (c: Uint256, is_overflow) = uint256_add(a, b)
    assert (is_overflow) = 0
    return (c)
end

# Subtracts two integers.
# Reverts if the difference is greater than minuend.
func uint256_checked_sub_le{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (a: Uint256, b: Uint256) -> (c: Uint256):
    alloc_locals
    let (c: Uint256) = uint256_sub(a, b)
    let (is_le) = uint256_le(c, a)
    assert_not_zero(is_le)
    return (c)
end

# Subtracts two integers.
# Reverts if the difference is greater than or equal to minuend.
func uint256_checked_sub_lt{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (a: Uint256, b: Uint256) -> (c: Uint256):
    alloc_locals
    let (c: Uint256) = uint256_sub(a, b)
    let (is_lt) = uint256_lt(c, a)
    assert_not_zero(is_lt)
    return (c)
end
