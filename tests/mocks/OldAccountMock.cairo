// SPDX-License-Identifier: MIT

// This mock is to test _is_account() for
// previous account ids in ERC721 and ERC1155
// safe transfers. _is_account() uses the
// ERC165 supportsInterface entrypoint.

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE, FALSE

from openzeppelin.utils.constants.library import OLD_IACCOUNT_ID

@view
func supportsInterface{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    interfaceId: felt
) -> (success: felt){
    if (interfaceId == OLD_IACCOUNT_ID) {
        return (success=TRUE);
    }
    return (success=FALSE);
}