# SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin

from openzeppelin.introspection.ERC165 import ERC165

@view
func supportsInterface{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (interfaceId: felt) -> (success: felt):
    let (success) = ERC165.supports_interface(interfaceId)
    return (success)
end

@external
func registerInterface{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    } (interfaceId: felt):
    ERC165.register_interface(interfaceId)
    return ()
end
