%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin

from openzeppelin.introspection.erc165.library import ERC165
from openzeppelin.utils.constants import OLD_IACCOUNT_ID

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    ERC165.register_interface(OLD_IACCOUNT_ID);
    return ();
end

@view
func supportsInterface{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    interfaceId: felt
) -> (success: felt):
    let (success) = ERC165.supports_interface(interfaceId)
    return (success)
end