# SPDX-License-Identifier: MIT
# OpenZeppelin Cairo Contracts v0.1.0 (utils/structs/enumerablemap.cairo)
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from openzeppelin.utils.structs.enumerableset import EnumerableSet

@storage_var
func EnumerableMap_values(map_id : felt, key : felt) -> (value : felt):
end

namespace EnumerableMap:
    func set{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(
            map_id : felt, 
            key : felt, 
            value : felt
        ) -> (success : felt):
        EnumerableMap_values.write(map_id=map_id, key=key, value=value)
        let (success) = EnumerableSet.add(set_id=map_id, value=key)
        return (success=success)
    end

    func remove{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(map_id : felt, key : felt) -> (success : felt):
        EnumerableMap_values.write(map_id=map_id, key=key, value=0)
        let (success) = EnumerableSet.remove(set_id=map_id, value=key)
        return (success=success)
    end

    func contains{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(
            map_id : felt, 
            key : felt
        ) -> (contains : felt):
        let (contains) = EnumerableSet.contains(set_id=map_id, value=key)
        return (contains=contains)
    end

    func length{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(map_id : felt) -> (length : felt):
        let (length) = EnumerableSet.length(set_id=map_id)
        return (length=length)
    end

    func at{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(map_id : felt, index : felt) -> (key : felt, value : felt):
        let (key) = EnumerableSet.at(set_id=map_id, index=index)
        let (value) = EnumerableMap_values.read(map_id=map_id, key=key)
        return (key=key, value=value)
    end

    func try_get{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(map_id : felt, key : felt) -> (contains : felt, value : felt):
        let (value) = EnumerableMap_values.read(map_id=map_id, key=key)
        let (contains) = EnumerableSet.contains(set_id=map_id, value=key)
        return (contains=contains, value=value)
    end

    func get{
            syscall_ptr : felt*, 
            pedersen_ptr : HashBuiltin*, 
            range_check_ptr
        }(map_id : felt, key : felt) -> (contains : felt, value : felt):
        let (value) = EnumerableMap_values.read(map_id=map_id, key=key)
        let (contains) = EnumerableSet.contains(set_id=map_id, value=key)

        with_attr error_message("EnumerableMap: nonexistent key"):
            assert_not_zero(contains)
        end

        return (contains=contains, value=value)
    end
end
