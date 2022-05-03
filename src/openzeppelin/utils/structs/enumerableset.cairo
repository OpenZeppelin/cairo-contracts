# SPDX-License-Identifier: MIT
# OpenZeppelin Cairo Contracts v0.1.0 (utils/structs/enumerableset.cairo)
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE

@storage_var
func EnumerableSet_values(set_id : felt, set_index : felt) -> (value : felt):
end

@storage_var
func EnumerableSet_sizes(set_id : felt) -> (size : felt):
end

@storage_var
func EnumerableSet_indexes(set_id : felt, set_value : felt) -> (set_index : felt):
end

namespace EnumerableSet:
    func contains{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(set_id : felt, value : felt) -> (contains : felt):
        let (index) = EnumerableSet_indexes.read(set_id=set_id, set_value=value)
        if index == 0:
            return (contains=FALSE)
        end
        return (contains=TRUE)
    end
    func add{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(set_id : felt, value : felt) -> (success : felt):
        alloc_locals
        let (contains) = EnumerableSet.contains(set_id, value=value)

        if contains == FALSE:
            let (size) = EnumerableSet_sizes.read(set_id=set_id)
            local newSize = size + 1
            EnumerableSet_values.write(set_id=set_id, set_index=newSize, value=value)
            EnumerableSet_indexes.write(set_id=set_id, set_value=value, value=newSize)
            EnumerableSet_sizes.write(set_id=set_id, value=newSize)
            return (success=TRUE)
        end

        return (success=FALSE)
    end

    func remove{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(set_id : felt, value : felt) -> (success : felt):
        alloc_locals
        let (valueIndex) = EnumerableSet_indexes.read(set_id=set_id, set_value=value)

        if valueIndex == 0:
            return (success=FALSE)
        end

        let (lastIndex) = EnumerableSet_sizes.read(set_id=set_id)
        local res = lastIndex - valueIndex
        local new_last_index = lastIndex - 1

        let (lastValue) = EnumerableSet_values.read(set_id=set_id, set_index=lastIndex)

        EnumerableSet_values.write(set_id=set_id, set_index=lastIndex, value=0)
        EnumerableSet_indexes.write(set_id=set_id, set_value=value, value=0)
        EnumerableSet_sizes.write(set_id=set_id, value=new_last_index)

        if res != 0:
            EnumerableSet_values.write(set_id=set_id, set_index=valueIndex, value=lastValue)
            EnumerableSet_indexes.write(set_id=set_id, set_value=lastValue, value=valueIndex)
        end

        return (success=TRUE)
    end

    func length{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(set_id : felt) -> (length : felt):
        let (size) = EnumerableSet_sizes.read(set_id=set_id)
        return (length=size)
    end

    func at{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(set_id : felt, index : felt) -> (res : felt):
        let (value) = EnumerableSet_values.read(set_id=set_id, set_index=index)
        return (res=value)
    end

    func values{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(set_id : felt) -> (res : felt*):
        let index = 1
        let values : felt* = alloc()
        let (size) = EnumerableSet_sizes.read(set_id=set_id)
        let size_oob = size + 1
        let (vals) = _values_helper(
            set_id=set_id, index=index, size=size_oob, values=values)
        return (res=vals)
    end
end

func _values_helper{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr
    }(
        set_id : felt, 
        index : felt, 
        size : felt, 
        values : felt*
    ) -> (res : felt*):
    if index == size:
        return (res=values)
    end

    let (value) = EnumerableSet_values.read(set_id=set_id, set_index=index)

    assert values[index - 1] = value

    let new_index = index + 1

    let (new_values) = _values_helper(set_id=set_id, index=new_index, size=size, values=values)

    return (res=new_values)
end
