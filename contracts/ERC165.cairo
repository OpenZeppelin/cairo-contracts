%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin

from contracts.ERC165_base import (
    ERC165_supports_interface, 
    ERC165_register_interface
)

@view
func supportsInterface{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (interface_id: felt) -> (success: felt):
    let (success) = ERC165_supports_interface(interface_id)
    return (success)
end

@external
func register_interface{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (interface_id: felt):
    ERC165_register_interface(interface_id)
    return ()
end
