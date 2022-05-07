# SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from openzeppelin.utils.structs.enumerablemap import EnumerableMap

const MAP_ID = 0

@external
func set{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(key: felt, value: felt) -> (success: felt):
    let (success) = EnumerableMap.set(map_id=MAP_ID, key=key, value=value)
    return (success=success)
end

@external
func remove{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(key: felt) -> (success: felt):
    let (success) = EnumerableMap.remove(map_id=MAP_ID, key=key)
    return (success=success)
end

@external
func contains{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(key: felt) -> (contains: felt):
    let (contains) = EnumerableMap.contains(map_id=MAP_ID, key=key)
    return (contains=contains)
end

@external
func length{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }() -> (length: felt):
    let (length) = EnumerableMap.length(map_id=MAP_ID)
    return (length=length)
end

@external
func tryGet{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(key: felt) -> (contains: felt, value: felt):
    let (contains, value) = EnumerableMap.try_get(map_id=MAP_ID, key=key)
    return (contains=contains, value=value)
end

@external
func get{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(key: felt) -> (contains: felt, value: felt):
    let (contains, value) = EnumerableMap.get(map_id=MAP_ID, key=key)
    return (contains=contains, value=value)
end
