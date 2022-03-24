# SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_le
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_signed_nn_le,
    uint256_sub
)
from starkware.starknet.common.syscalls import (
    get_contract_address
)
from openzeppelin.security.reentrancy_guard import (  
    ReentrancyGuard_start,
    ReentrancyGuard_end
)

@contract_interface
namespace IReentrancyGuardAttacker:
    func call_sender():
    end
end

@contract_interface
namespace IReentrancyGuard:
    func count_this_recursive(n : Uint256):
    end
end

@storage_var
func counter() -> (res : felt):  
end

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(initial_number: felt):
    counter.write(initial_number)
    return ()
end

@view
func current_count{syscall_ptr: felt*,
 pedersen_ptr : HashBuiltin*,
 range_check_ptr}() -> (res: felt):
    let (res) = counter.read()
    return (res)
end

@external
func callback{syscall_ptr : felt*, 
   pedersen_ptr : HashBuiltin*,
   range_check_ptr}():
   ReentrancyGuard_start()
   _count()
   ReentrancyGuard_end()
   return ()
end

@external
func count_local_recursive {syscall_ptr : felt*, 
   pedersen_ptr : HashBuiltin*,
   range_check_ptr} (n : felt):
   ReentrancyGuard_start()
   assert_le(1, n)
   _count()
   count_local_recursive(n - 1)
   ReentrancyGuard_end()
   return ()
end

@external
func count_this_recursive {syscall_ptr : felt*, 
   pedersen_ptr : HashBuiltin*,
   range_check_ptr} (n : Uint256, recursive_jump: Uint256):
   alloc_locals
   ReentrancyGuard_start()
   uint256_signed_nn_le(recursive_jump, n)    
   _count()
   let (contract_address) = get_contract_address()
   let (new_n: Uint256) = uint256_sub(n,recursive_jump)
   IReentrancyGuard.delegate_count_this_recursive(
       contract_address=contract_address, n=new_n )
   ReentrancyGuard_end()
    return ()    
end

@external
func count_and_call{ syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*,
    range_check_ptr}(attacker : felt):
    alloc_locals
    ReentrancyGuard_start()
    _count()
    IReentrancyGuardAttacker.call_sender(contract_address=attacker)
    ReentrancyGuard_end()
    return()
end

func _count{ syscall_ptr : felt*, 
    pedersen_ptr : HashBuiltin*,
    range_check_ptr}():
    let (current_count) = counter.read()
    counter.write(current_count + 1)
    return ()
end