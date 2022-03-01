# SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.security.safemath import (
    uint256_checked_add,
    uint256_checked_sub_le,
    uint256_checked_sub_lt,
    uint256_checked_mul,
    uint256_checked_div_rem
)

#
# Note the follow exposed functions are meant for testing.
# Contracts should import from the `safemath.cairo` library.
#

@view
func test_add{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (a: Uint256, b: Uint256) -> (c: Uint256):
    let (c: Uint256) = uint256_checked_add(a, b)
    return (c)
end

@view
func test_sub_le{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (a: Uint256, b: Uint256) -> (c: Uint256):
    let (c: Uint256) = uint256_checked_sub_le(a, b)
    return (c)
end

@view
func test_sub_lt{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (a: Uint256, b: Uint256) -> (c: Uint256):
    let (c: Uint256) = uint256_checked_sub_lt(a, b)
    return (c)
end

@view
func test_mul{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (a: Uint256, b: Uint256) -> (c: Uint256):
    let (c: Uint256) = uint256_checked_mul(a, b)
    return (c)
end

@view
func test_div{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (a: Uint256, b: Uint256) -> (c: Uint256, rem: Uint256):
    let (c: Uint256, rem: Uint256) = uint256_checked_div_rem(a, b)
    return (c, rem)
end
