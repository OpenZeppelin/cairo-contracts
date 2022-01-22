%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.uint256 import Uint256
from contracts.utils.Uint256_Checked_base import (
    Uint256_Checked_add,
    Uint256_Checked_sub_le,
    Uint256_Checked_sub_lt
)

#
# Note the follow exposed functions are meant for testing.
# Contracts should import from the `Uint256_Checked_base.cairo` library.
#

@view
func test_add{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (a: Uint256, b: Uint256) -> (c: Uint256):
    let (c: Uint256) = Uint256_Checked_add(a, b)
    return (c)
end

@view
func test_sub_le{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (a: Uint256, b: Uint256) -> (c: Uint256):
    let (c: Uint256) = Uint256_Checked_sub_le(a, b)
    return (c)
end

@view
func test_sub_lt{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (a: Uint256, b: Uint256) -> (c: Uint256):
    let (c: Uint256) = Uint256_Checked_sub_lt(a, b)
    return (c)
end
