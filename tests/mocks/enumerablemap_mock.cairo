# SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from openzeppelin.utils.structs.enumerablemap import (
    EnumerableMap_set, EnumerableMap_remove, EnumerableMap_contains, EnumerableMap_length,
    EnumerableMap_at, EnumerableMap_try_get, EnumerableMap_get)

const MAP_ID = 0

@external
func set{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        key : felt, value : felt) -> (success : felt):
    let (success) = EnumerableMap_set(map_id=MAP_ID, key=key, value=value)
    return (success=success)
end

@external
func remove{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(key : felt) -> (
        success : felt):
    let (success) = EnumerableMap_remove(map_id=MAP_ID, key=key)
    return (success=success)
end

@external
func contains{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(key : felt) -> (
        contains : felt):
    let (contains) = EnumerableMap_contains(map_id=MAP_ID, key=key)
    return (contains=contains)
end

@external
func length{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (length : felt):
    let (length) = EnumerableMap_length(map_id=MAP_ID)
    return (length=length)
end

@external
func try_get{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(key : felt) -> (
        contains : felt, value : felt):
    let (contains, value) = EnumerableMap_try_get(map_id=MAP_ID, key=key)
    return (contains=contains, value=value)
end

@external
func get{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(key : felt) -> (
        contains : felt, value : felt):
    let (contains, value) = EnumerableMap_get(map_id=MAP_ID, key=key)
    return (contains=contains, value=value)
end
