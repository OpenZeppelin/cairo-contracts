# SPDX-License-Identifier: MIT
# OpenZeppelin Cairo Contracts v0.1.0 (utils/structs/enumerableset.cairo)
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE

@storage_var
func EnumerableSet_values(set_id: felt, set_index: felt) -> (value: felt):
end

@storage_var
func EnumerableSet_size(set_id: felt) -> (size: felt):
end

@storage_var
func EnumerableSet_indexes(set_id: felt, set_value: felt) -> (set_index: felt):
end

namespace EnumerableSet:
    func contains{
            syscall_ptr: felt*, 
            pedersen_ptr: HashBuiltin*, 
            range_check_ptr
        }(set_id: felt, value: felt) -> (contains: felt):
        let (index) = EnumerableSet_indexes.read(set_id, value)
        if index == 0:
            return (FALSE)
        end
        return (TRUE)
    end

    func add{
            syscall_ptr: felt*, 
            pedersen_ptr: HashBuiltin*, 
            range_check_ptr
        }(set_id: felt, value: felt) -> (success: felt):
        alloc_locals
        let (contains) = EnumerableSet.contains(set_id, value)

        if contains == FALSE:
            let (size) = EnumerableSet_size.read(set_id)
            local new_size = size + 1
            EnumerableSet_values.write(set_id, new_size, value)
            EnumerableSet_indexes.write(set_id, value, new_size)
            EnumerableSet_size.write(set_id, new_size)
            return (TRUE)
        end

        return (FALSE)
    end

    func remove{
            syscall_ptr: felt*, 
            pedersen_ptr: HashBuiltin*, 
            range_check_ptr
        }(set_id: felt, value: felt) -> (success: felt):
        alloc_locals
        let (value_index) = EnumerableSet_indexes.read(set_id, value)

        if value_index == 0:
            return (FALSE)
        end

        let (last_index) = EnumerableSet_size.read(set_id)
        local res = last_index - value_index
        local new_last_index = last_index - 1

        let (last_value) = EnumerableSet_values.read(set_id, last_index)

        EnumerableSet_values.write(set_id, last_index, 0)
        EnumerableSet_indexes.write(set_id, value, 0)
        EnumerableSet_size.write(set_id, new_last_index)

        # if removed value index is not last
        if res != 0:
            EnumerableSet_values.write(set_id, value_index, last_value)
            EnumerableSet_indexes.write(set_id, last_value, value_index)
        end

        return (TRUE)
    end

    func length{
            syscall_ptr: felt*, 
            pedersen_ptr: HashBuiltin*, 
            range_check_ptr
        }(set_id: felt) -> (length: felt):
        let (size) = EnumerableSet_size.read(set_id)
        return (size)
    end

    func at{
            syscall_ptr: felt*, 
            pedersen_ptr: HashBuiltin*, 
            range_check_ptr
        }(set_id: felt, index: felt) -> (value: felt):
        let (value) = EnumerableSet_values.read(set_id, index)
        return (value)
    end

    func values{
            syscall_ptr: felt*, 
            pedersen_ptr: HashBuiltin*, 
            range_check_ptr
        }(set_id: felt) -> (res: felt*):
        let values: felt* = alloc()
        let (size) = EnumerableSet_size.read(set_id)
        let (vals) = _values_helper(set_id, size, values, index=1)
        return (res=vals)
    end
end

func _values_helper{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(
        set_id: felt, 
        size: felt, 
        values: felt*,
        index: felt,
    ) -> (res: felt*):

    if index == size + 1:
        return (values)
    end

    let (value) = EnumerableSet_values.read(set_id, index)
    assert values[index - 1] = value
    let new_index = index + 1
    let (new_values) = _values_helper(set_id, size, values, new_index)
    return (new_values)
end
