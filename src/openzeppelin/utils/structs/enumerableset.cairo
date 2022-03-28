# SPDX-License-Identifier: MIT
# OpenZeppelin Cairo Contracts v0.1.0 (utils/structs/enumerableset.cairo)
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_not_zero
from openzeppelin.utils.constants import TRUE, FALSE

@storage_var
func Set_values(set_key : felt, set_index : felt) -> (value : felt):
end

@storage_var
func Set_sizes(set_key : felt) -> (size : felt):
end

@storage_var
func Set_indexes(set_key : felt, set_value : felt) -> (set_index : felt):
end

func _add{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        set_key : felt, value : felt) -> (success : felt):
    alloc_locals
    let (contains) = _contains(set_key, value=value)

    if contains == FALSE:
        let (size) = Set_sizes.read(set_key=set_key)
        local newSize = size + 1
        Set_values.write(set_key=set_key, set_index=newSize, value=value)
        Set_indexes.write(set_key=set_key, set_value=value, value=newSize)
        Set_sizes.write(set_key=set_key, value=newSize)
        return (success=TRUE)
    end

    return (success=FALSE)
end

func _remove{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(set_key : felt, 
        value : felt) -> (success : felt):
    alloc_locals
    let (valueIndex) = Set_indexes.read(set_key=set_key, set_value=value)

    if valueIndex == 0:
        return (success=FALSE)
    end

    let (lastIndex) = Set_sizes.read(set_key=set_key)
    local res = lastIndex - valueIndex
    local new_last_index = lastIndex - 1

    let (lastValue) = Set_values.read(set_key=set_key, set_index=lastIndex)

    Set_values.write(set_key=set_key, set_index=lastIndex, value=0)
    Set_indexes.write(set_key=set_key, set_value=value, value=0)
    Set_sizes.write(set_key=set_key, value=new_last_index)

    if res != 0:
        Set_values.write(set_key=set_key, set_index=valueIndex, value=lastValue)
        Set_indexes.write(set_key=set_key, set_value=lastValue, value=valueIndex)
    end

    return (success=TRUE)
end

func _contains{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        set_key : felt, value : felt) -> (contains : felt):
    let (index) = Set_indexes.read(set_key=set_key, set_value=value)
    if index == 0:
        return (contains=FALSE)
    end
    return (contains=TRUE)
end

func _length{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(set_key : felt) -> (
        length : felt):
    let (size) = Set_sizes.read(set_key=set_key)
    return (length=set_key)
end

func _at{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        set_key : felt, index : felt) -> (res : felt):
    let (value) = Set_values.read(set_key=set_key, set_index=index)
    return (res=value)
end

func _values{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(set_key : felt) -> (
        res : felt*):
    let index = 1
    let values : felt* = alloc()
    let (size) = Set_sizes.read(set_key=set_key)
    let size_oob = size + 1
    let (set_values) = _values_helper(set_key=set_key, index=index, size=size_oob, values=values)
    return (res=set_values)
end

func _values_helper{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(set_key : felt, 
        index : felt, size : felt, values : felt*) -> (res : felt*):
    if index == size:
        return (res=values)
    end

    let (value) = Set_values.read(set_key=set_key, set_index=index)

    assert values[index - 1] = value

    let new_index = index + 1

    let (new_values) = _values_helper(set_key=set_key, index=new_index, size=size, values=values)

    return (res=new_values) 
end

func EnumerableSet_add{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        set_key : felt, value : felt) -> (success : felt):
    let (success) = _add(set_key=set_key, value=value)
    return (success=success)
end

func EnumerableSet_remove{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(set_key : felt, 
        value : felt) -> (success : felt):
    let (success) = _remove(set_key=set_key, value=value)
    return (success=success)
end

func EnumerableSet_contains{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        set_key : felt, value : felt) -> (contains : felt):
    let (contains) = _contains(set_key=set_key, value=value)
    return (contains=contains)
end

func EnumerableSet_length{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(set_key : felt) -> (
        length : felt):
    let (length) = _length(set_key=set_key)
    return (length=length)
end

func EnumerableSet_at{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        set_key : felt, index : felt) -> (res : felt):
    let (res) = _at(set_key=set_key, index=index)
    return (res=res)
end

func EnumerableSet_values{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(set_key : felt) -> (
        res : felt*):
    let (res) = _values(set_key=set_key)
    return (res=res)
end
