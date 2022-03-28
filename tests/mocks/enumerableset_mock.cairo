# SPDX-License-Identifier: MIT

%lang starknet

from openzeppelin.utils.structs.enumerableset import (
    EnumerableSet_add,
    EnumerableSet_remove,
    EnumerableSet_contains,
    EnumerableSet_length,
    EnumerableSet_at,
    EnumerableSet_values
)

@external
func test_add{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        set_key : felt, value : felt) -> (success : felt):
    let (success) = EnumerableSet_add(set_key=set_key, value=value)
    return (success=success)
end

@external
func test_remove{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(set_key : felt, 
        value : felt) -> (success : felt):
    let (success) = EnumerableSet_remove(set_key=set_key, value=value)
    return (success=success)
end

@view
func test_contains{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        set_key : felt, value : felt) -> (contains : felt):
    let (contains) = EnumerableSet_contains(set_key=set_key, value=value)
    return (contains=contains)
end

@view
func test_length{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(set_key : felt) -> (
        length : felt):
    let (length) = EnumerableSet_length(set_key=set_key)
    return (length=length)
end

@view
func test_at{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        set_key : felt, index : felt) -> (res : felt):
    let (res) = EnumerableSet_at(set_key=set_key, index=index)
    return (res=res)
end

@view
func test_values{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(set_key : felt) -> (
        res : felt*):
    let (res) = EnumerableSet_values(set_key=set_key)
    return (res=res)
end
