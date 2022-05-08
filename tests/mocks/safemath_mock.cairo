# SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.security.safemath import SafeUint256

@view
func uint256_add{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (a: Uint256, b: Uint256) -> (c: Uint256):
    let (c: Uint256) = SafeUint256.add(a, b)
    return (c)
end

@view
func uint256_sub_le{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (a: Uint256, b: Uint256) -> (c: Uint256):
    let (c: Uint256) = SafeUint256.sub_le(a, b)
    return (c)
end

@view
func uint256_sub_lt{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (a: Uint256, b: Uint256) -> (c: Uint256):
    let (c: Uint256) = SafeUint256.sub_lt(a, b)
    return (c)
end

@view
func uint256_mul{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (a: Uint256, b: Uint256) -> (c: Uint256):
    let (c: Uint256) = SafeUint256.mul(a, b)
    return (c)
end

@view
func uint256_div{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (a: Uint256, b: Uint256) -> (c: Uint256, rem: Uint256):
    let (c: Uint256, rem: Uint256) = SafeUint256.div_rem(a, b)
    return (c, rem)
end
