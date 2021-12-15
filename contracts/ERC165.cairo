%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin

@view
func ERC165_supportsInterface{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (interface_id: felt) -> (success: felt):
    # 165
    if interface_id == '0x01ffc9a7':
        return (1)
    end

    # The INVALID_ID '0xffffffff' must explicitly return false ('0')
    # according to EIP721
    if interface_id == '0xffffffff':
        return (0)
    end
    return (0)
end
