%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math import assert_not_equal

@storage_var
func ERC165_supported_interfaces(interface_id: felt) -> (is_supported: felt):
end 

func ERC165_supports_interface{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (interface_id: felt) -> (success: felt):
    # 165
    if interface_id == '0x01ffc9a7':
        return (1)
    end

    # Checks interface registry
    let (is_supported) = ERC165_supported_interfaces.read(interface_id)
    if is_supported == 1:
        return (1)
    end

    return (0)
end

func ERC165_register_interface{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    } (interface_id: felt):
    # Ensures interface_id is not the invalid interface_id
    assert_not_equal(interface_id, '0xffffffff')
    ERC165_supported_interfaces.write(interface_id, 1)
    return ()
end
