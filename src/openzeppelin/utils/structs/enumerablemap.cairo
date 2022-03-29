# SPDX-License-Identifier: MIT
# OpenZeppelin Cairo Contracts v0.1.0 (utils/structs/enumerablemap.cairo)
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_not_zero
from openzeppelin.utils.constants import TRUE, FALSE
from openzeppelin.utils.structs.enumerableset import (
    EnumerableSet_add,
    EnumerableSet_remove,
    EnumerableSet_contains
)

@storage_var
func EnumerableMap_felt_values(map_id : felt, key : felt) -> (value : felt):
end

@external
func EnumerableMap_set{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        map_id : felt, key : felt, value : felt) -> (success : felt):
    EnumerableMap_values.write(map_id=map_id, key=key, value=value)
    let (success) = EnumerableSet_add(set_id=map_id, value=key)
    return (success=success)
end
